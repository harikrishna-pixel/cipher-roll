import Foundation
import LocalAuthentication
import Security

protocol PasscodeChecking {
    func deviceHasPasscode() -> Bool
}

struct DevicePasscodeChecker: PasscodeChecking {
    func deviceHasPasscode() -> Bool {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            return true
        }
        return false
    }
}

protocol BundleSealing {
    func seal(_ plaintext: Data) throws -> Data
    func open(_ sealed: Data) throws -> Data
}

final class SecureEnclaveBundleSealer: BundleSealing {
    private let tag = Data("app.cipherroll.enclave.wrap".utf8)

    func seal(_ plaintext: Data) throws -> Data {
        let publicKey = try publicKey()
        var error: Unmanaged<CFError>?
        guard let sealed = SecKeyCreateEncryptedData(
            publicKey,
            .eciesEncryptionCofactorVariableIVX963SHA256AESGCM,
            plaintext as CFData,
            &error
        ) else {
            throw VaultError.wrapFailed
        }
        return sealed as Data
    }

    func open(_ sealed: Data) throws -> Data {
        let privateKey = try privateKey()
        var error: Unmanaged<CFError>?
        guard let plain = SecKeyCreateDecryptedData(
            privateKey,
            .eciesEncryptionCofactorVariableIVX963SHA256AESGCM,
            sealed as CFData,
            &error
        ) else {
            throw VaultError.authenticationFailed
        }
        return plain as Data
    }

    private func publicKey() throws -> SecKey {
        guard let key = SecKeyCopyPublicKey(try privateKey()) else { throw VaultError.wrapFailed }
        return key
    }

    private func privateKey() throws -> SecKey {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnRef as String: true
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess, let result, CFGetTypeID(result) == SecKeyGetTypeID() {
            return (result as! SecKey)
        }
        return try createKey()
    }

    private func createKey() throws -> SecKey {
        var error: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
            [.privateKeyUsage],
            &error
        ) else {
            throw VaultError.wrapFailed
        }
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: tag,
                kSecAttrAccessControl as String: access
            ]
        ]
        guard let key = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            throw VaultError.wrapFailed
        }
        return key
    }
}
