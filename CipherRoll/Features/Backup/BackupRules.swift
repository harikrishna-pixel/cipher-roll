import Foundation

enum BackupRules {
    static let minimumPassword = BackupFile.minimumPasswordLength
    static let intro = "Make a file you can keep outside this iPhone. You choose a password for it."
    static let passwordNote = "Use at least 10 characters. This is not your PIN."
    static let warning = "If you forget this password, we cannot open the backup or reset it for you. Keep it apart from the file."
    static let readyNote = "Save it somewhere that is not only on this iPhone, such as iCloud Drive or your computer. It opens with the password you chose, not your PIN."
    static let notSaved = "Not saved yet"
    static let restoreIntro = "Bring back items from a CipherRoll backup file."
    static let chooseFile = "Choose the backup file"
    static let chooseFileDetail = "From Files, iCloud Drive or a computer"
    static let passwordTitle = "Enter the backup password"
    static let passwordDetail = "The one you chose when you made the backup"
    static let restoreNote = "Items are added as a new vault on this iPhone. Nothing here is overwritten."
    static let wrongPassword = "That password does not open this backup. Check it and try again."
    static let badFile = "Choose a CipherRoll backup file and try again."
    static let couldNotMake = "The backup could not be made. Try again."
    static let pinTitle = "PIN for this vault"
    static let pinHint = "Use at least 6 digits. This is not the backup password."
    static let pinTaken = "Choose a different PIN for the restored vault."
    static let restoredNote = "Your PIN for the restored vault is the one you set on this iPhone. The recovery key you already saved covers this vault too."
    static let protected = "The file is protected by the password you choose."

    static let exportStarted = "backup_export_started"
    static let exportCompleted = "backup_export_completed"
    static let saved = "backup_saved"
    static let restoreStarted = "backup_restore_started"
    static let restoreCompleted = "backup_restore_completed"
    static let restoreFailed = "backup_restore_failed"

    static var scanned: String {
        [
            intro, passwordNote, warning, readyNote, notSaved, restoreIntro, chooseFile, chooseFileDetail,
            passwordTitle, passwordDetail, restoreNote, wrongPassword, badFile, couldNotMake,
            pinTitle, pinHint, pinTaken, restoredNote, protected
        ].joined(separator: "\n")
    }

    static func canCreate(password: String, repeated: String) -> Bool {
        password.count >= minimumPassword && password == repeated
    }

    static func fileName(on date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "dMMM"
        return "CipherRoll_Backup_\(formatter.string(from: date)).crbackup"
    }

    static func properties(count: Int, destination: String? = nil, reason: String? = nil) -> [String: String] {
        var properties = ["item_count_bucket": CountBucket.label(count)]
        if let destination { properties["destination"] = destination }
        if let reason { properties["reason"] = reason }
        return properties
    }

    static func reason(for error: Error) -> String {
        if let failure = error as? BackupFile.Failure, failure == .wrongPassword {
            return "wrong_password"
        }
        return "bad_file"
    }

    static func message(for error: Error) -> String {
        if let failure = error as? BackupFile.Failure {
            switch failure {
            case .wrongPassword: return wrongPassword
            case .badFile: return badFile
            case .passwordTooShort: return passwordNote
            case .unavailable: return couldNotMake
            }
        }
        if let vault = error as? VaultError {
            switch vault {
            case .secretTooShort: return pinHint
            case .secretInvalid: return pinTaken
            default: return couldNotMake
            }
        }
        return couldNotMake
    }
}
