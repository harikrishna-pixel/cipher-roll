import Foundation

enum PaidPlan: String, CaseIterable, Identifiable {
    case weekly
    case yearly
    case lifetime

    var id: String { rawValue }

    static let displayOrder: [PaidPlan] = [.yearly, .weekly, .lifetime]

    var productID: String {
        switch self {
        case .weekly: "com.marberx.photovault.weekly"
        case .yearly: "com.marberx.photovault.yearly"
        case .lifetime: "com.marberx.photovault.lifetime"
        }
    }

    static func from(productID: String) -> PaidPlan? {
        allCases.first { $0.productID == productID }
    }
}

enum PlanTier: String, Equatable {
    case free
    case trial
    case weekly
    case yearly
    case lifetime

    var removesLimits: Bool { self != .free }

    static func prefer(_ current: PlanTier, _ next: PlanTier) -> PlanTier {
        rank(next) > rank(current) ? next : current
    }

    private static func rank(_ tier: PlanTier) -> Int {
        switch tier {
        case .free: 0
        case .trial: 1
        case .weekly: 2
        case .yearly: 3
        case .lifetime: 4
        }
    }
}

enum PaywallTrigger: String, Equatable {
    case onboarding
    case exit
    case limitPhotos = "limit_photos"
    case limitVideos = "limit_videos"
    case limitFiles = "limit_files"
    case limitNotes = "limit_notes"
    case secondVault = "second_vault"
    case decoyVault = "decoy_vault"
    case usageSheet = "usage_sheet"
    case homeChip = "home_chip"
    case settings
    case valueFraming = "value_framing"
    case trialEnded = "trial_ended"

    static func limit(_ kind: ItemKind) -> PaywallTrigger {
        switch kind {
        case .photo: .limitPhotos
        case .video: .limitVideos
        case .file: .limitFiles
        case .note: .limitNotes
        }
    }

    var usesContinueFree: Bool {
        switch self {
        case .exit, .limitPhotos, .limitVideos, .limitFiles, .limitNotes:
            true
        default:
            false
        }
    }
}

enum PaywallDismiss: String {
    case x
    case maybeLater = "maybe_later"
    case continueFree = "continue_free"
}

struct PlanPrices: Equatable {
    var weekly: Decimal
    var yearly: Decimal
    var lifetime: Decimal
    var weeklyText: String
    var yearlyText: String
    var lifetimeText: String

    static let catalog = PlanPrices(
        weekly: Decimal(string: "1.99") ?? 1.99,
        yearly: Decimal(string: "19.99") ?? 19.99,
        lifetime: Decimal(string: "39.99") ?? 39.99,
        weeklyText: "$1.99",
        yearlyText: "$19.99",
        lifetimeText: "$39.99"
    )

    func text(_ plan: PaidPlan) -> String {
        switch plan {
        case .weekly: weeklyText
        case .yearly: yearlyText
        case .lifetime: lifetimeText
        }
    }

    func amount(_ plan: PaidPlan) -> Decimal {
        switch plan {
        case .weekly: weekly
        case .yearly: yearly
        case .lifetime: lifetime
        }
    }
}

enum PaywallMath {
    static func perWeek(yearly: Decimal) -> Decimal {
        var value = yearly / 52
        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, 2, .plain)
        return rounded
    }

    static func perWeekText(yearly: Decimal) -> String {
        currency(perWeek(yearly: yearly))
    }

    static func savePercent(weekly: Decimal, yearly: Decimal) -> Int {
        let yearOfWeekly = weekly * 52
        guard yearOfWeekly > 0 else { return 0 }
        let ratio = (yearOfWeekly - yearly) / yearOfWeekly * 100
        let number = NSDecimalNumber(decimal: ratio)
        let handler = NSDecimalNumberHandler(roundingMode: .plain, scale: 0, raiseOnExactness: false, raiseOnOverflow: false, raiseOnUnderflow: false, raiseOnDivideByZero: false)
        return number.rounding(accordingToBehavior: handler).intValue
    }

    static func currency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_US")
        formatter.currencyCode = "USD"
        return formatter.string(from: value as NSDecimalNumber) ?? "$\(value)"
    }
}

