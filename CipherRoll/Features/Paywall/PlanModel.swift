import StoreKit
import SwiftUI
import UserNotifications

struct PaywallRequest: Identifiable, Equatable {
    var id = UUID()
    var trigger: PaywallTrigger
    var limitKind: ItemKind?
    var itemCount: Int = 0
}

@MainActor
final class PlanModel: ObservableObject {
    @Published var tier: PlanTier = .free
    @Published var trialEligible = false
    @Published var prices = PlanPrices.catalog
    @Published var offline = false
    @Published var selected: PaidPlan = .yearly
    @Published var paywall: PaywallRequest?
    @Published var showTrialEnded = false
    @Published var showRestoreNone = false
    @Published var endedVaults: [EndedVault] = []
    @Published var message: String?
    @Published var restoring = false
    @Published var managing = false
    @Published private(set) var keptVaultID = "personal"

    private let client: any PurchaseClient
    private let defaults: UserDefaults
    private var analytics: any AnalyticsClient = NoOpAnalyticsClient()
    private var didAttach = false

    init(client: (any PurchaseClient)? = nil, defaults: UserDefaults = .standard) {
        self.client = client ?? PurchaseClientFactory.make()
        self.defaults = defaults
        if defaults.string(forKey: Keys.exitCell) == nil {
            let seed = UInt64(bitPattern: Int64(UUID().hashValue))
            defaults.set(ExitOffer.cell(seed: seed).rawValue, forKey: Keys.exitCell)
        }
        if let raw = defaults.string(forKey: Keys.tier), let stored = PlanTier(rawValue: raw) {
            tier = stored
            AppGroupDefaults.suite.set(stored.rawValue, forKey: Keys.tier)
        }
        keptVaultID = defaults.string(forKey: Keys.keptVault) ?? "personal"
    }

    var exitCell: ExitOfferCell {
        ExitOfferCell(rawValue: defaults.string(forKey: Keys.exitCell) ?? "") ?? .control
    }

    func attach(_ analytics: any AnalyticsClient) {
        guard !didAttach else { return }
        didAttach = true
        self.analytics = analytics
        Task { await refresh(showOnboarding: true) }
        Task { await listenForTransactions() }
    }

    func refresh(showOnboarding: Bool = false) async {
        let catalog = await client.loadCatalog()
        offline = catalog.offline
        trialEligible = catalog.trialEligible
        if !catalog.offline { prices = catalog.prices }
        let loaded = await client.currentTier()
        apply(loaded)
        if showOnboarding {
            considerOnboardingPaywall()
        }
    }

    func present(_ trigger: PaywallTrigger, limitKind: ItemKind? = nil, itemCount: Int = 0) {
        if trigger == .onboarding {
            defaults.set(true, forKey: Keys.onboardingSeen)
        }
        paywall = PaywallRequest(trigger: trigger, limitKind: limitKind, itemCount: itemCount)
        if trigger == .secondVault {
            analytics.track("pro_feature_tapped", properties: ["feature": "second_vault"])
        }
        analytics.track("paywall_viewed", properties: [
            "trigger": trigger.rawValue,
            "variant": PaywallCopy.variant(trialEligible: trialEligible, selected: selected, offline: offline)
        ])
    }

    func select(_ plan: PaidPlan) {
        selected = plan
        analytics.track("plan_selected", properties: ["plan": plan.rawValue])
    }

    func close(_ dismiss: PaywallDismiss) {
        let trigger = paywall?.trigger
        analytics.track("paywall_closed", properties: ["dismiss": dismiss.rawValue])
        if dismiss == .continueFree, let trigger, trigger.usesContinueFree, trigger != .exit {
            analytics.track("free_alternative_used", properties: ["trigger": trigger.rawValue])
        }
        paywall = nil
        guard trigger == .onboarding else { return }
        guard ExitOffer.shouldPresent(cell: exitCell, alreadyShown: defaults.bool(forKey: Keys.exitShown)) else { return }
        defaults.set(true, forKey: Keys.exitShown)
        analytics.track("exit_offer_shown", properties: ["cell": exitCell.rawValue])
        Task { @MainActor in
            present(.exit)
        }
    }

