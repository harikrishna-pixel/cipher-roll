import XCTest
@testable import CipherRoll

final class AccessibilityQATests: XCTestCase {
    func testMotionAndTouchTargetMatchTheHandoff() {
        XCTAssertEqual(CipherA11y.minimumTarget, 44)
        XCTAssertEqual(CipherA11y.standardMotion, 0.25)
        XCTAssertGreaterThanOrEqual(CipherA11y.reducedMotion, 0.12)
        XCTAssertLessThanOrEqual(CipherA11y.reducedMotion, 0.18)
        XCTAssertEqual(CipherA11y.duration(reduceMotion: true), CipherA11y.reducedMotion)
        XCTAssertEqual(CipherA11y.duration(reduceMotion: false), CipherA11y.standardMotion)
    }

    func testBodyTextPairsClearContrast() {
        let pairs: [(UInt32, UInt32)] = [
            (0x101828, 0xF4F5F7),
            (0x4F5A6D, 0xF4F5F7),
            (0x101828, 0xFFFFFF),
            (0x14233B, 0xE0B050),
            (0x14233B, 0xE6BE6A),
            (0xFFFFFF, 0x14233B),
            (0xF2F5FA, 0x0B1220),
            (0xB3BDD0, 0x0B1220),
            (0xB3BDD0, 0x141E31),
            (0x1F3A5F, 0xF4F5F7),
            (0xC2412D, 0xF4F5F7)
        ]
        for pair in pairs {
            XCTAssertTrue(
                Contrast.passesBodyText(pair.0, pair.1),
                String(format: "%06X on %06X is %.2f", pair.0, pair.1, Contrast.ratio(pair.0, pair.1))
            )
        }
    }

    func testItemCountsUseASingular() {
        XCTAssertEqual(ItemCountCopy.label(0), "0 items")
        XCTAssertEqual(ItemCountCopy.label(1), "1 item")
        XCTAssertEqual(ItemCountCopy.label(2), "2 items")
    }

    func testDeclinedConsentSendsNothingAndAllowedEventsHaveNoContent() {
        let gate = GatedAnalyticsClient()
        let sink = RecordingAnalyticsClient()
        gate.sink = sink
        gate.track("home_viewed", properties: [:])
        gate.track("vault_unlocked", properties: ["pin": "135790"])
        XCTAssertTrue(sink.events.isEmpty)

        gate.allowed = true
        gate.track("vault_unlocked", properties: UnlockAnalytics.properties(method: "face_id"))
        gate.track("vault_unlocked", properties: UnlockAnalytics.properties(method: "secret"))
        XCTAssertEqual(sink.events.map(\.name), ["vault_unlocked", "vault_unlocked"])
        for event in sink.events {
            XCTAssertFalse(AnalyticsPrivacy.namesContent(event.properties))
            XCTAssertFalse(UnlockAnalytics.namesAVault(event.properties))
            XCTAssertEqual(Set(event.properties.keys), ["method"])
        }
        XCTAssertTrue(AnalyticsPrivacy.namesContent(["filename": "holiday.jpg"]))
        XCTAssertTrue(AnalyticsPrivacy.namesContent(["query": "passport"]))
    }

    func testShareLimitLeavesTheOriginal() {
        XCTAssertTrue(ShareRules.leavesOriginal)
        let message = ShareRules.limitMessage(kind: .photo).lowercased()
        XCTAssertTrue(message.contains("nothing was removed"))
        XCTAssertFalse(message.contains("deleted"))
        XCTAssertEqual(ShareRules.saveButton(count: 1), "Save 1 item")
    }

    func testReviewedCopyAvoidsBannedClaims() {
        let scanned = [
            LockCopy.reviewStrings.joined(separator: "\n"),
            SettingsCopy.scanned,
            PaywallCopy.scannedText,
            HelpCatalog.scanned,
            ShareRules.scanned,
            ReferralRules.unavailable
        ].joined(separator: "\n").lowercased()
        for phrase in ["encrypted", "military", "unhackable", "nobody can see"] {
            XCTAssertFalse(scanned.contains(phrase), phrase)
        }
        XCTAssertTrue(scanned.contains("not a real calculator"))
        XCTAssertTrue(scanned.contains("protected by the password you choose"))
        XCTAssertTrue(scanned.contains("vault contents stay on this iphone"))
    }
}
