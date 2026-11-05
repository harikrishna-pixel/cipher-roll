import Foundation

enum SettingsKeys {
    static let consent = "app.cipherroll.analytics.consent"
    static let breakIn = "app.cipherroll.settings.breakIn"
    static let lockDelay = "app.cipherroll.settings.lockDelay"
}

enum ConsentChoice: String {
    case allowed
    case declined
}

enum LockDelay: Int, CaseIterable, Identifiable {
    case immediately = 0
    case oneMinute = 60
    case fiveMinutes = 300

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .immediately: "Immediately"
        case .oneMinute: "1 minute"
        case .fiveMinutes: "5 minutes"
        }
    }

    static func shouldLock(since backgrounded: Date?, delay: LockDelay, now: Date) -> Bool {
        guard delay != .immediately, let backgrounded else { return true }
        return now.timeIntervalSince(backgrounded) >= TimeInterval(delay.rawValue)
    }
}

enum AppIconChoice: String, CaseIterable, Identifiable {
    case crLock = "cr_lock"
    case calculator
    case notes
    case weather
    case utility

    var id: String { rawValue }

    var title: String {
        switch self {
        case .crLock: "CR lock"
        case .calculator: "Calculator"
        case .notes: "Notes"
        case .weather: "Weather"
        case .utility: "Utility"
        }
    }

    /// Name passed to `setAlternateIconName`. Nil is the primary icon.
    var alternateName: String? {
        switch self {
        case .crLock: nil
        case .calculator: "Calculator"
        case .notes: "Notes"
        case .weather: "Weather"
        case .utility: "Utility"
        }
    }
}

enum BreakInPolicy {
    static let wrongPINThreshold = 3

    static func shouldCapture(enabled: Bool, attempts: Int) -> Bool {
        enabled && attempts == wrongPINThreshold
    }
}

enum UnlockAnalytics {
    static func properties(method: String) -> [String: String] {
        ["method": method]
    }

    static func namesAVault(_ properties: [String: String]) -> Bool {
        let text = properties.values.joined(separator: " ").lowercased()
        return text.contains("decoy") || text.contains("real")
    }
}

enum SettingsCopy {
    static let usageDetail = "No photos, files, notes, PINs or search words are sent."
    static let breakInDetail = "Takes a photo after wrong PINs. It stays on this iPhone and is not uploaded."
    static let calculatorDetail = "Shows a calculator first. Your PIN opens the vault."
    static let iconDetail = "Choose CR lock, Calculator, Notes, Weather or Utility."
    static let previewDetail = "The app preview stays covered."
    static let vaultStays = "Vault contents stay on this iPhone."
    static let iconNote = "iOS shows a short message when the icon changes. The name under the icon stays \"CipherRoll\"."
    static let decoyTitle = "One lock, two vaults"
    static let decoySubtitle = "A second PIN opens a harmless vault. Use it if someone makes you unlock your iPhone."
    static let decoyOwn = "It has its own PIN, keys and items. Nothing is copied."
    static let decoyPro = "A decoy uses one extra vault, so it needs Pro."
    static let decoyForgotten = "If you forget the decoy PIN, its items cannot be recovered. The recovery key does not cover it."
    static let decoyPINDetail = "At least 6 digits. This PIN is not covered by your recovery key."
    static let selfieTitle = "See who tried to open it"
    static let selfieDetail = "After 3 wrong PINs, CipherRoll can take a front-camera photo."
    static let selfieStays = "The photo stays on this iPhone and is not uploaded."
    static let selfieSee = "You can see it in Settings, and delete it any time."
    static let selfieOff = "You can turn this off whenever you like."
    static let photoDeniedTitle = "Photo access is optional"
    static let photoDeniedDetail = "You can still choose photos to add. Access is only needed if you want CipherRoll to offer deleting originals."
    static let restoreNoneTitle = "No active purchase found"
    static let restoreNoneDetail = "We could not find an active CipherRoll plan on this Apple Account. Your vault is unchanged."
    static let consentTitle = "Help improve CipherRoll?"
    static let consentBody = "Allow anonymous usage stats, such as which screens are used. We never send your photos, files, notes, PINs or search words."
    static let consentChange = "You can change this any time in Settings, then Privacy and lock."
    static let storageWarning = "If this iPhone is reset or replaced, vault items cannot be recovered unless you export a copy first."
    static let backupLater = "You can export a backup file. It is protected by the password you choose, not your PIN. A forgotten password cannot be reset."

    static var scanned: String {
        [
            usageDetail, breakInDetail, calculatorDetail, iconDetail, previewDetail, vaultStays, iconNote,
            decoyTitle, decoySubtitle, decoyOwn, decoyPro, decoyForgotten, decoyPINDetail,
            selfieTitle, selfieDetail, selfieStays, selfieSee, selfieOff,
            photoDeniedTitle, photoDeniedDetail, restoreNoneTitle, restoreNoneDetail,
            consentTitle, consentBody, consentChange, storageWarning, backupLater
        ].joined(separator: "\n")
    }
}
