import CryptoKit
import Foundation

enum AESGCMBox {
    static func seal(_ plaintext: Data, using key: SymmetricKey, authenticating aad: Data) throws -> Data {
        do {
            let box = try AES.GCM.seal(plaintext, using: key, authenticating: aad)
            guard let combined = box.combined else { throw VaultError.wrapFailed }
            return combined
        } catch let error as VaultError {
            throw error
        } catch {
            throw VaultError.wrapFailed
        }
    }

    static func open(_ combined: Data, using key: SymmetricKey, authenticating aad: Data) throws -> Data {
        do {
            let box = try AES.GCM.SealedBox(combined: combined)
            return try AES.GCM.open(box, using: key, authenticating: aad)
        } catch let error as VaultError {
            throw error
        } catch {
            throw VaultError.authenticationFailed
        }
    }

    static func openIfValid(_ combined: Data, using key: SymmetricKey, authenticating aad: Data) -> Data? {
        try? open(combined, using: key, authenticating: aad)
    }
}

enum ItemFileFormat {
    static let magic = Data("CRI1".utf8)

    static func encode(combined: Data) -> Data {
        var body = magic
        body.append(1)
        body.append(combined)
        return body
    }

    static func combined(from file: Data) throws -> Data {
        guard file.starts(with: magic), file.count > 5, file[file.startIndex + 4] == 1 else {
            throw VaultError.fileMissing
        }
        return Data(file.dropFirst(5))
    }
}