enum ExitOfferCell: String {
    case control
    case treatment
}

enum ExitOffer {
    /// Control shows nothing. Treatment may show the exit offer once per install.
    static func cell(seed: UInt64) -> ExitOfferCell {
        seed % 2 == 0 ? .control : .treatment
    }

    static func shouldPresent(cell: ExitOfferCell, alreadyShown: Bool) -> Bool {
        cell == .treatment && !alreadyShown
    }
}

struct EndedVault: Identifiable, Equatable {
    var id: String
    var name: String
    var summary: String
    var editable: Bool
}

enum PlanEnding {
    /// One vault stays editable. The others stay listed and become read-only. Nothing is removed.
    static func assign(vaults: [EndedVault], keepID: String?) -> [EndedVault] {
        let chosen = keepID ?? vaults.first?.id
        return vaults.map { vault in
            EndedVault(id: vault.id, name: vault.name, summary: vault.summary, editable: vault.id == chosen)
        }
    }
}

enum PlanAccess {
    static func canAdd(tier: PlanTier, vaultEditable: Bool, kind: ItemKind, used: Int) -> Bool {
        guard vaultEditable else { return false }
        if tier.removesLimits { return true }
        return used < ItemKindLimit.cap(kind)
    }
}

enum TrialReminder {
    static let notificationID = "app.cipherroll.trial.day6"
    static let title = "CipherRoll"
    static let body = "Your trial reminder is here. You can manage the plan in Settings."

    static func fireDate(trialStart: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: 6, to: trialStart) ?? trialStart
    }

    static func shouldSchedule(fire: Date, now: Date, notificationsAllowed: Bool, alreadyScheduled: Bool) -> Bool {
        notificationsAllowed && !alreadyScheduled && fire > now
    }
}

enum PaywallCopy {
    static let features = [
        "Unlimited photos, videos, files and notes",
        "Unlimited vaults, each with its own lock",
        "Decoy vault for extra privacy"
    ]

    static let valueLine = "Ongoing updates. Restore on any device with the same Apple ID. Unlimited vaults and items. A decoy vault. No sync is promised."

    static func showsTrial(_ eligible: Bool) -> Bool { eligible }

    static func cardPrice(_ plan: PaidPlan, prices: PlanPrices) -> String {
        switch plan {
        case .weekly: "\(prices.weeklyText)/wk"
        case .yearly: "\(prices.yearlyText)/yr"
        case .lifetime: prices.lifetimeText
        }
    }

    static func cardDetail(_ plan: PaidPlan, prices: PlanPrices, trialEligible: Bool) -> String {
        switch plan {
        case .yearly where trialEligible:
            "7 days free, then \(PaywallMath.perWeekText(yearly: prices.yearly)) a week"
        case .yearly:
            "\(PaywallMath.perWeekText(yearly: prices.yearly)) a week, billed yearly"
        case .weekly:
            "Billed every week"
        case .lifetime:
            "Pay once, keep forever"
        }
    }

    static func badge(_ plan: PaidPlan, prices: PlanPrices, trialEligible: Bool) -> String? {
        guard plan == .yearly else { return nil }
        if trialEligible { return "7 DAYS FREE" }
        return "SAVE \(PaywallMath.savePercent(weekly: prices.weekly, yearly: prices.yearly))%"
    }

    static func buttonTitle(_ plan: PaidPlan, trialEligible: Bool) -> String {
        switch plan {
        case .yearly where trialEligible:
            "Start 7 days free"
        case .yearly:
            "Unlock unlimited"
        case .weekly:
            "Continue with Weekly"
        case .lifetime:
            "Get lifetime access"
        }
    }

    static func legal(_ plan: PaidPlan, prices: PlanPrices, trialEligible: Bool) -> String {
        switch plan {
        case .yearly where trialEligible:
            "Then \(prices.yearlyText)/year, renews automatically. Cancel anytime in Settings. We'll remind you before your trial ends."
        case .yearly:
            "\(prices.yearlyText)/year. Renews automatically until cancelled. Cancel anytime in Settings."
        case .weekly:
            "\(prices.weeklyText)/week, renews automatically. Cancel anytime in Settings."
        case .lifetime:
            "One payment of \(prices.lifetimeText). No subscription. Restore any time."
        }
    }

