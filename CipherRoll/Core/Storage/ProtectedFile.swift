import Foundation

enum ProtectedFile {
    static func write(_ data: Data, to url: URL) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try excludeFromBackup(directory)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: url.path
        )
        try excludeFromBackup(url)
    }

    static func excludeFromBackup(_ url: URL) throws {
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutable = url
        try mutable.setResourceValues(values)
    }
}

enum InterruptedWorkSweeper {
    static let imports = "Imports"
    static let playback = "Playback"
    static let vaults = "Vaults"
    static let backupWork = "BackupWork"

    /// Removes staged imports, video playback files, and unfinished backup files. Vault ciphertext is left in place.
    static func sweep(root: URL) throws {
        let manager = FileManager.default
        for name in [imports, playback, backupWork] {
            let directory = root.appendingPathComponent(name, isDirectory: true)
            guard manager.fileExists(atPath: directory.path) else { continue }
            let files = try manager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            for file in files {
                try manager.removeItem(at: file)
            }
        }
    }
}