    func buy() async {
        guard !offline else {
            analytics.track("purchase_offline", properties: ["plan": selected.rawValue])
            message = "Cannot load plans. Your vault still works offline."
            return
        }
        analytics.track("purchase_started", properties: ["plan": selected.rawValue])
        let outcome = await client.purchase(selected)
        switch outcome {
        case .success(let purchased):
            if purchased == .trial {
                analytics.track("trial_started", properties: ["plan": "yearly"])
                await scheduleTrialReminder(from: Date())
            }
            analytics.track("purchase_succeeded", properties: ["plan": purchased.rawValue])
            apply(purchased)
            paywall = nil
        case .cancelled:
            analytics.track("purchase_cancelled", properties: ["plan": selected.rawValue])
        case .pending:
            analytics.track("purchase_pending", properties: ["plan": selected.rawValue])
            message = "That purchase is waiting for approval."
        case .failed(let code):
            analytics.track("purchase_failed", properties: ["code": code])
            message = "That purchase did not finish. Code: \(code)."
        case .offline:
            analytics.track("purchase_offline", properties: ["plan": selected.rawValue])
            offline = true
        }
    }

    func restore() async {
        guard !restoring else { return }
        restoring = true
        defer { restoring = false }
        let outcome = await client.restore()
        switch outcome {
        case .restored(let restored):
            analytics.track("restore_result", properties: ["result": "restored"])
            apply(restored)
            paywall = nil
            message = "Purchases restored."
        case .none:
            analytics.track("restore_result", properties: ["result": "none"])
            // Keep paywall up briefly so the sheet can present without a hard cut.
            showRestoreNone = true
        case .failed(let code):
            analytics.track("restore_result", properties: ["result": "failed", "code": code])
            message = "Restore did not finish. Code: \(code)."
        }
    }

    func manage() {
        analytics.track("manage_subscription_tapped", properties: [:])
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        Task {
            managing = true
            defer { managing = false }
            try? await AppStore.showManageSubscriptions(in: scene)
        }
    }

    func keepEditing(_ id: String) {
        keptVaultID = id
        defaults.set(id, forKey: Keys.keptVault)
        defaults.set(true, forKey: Keys.trialEndedSeen)
        endedVaults = PlanEnding.assign(vaults: endedVaults, keepID: id)
        showTrialEnded = false
    }

    func openPlansFromTrialEnded() {
        showTrialEnded = false
        present(.trialEnded, itemCount: 0)
    }

    private func considerOnboardingPaywall() {
        guard tier == .free else { return }
        guard !defaults.bool(forKey: Keys.onboardingSeen) else { return }
        guard paywall == nil else { return }
        present(.onboarding)
    }

    private func apply(_ loaded: PlanTier) {
        let previous = PlanTier(rawValue: defaults.string(forKey: Keys.tier) ?? "") ?? .free
        tier = loaded
        defaults.set(loaded.rawValue, forKey: Keys.tier)
        AppGroupDefaults.suite.set(loaded.rawValue, forKey: Keys.tier)
        if previous.removesLimits && loaded == .free && !defaults.bool(forKey: Keys.trialEndedSeen) {
            endedVaults = PlanEnding.assign(vaults: [EndedVault(id: "personal", name: "Personal", summary: "This vault", editable: true)], keepID: "personal")
            showTrialEnded = true
            analytics.track("trial_ended_state_viewed", properties: ["plan_before": previous.rawValue])
        }
    }

    private func scheduleTrialReminder(from start: Date) async {
        guard !defaults.bool(forKey: Keys.reminderScheduled) else { return }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let fire = TrialReminder.fireDate(trialStart: start)
        guard TrialReminder.shouldSchedule(
            fire: fire,
            now: Date(),
            notificationsAllowed: settings.authorizationStatus == .authorized,
            alreadyScheduled: false
        ) else { return }
        let content = UNMutableNotificationContent()
        content.title = TrialReminder.title
        content.body = TrialReminder.body
        let interval = max(60, fire.timeIntervalSinceNow)
        let request = UNNotificationRequest(
            identifier: TrialReminder.notificationID,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        )
        try? await UNUserNotificationCenter.current().add(request)
        defaults.set(true, forKey: Keys.reminderScheduled)
        analytics.track("trial_reminder_scheduled", properties: [:])
    }

    private func listenForTransactions() async {
        for await update in Transaction.updates {
            guard case .verified(let transaction) = update else { continue }
            await transaction.finish()
            apply(StoreKitPurchaseClient.tier(for: transaction))
        }
    }

    private enum Keys {
        static let exitCell = "app.cipherroll.plan.exitCell"
        static let exitShown = "app.cipherroll.plan.exitShown"
        static let onboardingSeen = "app.cipherroll.plan.onboardingSeen"
        static let tier = "app.cipherroll.plan.tier"
        static let keptVault = "app.cipherroll.plan.keptVault"
        static let trialEndedSeen = "app.cipherroll.plan.trialEndedSeen"
        static let reminderScheduled = "app.cipherroll.plan.reminderScheduled"
    }
}
