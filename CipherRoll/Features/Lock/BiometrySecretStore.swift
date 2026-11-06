import Foundation
import LocalAuthentication
import Security

protocol BiometrySecretStoring: AnyObject {
    func save(_ secret: LockSecret) throws
    func load(context: LAContext) throws -> LockSecret?
    func delete() throws
}

final class KeychainBiometryStore: BiometrySecretStoring {
    private let service = "app.cipherroll.biometry"
    private let account = "lock-secret"

    func save(_ secret: LockSecret) throws {
        try delete()
        guard let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
            .biometryCurrentSet,
            nil
        ) else { throw VaultError.wrapFailed }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessControl as String: access,
            kSecAttrSynchronizable as String: false,
            kSecValueData as String: LockSecretCodec.encode(secret)
        ]
        let status = KeychainWork.onMain { SecItemAdd(query as CFDictionary, nil) }
        guard status == errSecSuccess else { throw VaultError.wrapFailed }
    }

    func load(context: LAContext) throws -> LockSecret? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: context
        ]
        var result: CFTypeRef?
        let status = KeychainWork.onMain {
            SecItemCopyMatching(query as CFDictionary, &result)
        }
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw VaultError.wrapFailed }
        return try LockSecretCodec.decode(data)
    }

    func delete() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = KeychainWork.onMain { SecItemDelete(query as CFDictionary) }
        guard status == errSecSuccess || status == errSecItemNotFound else { throw VaultError.wrapFailed }
    }
}

#if targetEnvironment(simulator)
/// Face ID on the simulator cannot wrap a Keychain item. The secret stays in the simulator key folder,
/// and the app reads it only after LocalAuthentication succeeds.
final class SimulatorBiometryStore: BiometrySecretStoring {
    private let keys: SimulatorKeyStore
    private let service = "app.cipherroll.biometry"
    private let account = "lock-secret"

    init() {
        let folder = AppGroupStore.root().appendingPathComponent("SimulatorKeys", isDirectory: true)
        keys = SimulatorKeyStore(folder: folder)
    }

    func save(_ secret: LockSecret) throws {
        try keys.set(LockSecretCodec.encode(secret), service: service, account: account)
    }

    func load(context: LAContext) throws -> LockSecret? {
        guard let data = try keys.data(service: service, account: account) else { return nil }
        return try LockSecretCodec.decode(data)
    }

    func delete() throws {
        try keys.delete(service: service, account: account)
    }
}
#endif

enum BiometryStoreFactory {
    static func make() -> BiometrySecretStoring {
        #if targetEnvironment(simulator)
        return SimulatorBiometryStore()
        #else
        return KeychainBiometryStore()
        #endif
    }
}
