import Foundation

struct ShareTarget: Equatable, Identifiable {
    var id: UUID
    var title: String
}

enum ShareRules {
    /// Saving from another app never removes the source file.
    static let leavesOriginal = true
    static let originalStays = "The original stays in the source app. Saving here does not remove it."

    static func targets(entries: [(id: UUID, role: VaultRole)], unlocked: VaultRole) -> [ShareTarget] {
        let allowed = entries.filter { unlocked == .decoy ? $0.role == .decoy : $0.role == .real }
        return allowed.map { ShareTarget(id: $0.id, title: "Personal") }
    }

    static func namesADecoy(_ targets: [ShareTarget]) -> Bool {
        targets.contains { $0.title.lowercased().contains("decoy") }
    }

    static func kind(for typeIdentifier: String) -> ItemKind {
        let value = typeIdentifier.lowercased()
        if value.contains("image") { return .photo }
        if value.contains("movie") || value.contains("video") { return .video }
        if value.contains("text") || value.contains("plain") { return .note }
        return .file
    }

    static func saveButton(count: Int) -> String {
        "Save \(count) \(count == 1 ? "item" : "items")"
    }

    static func savedTitle(vault: String) -> String {
        "Saved to \(vault)"
    }

    static func savedDetail(count: Int, kind: ItemKind) -> String {
        let noun = noun(count, kind)
        let verb = count == 1 ? "is" : "are"
        return "\(count) \(noun) \(verb) now saved in CipherRoll."
    }

    static func limitMessage(kind: ItemKind) -> String {
        let name = ShareRules.noun(2, kind)
        return "\(name.capitalized) on the Free plan are full. Open CipherRoll to see plans. Nothing was removed from the other app."
    }

    static func noun(_ count: Int, _ kind: ItemKind) -> String {
        switch kind {
        case .photo: count == 1 ? "photo" : "photos"
        case .video: count == 1 ? "video" : "videos"
        case .file: count == 1 ? "file" : "files"
        case .note: count == 1 ? "note" : "notes"
        }
    }

    static var scanned: String {
        [originalStays, savedDetail(count: 3, kind: .photo), limitMessage(kind: .photo), saveButton(count: 3)].joined(separator: "\n")
    }
}

enum ShareLimitHandoff {
    static let key = "app.cipherroll.share.limitKind"

    static func record(_ kind: ItemKind, defaults: UserDefaults = AppGroupDefaults.suite) {
        defaults.set(kind.rawValue, forKey: key)
    }

    static func consume(defaults: UserDefaults = AppGroupDefaults.suite) -> ItemKind? {
        guard let raw = defaults.string(forKey: key) else { return nil }
        defaults.removeObject(forKey: key)
        return ItemKind(rawValue: raw)
    }
}