    static func dismissTitle(_ trigger: PaywallTrigger) -> String {
        trigger.usesContinueFree ? "Continue with Free" : "Maybe later"
    }

    static func dismiss(_ trigger: PaywallTrigger) -> PaywallDismiss {
        trigger.usesContinueFree ? .continueFree : .maybeLater
    }

    static func variant(trialEligible: Bool, selected: PaidPlan, offline: Bool) -> String {
        if offline { return "offline" }
        if !trialEligible { return "trial_used" }
        return selected.rawValue
    }

    struct Header: Equatable {
        var badge: String?
        var title: String
        var subtitle: String
    }

    static func header(trigger: PaywallTrigger, trialEligible: Bool, limitKind: ItemKind?, itemCount: Int) -> Header {
        if trigger == .exit && trialEligible {
            return Header(
                badge: nil,
                title: "Try everything free for 7 days.",
                subtitle: "The Free plan is always here too: 1 vault, 100 photos, 10 videos, 10 files and 10 notes."
            )
        }
        if trigger == .valueFraming && trialEligible {
            return Header(
                badge: "\(itemCount) items kept safe so far",
                title: "Keep every private moment safe.",
                subtitle: "Unlimited photos, videos, files and notes, locked on your iPhone."
            )
        }
        if let limitKind, isLimit(trigger) {
            let name = kindName(limitKind)
            let others = otherKinds(limitKind)
            return Header(
                badge: "\(name): \(ItemKindLimit.cap(limitKind)) of \(ItemKindLimit.cap(limitKind)) stored",
                title: "Room for all your \(name.lowercased()).",
                subtitle: "Add as many as you like. \(others) keep working on Free."
            )
        }
        if !trialEligible {
            return Header(
                badge: nil,
                title: "Unlock your full vault.",
                subtitle: "Unlimited vaults and items, whenever you're ready."
            )
        }
        return Header(
            badge: nil,
            title: "Your private space, fully unlocked.",
            subtitle: "Unlimited items and vaults, all kept on your iPhone."
        )
    }

    static func chip(tier: PlanTier) -> (title: String, button: String) {
        switch tier {
        case .free:
            ("", "Upgrade")
        case .trial:
            ("Trial", "Manage")
        case .weekly, .yearly, .lifetime:
            ("Pro", "Manage")
        }
    }

    static var scannedText: String {
        let prices = PlanPrices.catalog
        var lines = features + [valueLine, TrialReminder.title, TrialReminder.body]
        for eligible in [true, false] {
            for plan in PaidPlan.allCases {
                lines.append(buttonTitle(plan, trialEligible: eligible))
                lines.append(legal(plan, prices: prices, trialEligible: eligible))
                lines.append(cardDetail(plan, prices: prices, trialEligible: eligible))
            }
        }
        for trigger in [PaywallTrigger.onboarding, .exit, .limitVideos, .valueFraming] {
            let header = header(trigger: trigger, trialEligible: true, limitKind: .video, itemCount: 52)
            lines.append(header.title)
            lines.append(header.subtitle)
            lines.append(dismissTitle(trigger))
        }
        let used = header(trigger: .onboarding, trialEligible: false, limitKind: nil, itemCount: 0)
        lines.append(used.title)
        lines.append(used.subtitle)
        return lines.joined(separator: "\n")
    }

    private static func isLimit(_ trigger: PaywallTrigger) -> Bool {
        switch trigger {
        case .limitPhotos, .limitVideos, .limitFiles, .limitNotes: true
        default: false
        }
    }

    private static func kindName(_ kind: ItemKind) -> String {
        switch kind {
        case .photo: "Photos"
        case .video: "Videos"
        case .file: "Files"
        case .note: "Notes"
        }
    }

    private static func otherKinds(_ kind: ItemKind) -> String {
        switch kind {
        case .photo: "Videos, files and notes"
        case .video: "Photos, files and notes"
        case .file: "Photos, videos and notes"
        case .note: "Photos, videos and files"
        }
    }
}
