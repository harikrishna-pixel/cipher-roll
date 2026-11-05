import SwiftUI
import UIKit

@MainActor
final class SettingsModel: ObservableObject {
    @Published var consent: ConsentChoice?
    @Published var breakIn = false
    @Published var lockDelay: LockDelay = .immediately
    @Published var icon: AppIconChoice = .crLock
    @Published var photos: [BreakInPhoto] = []
    @Published var message: String?

    let gate: GatedAnalyticsClient
    private let defaults: UserDefaults

    init(gate: GatedAnalyticsClient = GatedAnalyticsClient(), defaults: UserDefaults = AppGroupDefaults.suite) {
        self.gate = gate
        self.defaults = defaults
        consent = ConsentChoice(rawValue: defaults.string(forKey: SettingsKeys.consent) ?? "")
        breakIn = defaults.bool(forKey: SettingsKeys.breakIn)
        lockDelay = LockDelay(rawValue: defaults.integer(forKey: SettingsKeys.lockDelay)) ?? .immediately
        gate.allowed = consent == .allowed
        if let current = UIApplication.shared.alternateIconName {
            icon = AppIconChoice.allCases.first { $0.alternateName == current } ?? .crLock
        }
    }

    var usageStatsOn: Bool { consent == .allowed }

    func allowStats() {
        consent = .allowed
        defaults.set(ConsentChoice.allowed.rawValue, forKey: SettingsKeys.consent)
        gate.allowed = true
        gate.track("analytics_consent_answered", properties: ["answer": "allowed"])
    }

    func declineStats() {
        consent = .declined
        defaults.set(ConsentChoice.declined.rawValue, forKey: SettingsKeys.consent)
        gate.allowed = false
    }

    func setUsageStats(_ on: Bool) {
        if on {
            consent = .allowed
            defaults.set(ConsentChoice.allowed.rawValue, forKey: SettingsKeys.consent)
            gate.allowed = true
            gate.track("analytics_consent_changed", properties: ["on": "true"])
        } else {
            gate.track("analytics_consent_changed", properties: ["on": "false"])
            consent = .declined
            defaults.set(ConsentChoice.declined.rawValue, forKey: SettingsKeys.consent)
            gate.allowed = false
        }
    }

    func setBreakIn(_ on: Bool) {
        breakIn = on
        defaults.set(on, forKey: SettingsKeys.breakIn)
        gate.track("breakin_selfie_toggled", properties: ["on": on ? "true" : "false"])
        if on { reloadPhotos() }
    }

    func setDelay(_ delay: LockDelay) {
        lockDelay = delay
        defaults.set(delay.rawValue, forKey: SettingsKeys.lockDelay)
        gate.track("lock_delay_changed", properties: ["value": delay.title])
    }

    func selectIcon(_ choice: AppIconChoice) {
        UIApplication.shared.setAlternateIconName(choice.alternateName) { [weak self] error in
            DispatchQueue.main.async {
                guard let self else { return }
                if error == nil {
                    self.icon = choice
                    self.gate.track("app_icon_changed", properties: ["icon": choice.rawValue])
                } else {
                    self.message = "The icon could not be changed on this device."
                }
            }
        }
    }

    func reloadPhotos() {
        photos = BreakInStore.photos()
    }

    func deletePhoto(_ photo: BreakInPhoto) {
        BreakInStore.delete(photo)
        reloadPhotos()
    }
}
