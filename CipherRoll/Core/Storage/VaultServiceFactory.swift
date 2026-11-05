import Foundation

enum VaultServiceFactory {
    static func live() -> VaultService {
        VaultService(
            root: AppGroupStore.root(),
            keys: KeychainStore(),
            sealer: SecureEnclaveBundleSealer(),
            passcode: DevicePasscodeChecker(),
            derivation: PBKDF2KeyDerivation(),
            iterations: KeyDerivation.calibratedIterations(),
            clock: SystemClock(),
            originals: NoOriginalsDeleting()
        )
    }

    /// Device builds use the Keychain and the Secure Enclave. Simulator builds cannot, so they use a stand-in store.
    static func makeForApp() -> VaultService {
        #if targetEnvironment(simulator)
        return SimulatorVault.make()
        #else
        return live()
        #endif
    }
}
