import Foundation

enum VaultError: Error, Equatable {
    case noPasscode
    case secretTooShort
    case secretInvalid
    case authenticationFailed
    case lockedOut
    case recoveryNotAvailable
    case wrapFailed
    case kdfFailed
    case fileMissing
    case verifyFailed
    case randomFailed
    case recoveryNotTested
}

enum VaultRole: String, Codable {
    case real
    case decoy
}

enum ItemKind: String, Codable {
    case photo
    case video
    case file
    case note
}

enum LockSecret: Equatable {
    case pin(String)
    case password(String)
    case phrase(String)
    case pattern([Int])

    func material() throws -> Data {
        switch self {
        case .pin(let value):
            guard value.allSatisfy({ $0 >= "0" && $0 <= "9" }) else { throw VaultError.secretInvalid }
            guard value.count >= 6 else { throw VaultError.secretTooShort }
            return Data(value.utf8)
        case .password(let value), .phrase(let value):
            guard value.count >= 8 else { throw VaultError.secretTooShort }
            return Data(value.utf8)
        case .pattern(let dots):
            guard dots.count >= 6 else { throw VaultError.secretTooShort }
            guard Set(dots).count == dots.count else { throw VaultError.secretInvalid }
            return Data(dots.map(String.init).joined(separator: "-").utf8)
        }
    }
}
