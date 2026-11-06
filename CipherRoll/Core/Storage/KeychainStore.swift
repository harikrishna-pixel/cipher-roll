import Foundation
import Security

protocol KeyStoring: AnyObject {
    func set(_ data: Data, service: String, account: String) throws
    func data(service: String, account: String) throws -> Data?
    func delete(service: String, account: String) throws
}

enum KeychainServiceName {
    static let vault = "app.cipherroll.vault"
    static let recovery = "app.cipherroll.recovery"
    static let lockout = "app.cipherroll.lockout"
}

enum KeychainAccount {
    static let index = "index"
    static let padding = "padding"
    static let recoveryKEK = "recovery-kek"
    static let pendingWords = "pending-words"
    static let recoveryTested = "recovery-tested"
    static let lockout = "attempt-counter"
}

enum KeychainQuery {
    /// No team id is written here. The signed keychain entitlement supplies the group,
    /// so a device build is not tied to one hardcoded prefix.
    static func add(data: Data, service: String, account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
            kSecAttrSynchronizable as String: false,
            kSecValueData as String: data
        ]
    }

    static func lookup(service: String, account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
    }

    static func remove(service: String, account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

final class KeychainStore: KeyStoring {
    func set(_ data: Data, service: String, account: String) throws {
        let status = KeychainWork.onMain {
            SecItemDelete(KeychainQuery.remove(service: service, account: account) as CFDictionary)
            return SecItemAdd(KeychainQuery.add(data: data, service: service, account: account) as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw VaultError.wrapFailed }
    }

    func data(service: String, account: String) throws -> Data? {
        var result: CFTypeRef?
        let status = KeychainWork.onMain {
            SecItemCopyMatching(KeychainQuery.lookup(service: service, account: account) as CFDictionary, &result)
        }
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw VaultError.wrapFailed }
        return data
    }

    func delete(service: String, account: String) throws {
        let status = KeychainWork.onMain {
            SecItemDelete(KeychainQuery.remove(service: service, account: account) as CFDictionary)
        }
        guard status == errSecSuccess || status == errSecItemNotFound else { throw VaultError.wrapFailed }
    }
}

enum KeychainWork {
    /// Secure Enclave and passcode-protected Keychain items fail from a background queue on a device.
    static func onMain(_ work: () -> OSStatus) -> OSStatus {
        if Thread.isMainThread { return work() }
        return DispatchQueue.main.sync(execute: work)
    }

    static func valueOnMain<T>(_ work: () throws -> T) throws -> T {
        if Thread.isMainThread { return try work() }
        return try DispatchQueue.main.sync(execute: work)
    }
}
