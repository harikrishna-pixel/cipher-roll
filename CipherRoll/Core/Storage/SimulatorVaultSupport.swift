import CryptoKit
import Foundation

#if targetEnvironment(simulator)

/// Simulator stand-in. The Secure Enclave and WhenPasscodeSetThisDeviceOnly Keychain are not available here.
/// Device builds do not compile this type. Iteration count is 1,000 so the lock screen stays responsive.
enum SimulatorVault {
    static let iterations = 1_000

    static func make() -> VaultService {
        let root = AppGroupStore.root()
        let keys = SimulatorKeyStore(folder: root.appendingPathComponent("SimulatorKeys", isDirectory: true))
        let sealer = (try? SimulatorBundleSealer(keys: keys)) ?? SimulatorBundleSealer(key: SymmetricKey(size: .bits256))
        return VaultService(
            root: root,
            keys: keys,
            sealer: sealer,
            passcode: SimulatorPasscode(),
            derivation: PBKDF2KeyDerivation(),
            iterations: iterations,
            clock: SystemClock(),
            originals: NoOriginalsDeleting()
        )
    }
}

struct SimulatorPasscode: PasscodeChecking {
    func deviceHasPasscode() -> Bool { true }
}

final class SimulatorKeyStore: KeyStoring {
    private let folder: URL

    init(folder: URL) {
        self.folder = folder
    }

    func set(_ data: Data, service: String, account: String) throws {
        try ProtectedFile.write(data, to: fileURL(service: service, account: account))
    }

    func data(service: String, account: String) throws -> Data? {
        let url = fileURL(service: service, account: account)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try Data(contentsOf: url)
    }

    func delete(service: String, account: String) throws {
        let url = fileURL(service: service, account: account)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    private func fileURL(service: String, account: String) -> URL {
        let raw = Data("\(service)\n\(account)".utf8).base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return folder.appendingPathComponent(raw)
    }
}

final class SimulatorBundleSealer: BundleSealing {
    private let key: SymmetricKey

    init(keys: KeyStoring) throws {
        let service = "app.cipherroll.simulator"
        let account = "bundle-key"
        if let existing = try keys.data(service: service, account: account), existing.count == 32 {
            key = SymmetricKey(data: existing)
        } else {
            let raw = try RandomBytes.generate(count: 32)
            try keys.set(raw, service: service, account: account)
            key = SymmetricKey(data: raw)
        }
    }

    init(key: SymmetricKey) {
        self.key = key
    }

    func seal(_ plaintext: Data) throws -> Data {
        try AESGCMBox.seal(plaintext, using: key, authenticating: Data("bundle-v1".utf8))
    }

    func open(_ sealed: Data) throws -> Data {
        try AESGCMBox.open(sealed, using: key, authenticating: Data("bundle-v1".utf8))
    }
}

#endif
