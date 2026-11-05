import XCTest
@testable import CipherRoll

@MainActor
final class SettingsRulesTests: XCTestCase {
    func testConsentGateDropsEventsUntilAllowed() {
        let (model, sink) = makeSettings()
        model.gate.track("home_viewed", properties: [:])
        XCTAssertTrue(sink.events.isEmpty)
        model.allowStats()
        XCTAssertEqual(sink.events.map(\.name), ["analytics_consent_answered"])
        XCTAssertEqual(sink.events.first?.properties["answer"], "allowed")
        model.gate.track("home_viewed", properties: [:])
        XCTAssertEqual(sink.events.count, 2)
    }

    func testDeclinedConsentIsNotSent() {
        let (model, sink) = makeSettings()
        model.declineStats()
        model.gate.track("home_viewed", properties: [:])
        XCTAssertTrue(sink.events.isEmpty)
        XCTAssertEqual(model.consent, .declined)
    }

    func testTurningStatsOffSendsTheChangeBeforeStopping() {
        let (model, sink) = makeSettings()
        model.allowStats()
        sink.events.removeAll()
        model.setUsageStats(false)
        XCTAssertEqual(sink.events.map(\.name), ["analytics_consent_changed"])
        XCTAssertEqual(sink.events.first?.properties["on"], "false")
        model.gate.track("later", properties: [:])
        XCTAssertEqual(sink.events.count, 1)
        XCTAssertFalse(model.gate.allowed)
    }

    func testUnlockPropertiesDoNotNameAVault() {
        let properties = UnlockAnalytics.properties(method: "secret")
        XCTAssertEqual(properties, ["method": "secret"])
        XCTAssertFalse(UnlockAnalytics.namesAVault(properties))
        XCTAssertFalse(UnlockAnalytics.namesAVault(UnlockAnalytics.properties(method: "face_id")))
        XCTAssertTrue(UnlockAnalytics.namesAVault(["method": "decoy"]))
    }

    func testBreakInCapturesOnlyOnTheThirdWrongPINWhenEnabled() {
        XCTAssertFalse(BreakInPolicy.shouldCapture(enabled: true, attempts: 2))
        XCTAssertTrue(BreakInPolicy.shouldCapture(enabled: true, attempts: 3))
        XCTAssertFalse(BreakInPolicy.shouldCapture(enabled: true, attempts: 4))
        XCTAssertFalse(BreakInPolicy.shouldCapture(enabled: false, attempts: 3))
    }

    func testLockDelay() {
        let now = Date()
        XCTAssertTrue(LockDelay.shouldLock(since: nil, delay: .immediately, now: now))
        XCTAssertTrue(LockDelay.shouldLock(since: now.addingTimeInterval(-1), delay: .immediately, now: now))
        XCTAssertFalse(LockDelay.shouldLock(since: now.addingTimeInterval(-30), delay: .oneMinute, now: now))
        XCTAssertTrue(LockDelay.shouldLock(since: now.addingTimeInterval(-60), delay: .oneMinute, now: now))
        XCTAssertFalse(LockDelay.shouldLock(since: now.addingTimeInterval(-120), delay: .fiveMinutes, now: now))
    }

    func testDecoyCopyIncludesTheForgottenPINWarning() {
        XCTAssertTrue(SettingsCopy.decoyForgotten.contains("forget the decoy PIN"))
        XCTAssertTrue(SettingsCopy.decoyForgotten.contains("recovery key does not cover"))
        XCTAssertTrue(SettingsCopy.decoyPINDetail.contains("not covered by your recovery key"))
    }

    func testSettingsCopyAvoidsBannedClaims() {
        let text = SettingsCopy.scanned.lowercased()
        for banned in ["encrypted", "military", "unhackable", "nobody can see", "monthly", "last chance", "expires", "locked out"] {
            XCTAssertFalse(text.contains(banned), banned)
        }
        XCTAssertTrue(text.contains("vault contents stay on this iphone"))
        XCTAssertTrue(text.contains("not backed up") == false)
        XCTAssertTrue(SettingsCopy.backupLater.contains("protected by the password you choose"))
    }

    func testAlternateIconNames() {
        XCTAssertNil(AppIconChoice.crLock.alternateName)
        XCTAssertEqual(AppIconChoice.calculator.alternateName, "Calculator")
        XCTAssertEqual(AppIconChoice.notes.alternateName, "Notes")
        XCTAssertEqual(AppIconChoice.weather.alternateName, "Weather")
        XCTAssertEqual(AppIconChoice.utility.alternateName, "Utility")
        XCTAssertEqual(AppIconChoice.allCases.count, 5)
    }

    func testDecoyPaywallTriggerName() {
        XCTAssertEqual(PaywallTrigger.decoyVault.rawValue, "decoy_vault")
    }

    private func makeSettings() -> (SettingsModel, RecordingAnalyticsClient) {
        let name = "settings-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        let sink = RecordingAnalyticsClient()
        let gate = GatedAnalyticsClient()
        gate.sink = sink
        return (SettingsModel(gate: gate, defaults: defaults), sink)
    }
}
