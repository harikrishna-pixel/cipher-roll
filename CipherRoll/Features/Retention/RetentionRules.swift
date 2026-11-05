import Foundation

enum RetentionKeys {
    static let wrongAttempts = "app.cipherroll.retention.wrongAttempts"
    static let addedThisWeek = "app.cipherroll.retention.addedThisWeek"
    static let weekStart = "app.cipherroll.retention.weekStart"
    static let lastOpen = "app.cipherroll.retention.lastOpen"
    static let welcomeShownDay = "app.cipherroll.retention.welcomeDay"
    static let lastRecap = "app.cipherroll.retention.lastRecap"
    static let reviewRequested = "app.cipherroll.retention.reviewRequested"
    static let notificationAsked = "app.cipherroll.retention.notificationAsked"
    static let sessions = "app.cipherroll.retention.sessions"
    static let inviteCode = "app.cipherroll.retention.inviteCode"
    static let inviteEmail = "app.cipherroll.retention.inviteEmail"
    static let rewardsThisYear = "app.cipherroll.retention.rewardsThisYear"
}

enum WelcomeVariant: String, Equatable {
    case daily
    case away
}

enum WelcomeRules {
    static let awayAfterDays = 9

    static func variant(lastOpen: Date?, now: Date, alreadyShownDay: String, calendar: Calendar = .current) -> WelcomeVariant? {
        guard let lastOpen else { return nil }
        let day = dayKey(now, calendar: calendar)
        if alreadyShownDay == day { return nil }
        let days = now.timeIntervalSince(lastOpen) / 86_400
        if days >= Double(awayAfterDays) { return .away }
        if !calendar.isDate(lastOpen, inSameDayAs: now) { return .daily }
        return nil
    }

    static func greeting(hour: Int) -> String {
        switch hour {
        case 5..<12: "Good morning"
        case 12..<17: "Good afternoon"
        default: "Good evening"
        }
    }

    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }
}

struct WelcomeCard: Equatable {
    var eyebrow: String
    var title: String
    var kept: String
    var leftTitle: String
    var leftDetail: String
    var action: String
}

enum WelcomeCopy {
    static func card(variant: WelcomeVariant, itemCount: Int, added: Int, hour: Int) -> WelcomeCard {
        switch variant {
        case .daily:
            WelcomeCard(
                eyebrow: WelcomeRules.greeting(hour: hour),
                title: "Welcome back",
                kept: "\(itemCount) items kept private",
                leftTitle: added > 0 ? "You added \(added) photos to Personal" : "Your vault is ready",
                leftDetail: added > 0 ? "Pick up where you stopped." : "Nothing new is waiting.",
                action: "Add more to your vault"
            )
        case .away:
            WelcomeCard(
                eyebrow: "It has been 9 days",
                title: "Still here, still private",
                kept: "\(itemCount) items kept private",
                leftTitle: "Nothing changed while you were away",
                leftDetail: "\(itemCount) items are exactly where you left them",
                action: "Open Personal"
            )
        }
    }

    static let uploaded = "0 uploaded"
}

enum RecapRules {
    static func shouldShow(last: Date?, now: Date, itemCount: Int) -> Bool {
        guard itemCount > 0, let last else { return false }
        return now.timeIntervalSince(last) >= 7 * 86_400
    }
}

enum RetentionSession {
    private static var number: Int?

    /// Counts a cold start once. The first session is 1, so a rating prompt waits for a later visit.
    static func begin(defaults: UserDefaults = AppGroupDefaults.suite) -> Int {
        if let number { return number }
        let next = defaults.integer(forKey: RetentionKeys.sessions) + 1
        defaults.set(next, forKey: RetentionKeys.sessions)
        number = next
        return next
    }

    static var current: Int { number ?? 1 }
}

enum ReviewPrompt {
    static func shouldRequest(moment: String, alreadyRequested: Bool, session: Int) -> Bool {
        guard !alreadyRequested, session >= 2 else { return false }
        return moment == "import_done" || moment == "weekly_recap"
    }
}

struct ReferralDecision: Equatable {
    var granted: Bool
    var days: Int
}

protocol ReferralChecking {
    func redeem(code: String) -> ReferralDecision
}

/// No invite server is configured. Rewards stay ungranted until one confirms them.
struct UnavailableReferralServer: ReferralChecking {
    func redeem(code: String) -> ReferralDecision {
        ReferralDecision(granted: false, days: 0)
    }
}

enum ReferralRules {
    static let rewardDays = 7
    static let maxPerYear = 10

    static func canReward(already: Int) -> Bool {
        already < maxPerYear
    }

    static func apply(server: ReferralDecision, already: Int) -> ReferralDecision {
        guard canReward(already: already), server.granted else {
            return ReferralDecision(granted: false, days: 0)
        }
        return ReferralDecision(granted: true, days: rewardDays)
    }

    static func code(stored: String?) -> String {
        if let stored, stored.count == 4 { return stored }
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<4).map { _ in alphabet.randomElement() ?? "A" })
    }

    static func message(code: String) -> String {
        "I keep my private photos and files in CipherRoll. Use my link for 7 days of Pro: \(AppIdentity.productURL.absoluteString)?code=\(code)"
    }

    static let unavailable = "We could not confirm this invite yet. Your vault is unchanged."
}

enum MarberxApp: String, CaseIterable, Identifiable {
    case tunely
    case shrink
    case bibleHi

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tunely: "Tunely"
        case .shrink: "Shrink"
        case .bibleHi: "BibleHi"
        }
    }

    var detail: String {
        switch self {
        case .tunely: "MP3 and ringtone maker. Works on your iPhone."
        case .shrink: "Video compressor. Smaller files, same video."
        case .bibleHi: "Read the Bible in a calm, clean layout."
        }
    }

    var letter: String {
        switch self {
        case .tunely: "T"
        case .shrink: "S"
        case .bibleHi: "B"
        }
    }

    var searchURL: URL {
        URL(string: "https://apps.apple.com/search?term=\(title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? title)")!
    }
}

enum ToastKind: String, Equatable {
    case success
    case undo
    case info
    case saved
    case offline
    case error
}

struct CipherToast: Equatable, Identifiable {
    var id = UUID()
    var kind: ToastKind
    var title: String
    var action: String?
}

enum ToastRules {
    static let seconds = 3
    static let note = "Appear above the tab bar for 3 seconds, dismiss on swipe, never stack more than one. Never used to sell."
}
