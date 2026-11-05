import Foundation

enum ItemKindLimit {
    static func cap(_ kind: ItemKind) -> Int {
        switch kind {
        case .photo: 100
        case .video: 10
        case .file: 10
        case .note: 10
        }
    }
}

struct UsageCounts: Equatable {
    var photos = 0
    var videos = 0
    var files = 0
    var notes = 0

    var total: Int { photos + videos + files + notes }

    subscript(_ kind: ItemKind) -> Int {
        switch kind {
        case .photo: photos
        case .video: videos
        case .file: files
        case .note: notes
        }
    }

    static func tally(_ items: [LibraryItem]) -> UsageCounts {
        var counts = UsageCounts()
        for item in items where item.deletedAt == nil {
            switch item.kind {
            case .photo: counts.photos += 1
            case .video: counts.videos += 1
            case .file: counts.files += 1
            case .note: counts.notes += 1
            }
        }
        return counts
    }
}

enum FreePlanChip {
    /// The kind whose used/limit ratio is highest. Photos win a tie so an empty vault stays calm.
    static func nearest(_ counts: UsageCounts) -> (kind: ItemKind, used: Int, limit: Int) {
        let kinds: [ItemKind] = [.photo, .video, .file, .note]
        return kinds.max { left, right in
            ratio(counts[left], ItemKindLimit.cap(left)) < ratio(counts[right], ItemKindLimit.cap(right))
        }.map { kind in
            (kind, counts[kind], ItemKindLimit.cap(kind))
        } ?? (.photo, 0, 100)
    }

    static func title(kind: ItemKind, used: Int, limit: Int) -> String {
        "Free plan · \(used) of \(limit) \(label(kind))"
    }

    static func label(_ kind: ItemKind) -> String {
        switch kind {
        case .photo: "photos"
        case .video: "videos"
        case .file: "files"
        case .note: "notes"
        }
    }

    private static func ratio(_ used: Int, _ limit: Int) -> Double {
        guard limit > 0 else { return 0 }
        return Double(used) / Double(limit)
    }
}

enum ImportAllowance {
    static func remaining(used: Int, limit: Int) -> Int {
        max(0, limit - used)
    }

    static func importable(selected: Int, used: Int, limit: Int) -> Int {
        min(max(0, selected), remaining(used: used, limit: limit))
    }

    static func isOverLimit(selected: Int, used: Int, limit: Int) -> Bool {
        selected > remaining(used: used, limit: limit)
    }
}

enum TrashPolicy {
    static let days = 30

    static func daysRemaining(deletedAt: Date, now: Date) -> Int {
        let left = Double(days) * 86_400 - now.timeIntervalSince(deletedAt)
        return max(0, Int(ceil(left / 86_400)))
    }

    static func isExpired(deletedAt: Date, now: Date) -> Bool {
        now.timeIntervalSince(deletedAt) >= Double(days) * 86_400
    }
}

enum CountBucket {
    static func label(_ count: Int) -> String {
        switch count {
        case ..<1: "0"
        case 1: "1"
        case 2...5: "2-5"
        case 6...20: "6-20"
        default: "21+"
        }
    }
}

enum LibrarySearch {
    static func matches(item: LibraryItem, noteText: String?, query: String, kind: ItemKind?) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        if let kind, item.kind != kind { return false }
        if item.deletedAt != nil { return false }
        if item.displayName.localizedCaseInsensitiveContains(trimmed) { return true }
        if item.kind == .note, let noteText, noteText.localizedCaseInsensitiveContains(trimmed) { return true }
        if let album = item.album, album.localizedCaseInsensitiveContains(trimmed) { return true }
        return false
    }
}

enum StorageRoom {
    static func canFit(bytes: Int, available: Int64?) -> Bool {
        guard let available else { return true }
        return available > Int64(bytes) + 20_000_000
    }

    /// A coarse label for the settings screen. Exact bytes stay off analytics.
    static func freeSpaceLabel() -> String {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        let values = try? home.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        guard let bytes = values?.volumeAvailableCapacityForImportantUsage else { return "On this iPhone" }
        let gigabytes = Double(bytes) / 1_000_000_000
        return String(format: "%.0f GB free", gigabytes)
    }
}
