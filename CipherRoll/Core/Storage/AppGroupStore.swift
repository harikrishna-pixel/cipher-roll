import Foundation

enum AppIdentity {
    static let bundleID = "com.marberx.photovault"
    static let appleID = "6830584787"
    static let productURL = URL(string: "https://apps.apple.com/app/id\(appleID)")!
}

/// Shared store for the app and the share extension. Keys on a device use the Keychain access group.
enum AppGroupDefaults {
    static var suite: UserDefaults { AppGroupStore.suite }
}

enum AppGroupStore {
    static let identifier = "group.com.marberx.photovault"
    /// Team id plus the group. Matches the keychain-access-groups entitlement.
    static let keychainAccessGroup = "5MWZCJ2Q4K.group.com.marberx.photovault"

    static var suite: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }

    static func root() -> URL {
        let shared: URL
        if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) {
            shared = container.appendingPathComponent("CipherRoll", isDirectory: true)
        } else {
            shared = legacyRoot()
        }
        migrateLegacyIfNeeded(into: shared)
        return shared
    }

    private static func legacyRoot() -> URL {
        let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        return library.appendingPathComponent("CipherRoll", isDirectory: true)
    }

    /// Copies an older app-sandbox vault into the shared container once, so existing items stay reachable.
    private static func migrateLegacyIfNeeded(into shared: URL) {
        let legacy = legacyRoot()
        guard shared.path != legacy.path else { return }
        let sharedVaults = shared.appendingPathComponent("Vaults", isDirectory: true)
        let legacyVaults = legacy.appendingPathComponent("Vaults", isDirectory: true)
        guard !FileManager.default.fileExists(atPath: sharedVaults.path),
              FileManager.default.fileExists(atPath: legacyVaults.path) else { return }
        try? FileManager.default.copyItem(at: legacy, to: shared)
    }
}
