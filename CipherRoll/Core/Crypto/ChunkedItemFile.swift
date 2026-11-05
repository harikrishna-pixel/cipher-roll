import CryptoKit
import Foundation

/// AES-GCM records written in fixed-size pieces so a large video is never held whole in the share extension.
enum ChunkedItemFile {
    static let magic = Data("CRI2".utf8)
    static let chunkBytes = 256 * 1024

    struct Written {
        var sha256: Data
        var byteCount: Int
    }

    static func write(from source: URL, to destination: URL, key: SymmetricKey, authenticating aad: Data) throws -> Written {
        let directory = destination.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try ProtectedFile.excludeFromBackup(directory)
        guard let input = InputStream(url: source) else { throw VaultError.fileMissing }
        let bufferURL = destination.appendingPathExtension("partial")
        guard let output = OutputStream(url: bufferURL, append: false) else { throw VaultError.fileMissing }
        input.open()
        output.open()
        defer {
            input.close()
            output.close()
        }
        try emit(magic + Data([1]), to: output)
        var hasher = SHA256()
        var count = 0
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: chunkBytes)
        defer { buffer.deallocate() }
        while true {
            let read = input.read(buffer, maxLength: chunkBytes)
            if read < 0 { throw VaultError.fileMissing }
            if read == 0 { break }
            let chunk = Data(bytes: buffer, count: read)
            hasher.update(data: chunk)
            count += read
            let sealed = try AESGCMBox.seal(chunk, using: key, authenticating: aad)
            var length = UInt32(sealed.count).bigEndian
            let lengthData = Data(bytes: &length, count: MemoryLayout<UInt32>.size)
            try emit(lengthData, to: output)
            try emit(sealed, to: output)
        }
        output.close()
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: bufferURL, to: destination)
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: destination.path
        )
        try ProtectedFile.excludeFromBackup(destination)
        return Written(sha256: Data(hasher.finalize()), byteCount: count)
    }

    static func open(_ file: Data, using key: SymmetricKey, authenticating aad: Data) throws -> Data {
        guard file.starts(with: magic), file.count > 5, file[file.startIndex + 4] == 1 else {
            throw VaultError.fileMissing
        }
        var offset = 5
        var plain = Data()
        let bytes = [UInt8](file)
        while offset < bytes.count {
            guard offset + 4 <= bytes.count else { throw VaultError.authenticationFailed }
            let length = Int(UInt32(bytes[offset]) << 24 | UInt32(bytes[offset + 1]) << 16 | UInt32(bytes[offset + 2]) << 8 | UInt32(bytes[offset + 3]))
            offset += 4
            guard length > 0, offset + length <= bytes.count else { throw VaultError.authenticationFailed }
            let sealed = Data(bytes[offset..<(offset + length)])
            offset += length
            plain.append(try AESGCMBox.open(sealed, using: key, authenticating: aad))
        }
        return plain
    }

    private static func emit(_ data: Data, to output: OutputStream) throws {
        var failed = false
        data.withUnsafeBytes { raw in
            guard let base = raw.bindMemory(to: UInt8.self).baseAddress else {
                failed = data.isEmpty ? false : true
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
        if failed { throw VaultError.wrapFailed }
    }
}
