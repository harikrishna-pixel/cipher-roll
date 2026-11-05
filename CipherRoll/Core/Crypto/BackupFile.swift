import CryptoKit
import Foundation

/// A `.crbackup` file. The password is not the vault PIN.
/// Plaintext is sealed in chunks so a large item is not held as one box.
enum BackupFile {
    static let magic = Data("CRBK".utf8)
    static let version: UInt8 = 1
    static let productionFloor = 600_000
    static let minimumPasswordLength = 10
    static let chunkBytes = 64 * 1024
    static let maximumIterations = 2_000_000

    enum Failure: Error, Equatable {
        case passwordTooShort
        case wrongPassword
        case badFile
        case unavailable
    }

    enum Stop: Error, Equatable {
        case beforeMove
    }

    struct Source {
        var kind: String
        var name: String
        var nextChunk: () throws -> Data?
    }

    struct ItemFile {
        var kind: String
        var name: String
        var file: URL
    }

    struct Opened {
        var title: String
        var items: [ItemFile]
    }

    static func restoredName(existingRealVaults: Int) -> String {
        if existingRealVaults <= 1 { return "Personal (restored)" }
        return "Personal (restored) \(existingRealVaults)"
    }

    static func write(
        title: String,
        sources: [Source],
        password: String,
        derivation: KeyDeriving,
        iterations: Int,
        to destination: URL,
        workRoot: URL,
        stopAfterHeader: Bool = false
    ) throws {
        guard password.count >= minimumPasswordLength else { throw Failure.passwordTooShort }
        guard iterations > 0, iterations <= maximumIterations else { throw Failure.badFile }
        try FileManager.default.createDirectory(at: workRoot, withIntermediateDirectories: true)
        try ProtectedFile.excludeFromBackup(workRoot)
        let partial = workRoot.appendingPathComponent("export.partial")
        if FileManager.default.fileExists(atPath: partial.path) {
            try FileManager.default.removeItem(at: partial)
        }
        let salt = try RandomBytes.generate(count: 16)
        let key = try derivedKey(password: password, salt: salt, iterations: iterations, derivation: derivation)
        guard let output = OutputStream(url: partial, append: false) else { throw Failure.badFile }
        output.open()
        defer { output.close() }
        try emit(header(salt: salt, iterations: iterations), to: output)
        if stopAfterHeader { throw Stop.beforeMove }
        var frame: UInt32 = 0
        try writeFrame(vaultTitle(title), key: key, index: frame, to: output)
        frame += 1
        for source in sources {
            var pending = try source.nextChunk()
            var isFirst = true
            if pending == nil {
                try writeFrame(itemFrame(kind: source.kind, name: source.name, chunk: Data(), first: true, last: true), key: key, index: frame, to: output)
                frame += 1
                continue
            }
            while let chunk = pending {
                let upcoming = try source.nextChunk()
                let parts = pieces(of: chunk)
                for (index, part) in parts.enumerated() {
                    let isLast = upcoming == nil && index == parts.count - 1
                    try writeFrame(
                        itemFrame(kind: source.kind, name: source.name, chunk: part, first: isFirst && index == 0, last: isLast),
                        key: key,
                        index: frame,
                        to: output
                    )
                    frame += 1
                }
                isFirst = false
                pending = upcoming
            }
        }
        output.close()
        let parent = destination.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: partial, to: destination)
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: destination.path
        )
        try ProtectedFile.excludeFromBackup(destination)
    }

    static func read(_ file: URL, password: String, derivation: KeyDeriving, into directory: URL) throws -> Opened {
        guard password.count >= minimumPasswordLength else { throw Failure.passwordTooShort }
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        let header = try handle.read(upToCount: headerLength) ?? Data()
        guard header.count == headerLength, header.starts(with: magic), header[header.startIndex + 4] == version else {
            throw Failure.badFile
        }
        let salt = header.subdata(in: 5..<21)
        let iterations = integer(header.subdata(in: 21..<25))
        guard iterations > 0, iterations <= maximumIterations else { throw Failure.badFile }
        let key = try derivedKey(password: password, salt: salt, iterations: iterations, derivation: derivation)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var frame: UInt32 = 0
        var title = ""
        var items: [ItemFile] = []
        var openItem: (kind: String, name: String, url: URL, handle: FileHandle)?
        while true {
            let lengthData = try handle.read(upToCount: 4) ?? Data()
            if lengthData.isEmpty { break }
            guard lengthData.count == 4 else { throw Failure.badFile }
            let length = integer(lengthData)
            guard length > 0, length <= chunkBytes + 4_096 else { throw Failure.badFile }
            let sealed = try handle.read(upToCount: length) ?? Data()
            guard sealed.count == length else { throw Failure.badFile }
            let plain: Data
            do {
                plain = try AESGCMBox.open(sealed, using: key, authenticating: aad(frame))
            } catch {
                throw frame == 0 ? Failure.wrongPassword : Failure.badFile
            }
            guard let kindByte = plain.first else { throw Failure.badFile }
            if kindByte == 1 {
                if openItem != nil { throw Failure.badFile }
                title = try vaultTitle(from: plain)
            } else if kindByte == 2 {
                if title.isEmpty { throw Failure.badFile }
                let piece = try itemPiece(from: plain)
                if piece.first {
                    if openItem != nil { throw Failure.badFile }
                    let url = directory.appendingPathComponent(UUID().uuidString)
                    FileManager.default.createFile(atPath: url.path, contents: nil)
                    let itemHandle = try FileHandle(forWritingTo: url)
                    openItem = (piece.kind, piece.name, url, itemHandle)
                }
                guard var current = openItem else { throw Failure.badFile }
                if !piece.chunk.isEmpty {
                    try current.handle.write(contentsOf: piece.chunk)
                }
                openItem = current
                if piece.last {
                    try current.handle.close()
                    items.append(ItemFile(kind: current.kind, name: current.name, file: current.url))
                    openItem = nil
                }
            } else {
                throw Failure.badFile
            }
            frame += 1
        }
        if openItem != nil || title.isEmpty || frame == 0 { throw Failure.badFile }
        return Opened(title: title, items: items)
    }

    static func storedIterations(at url: URL) throws -> Int {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let header = try handle.read(upToCount: headerLength) ?? Data()
        guard header.count == headerLength, header.starts(with: magic) else { throw Failure.badFile }
        return integer(header.subdata(in: 21..<25))
    }

    static func frameCount(at url: URL) throws -> Int {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let header = try handle.read(upToCount: headerLength) ?? Data()
        guard header.count == headerLength else { throw Failure.badFile }
        var count = 0
        while true {
            let lengthData = try handle.read(upToCount: 4) ?? Data()
            if lengthData.isEmpty { break }
            guard lengthData.count == 4 else { throw Failure.badFile }
            let length = integer(lengthData)
            guard length > 0 else { throw Failure.badFile }
            let body = try handle.read(upToCount: length) ?? Data()
            guard body.count == length else { throw Failure.badFile }
            count += 1
        }
        return count
    }

    private static let headerLength = 25

    private static func derivedKey(password: String, salt: Data, iterations: Int, derivation: KeyDeriving) throws -> SymmetricKey {
        var material = Data(password.utf8)
        defer { material.wipeSensitive() }
        return try derivation.derive(secret: material, salt: salt, iterations: iterations)
    }

    private static func header(salt: Data, iterations: Int) -> Data {
        var data = magic
        data.append(version)
        data.append(salt)
        data.append(bigEndian(UInt32(iterations)))
        return data
    }

    private static func aad(_ frame: UInt32) -> Data {
        var data = magic
        data.append(version)
        data.append(bigEndian(frame))
        return data
    }

    private static func pieces(of chunk: Data) -> [Data] {
        guard !chunk.isEmpty else { return [Data()] }
        var parts: [Data] = []
        var offset = 0
        while offset < chunk.count {
            let end = min(offset + chunkBytes, chunk.count)
            parts.append(chunk.subdata(in: offset..<end))
            offset = end
        }
        return parts
    }

    private static func vaultTitle(_ title: String) -> Data {
        let name = Data((title.isEmpty ? "Personal" : title).utf8)
        var data = Data([1])
        data.append(bigEndian16(UInt16(min(name.count, 512))))
        data.append(name.prefix(512))
        return data
    }

    private static func vaultTitle(from plain: Data) throws -> String {
        guard plain.count >= 3 else { throw Failure.badFile }
        let length = integer16(plain.subdata(in: 1..<3))
        guard length > 0, plain.count >= 3 + length else { throw Failure.badFile }
        guard let title = String(data: plain.subdata(in: 3..<(3 + length)), encoding: .utf8) else { throw Failure.badFile }
        return title
    }

    private static func itemFrame(kind: String, name: String, chunk: Data, first: Bool, last: Bool) -> Data {
        var flags: UInt8 = 0
        if first { flags |= 1 }
        if last { flags |= 2 }
        var data = Data([2, flags])
        if first {
            let kindData = Data((kind.isEmpty ? "file" : kind).utf8.prefix(32))
            let nameData = Data((name.isEmpty ? "Item" : name).utf8.prefix(512))
            data.append(UInt8(kindData.count))
            data.append(kindData)
            data.append(bigEndian16(UInt16(nameData.count)))
            data.append(nameData)
        }
        data.append(chunk)
        return data
    }

    private static func itemPiece(from plain: Data) throws -> (kind: String, name: String, chunk: Data, first: Bool, last: Bool) {
        guard plain.count >= 2 else { throw Failure.badFile }
        let flags = plain[plain.startIndex + 1]
        let first = flags & 1 != 0
        let last = flags & 2 != 0
        var offset = 2
        var kind = ""
        var name = ""
        if first {
            guard plain.count > offset else { throw Failure.badFile }
            let kindLength = Int(plain[plain.startIndex + offset])
            offset += 1
            guard kindLength > 0, plain.count >= offset + kindLength + 2 else { throw Failure.badFile }
            guard let kindText = String(data: plain.subdata(in: offset..<(offset + kindLength)), encoding: .utf8) else {
                throw Failure.badFile
            }
            kind = kindText
            offset += kindLength
            let nameLength = integer16(plain.subdata(in: offset..<(offset + 2)))
            offset += 2
            guard plain.count >= offset + nameLength else { throw Failure.badFile }
            guard let nameText = String(data: plain.subdata(in: offset..<(offset + nameLength)), encoding: .utf8) else {
                throw Failure.badFile
            }
            name = nameText
            offset += nameLength
        }
        return (kind, name, plain.subdata(in: offset..<plain.count), first, last)
    }

    private static func writeFrame(_ plain: Data, key: SymmetricKey, index: UInt32, to output: OutputStream) throws {
        let sealed = try AESGCMBox.seal(plain, using: key, authenticating: aad(index))
        try emit(bigEndian(UInt32(sealed.count)), to: output)
        try emit(sealed, to: output)
    }

    private static func emit(_ data: Data, to output: OutputStream) throws {
        var failed = false
        data.withUnsafeBytes { raw in
            guard let base = raw.bindMemory(to: UInt8.self).baseAddress else {
                failed = !data.isEmpty
                return
            }
            var sent = 0
            while sent < data.count {
                let wrote = output.write(base.advanced(by: sent), maxLength: data.count - sent)
                if wrote <= 0 {
                    failed = true
                    return
                }
                sent += wrote
            }
        }
        if failed { throw Failure.badFile }
    }

    private static func bigEndian(_ value: UInt32) -> Data {
        var n = value.bigEndian
        return Data(bytes: &n, count: 4)
    }

    private static func bigEndian16(_ value: UInt16) -> Data {
        var n = value.bigEndian
        return Data(bytes: &n, count: 2)
    }

    private static func integer(_ data: Data) -> Int {
        let bytes = [UInt8](data)
        guard bytes.count == 4 else { return 0 }
        return Int(UInt32(bytes[0]) << 24 | UInt32(bytes[1]) << 16 | UInt32(bytes[2]) << 8 | UInt32(bytes[3]))
    }

    private static func integer16(_ data: Data) -> Int {
        let bytes = [UInt8](data)
        guard bytes.count == 2 else { return 0 }
        return Int(UInt16(bytes[0]) << 8 | UInt16(bytes[1]))
    }
}

struct RestoredVault: Equatable {
    var itemCount: Int
    var name: String
}
