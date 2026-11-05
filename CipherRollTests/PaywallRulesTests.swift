import XCTest
@testable import CipherRoll

final class PaywallRulesTests: XCTestCase {
    func testCatalogPricesAndNoMonthlyPlan() {
        let prices = PlanPrices.catalog
        XCTAssertEqual(prices.weeklyText, "$1.99")
        XCTAssertEqual(prices.yearlyText, "$19.99")
        XCTAssertEqual(prices.lifetimeText, "$39.99")
        XCTAssertEqual(PaidPlan.allCases.map(\.rawValue), ["weekly", "yearly", "lifetime"])
        XCTAssertFalse(PaywallCopy.scannedText.localizedCaseInsensitiveContains("monthly"))
    }

    func testYearlyTrialCopyOnlyWhenEligible() {
        let prices = PlanPrices.catalog
        XCTAssertEqual(PaywallCopy.buttonTitle(.yearly, trialEligible: true), "Start 7 days free")
        XCTAssertEqual(
            PaywallCopy.legal(.yearly, prices: prices, trialEligible: true),
            "Then $19.99/year, renews automatically. Cancel anytime in Settings. We'll remind you before your trial ends."
        )
        XCTAssertEqual(PaywallCopy.badge(.yearly, prices: prices, trialEligible: true), "7 DAYS FREE")
        XCTAssertEqual(PaywallCopy.buttonTitle(.yearly, trialEligible: false), "Unlock unlimited")
        XCTAssertEqual(
            PaywallCopy.legal(.yearly, prices: prices, trialEligible: false),
            "$19.99/year. Renews automatically until cancelled. Cancel anytime in Settings."
        )
        XCTAssertNil(PaywallCopy.badge(.weekly, prices: prices, trialEligible: true))
        XCTAssertFalse(PaywallCopy.showsTrial(false))
    }

    func testWeeklyAndLifetimeButtonsMatchTheHandoff() {
        let prices = PlanPrices.catalog
        XCTAssertEqual(PaywallCopy.buttonTitle(.weekly, trialEligible: true), "Continue with Weekly")
        XCTAssertEqual(
            PaywallCopy.legal(.weekly, prices: prices, trialEligible: true),
            "$1.99/week, renews automatically. Cancel anytime in Settings."
        )
        XCTAssertEqual(PaywallCopy.buttonTitle(.lifetime, trialEligible: false), "Get lifetime access")
        XCTAssertEqual(
            PaywallCopy.legal(.lifetime, prices: prices, trialEligible: false),
            "One payment of $39.99. No subscription. Restore any time."
        )
    }

    func testDismissTextFollowsTheTrigger() {
        XCTAssertEqual(PaywallCopy.dismissTitle(.onboarding), "Maybe later")
        XCTAssertEqual(PaywallCopy.dismissTitle(.valueFraming), "Maybe later")
        XCTAssertEqual(PaywallCopy.dismiss(.exit), .continueFree)
        XCTAssertEqual(PaywallCopy.dismissTitle(.limitVideos), "Continue with Free")
        XCTAssertEqual(PaywallCopy.dismissTitle(.limitPhotos), "Continue with Free")
    }

    func testYearlyWorksOutToTheShownWeeklyPrice() {
        let prices = PlanPrices.catalog
        XCTAssertEqual(PaywallMath.perWeekText(yearly: prices.yearly), "$0.38")
        XCTAssertEqual(PaywallMath.savePercent(weekly: prices.weekly, yearly: prices.yearly), 81)
    }

    func testExitOfferControlShowsNothingAndTreatmentShowsOnce() {
        XCTAssertEqual(ExitOffer.cell(seed: 2), .control)
        XCTAssertEqual(ExitOffer.cell(seed: 3), .treatment)
        XCTAssertFalse(ExitOffer.shouldPresent(cell: .control, alreadyShown: false))
        XCTAssertTrue(ExitOffer.shouldPresent(cell: .treatment, alreadyShown: false))
        XCTAssertFalse(ExitOffer.shouldPresent(cell: .treatment, alreadyShown: true))
    }

    func testPlanEndingKeepsOneVaultEditableAndDeletesNothing() {
        let vaults = [
            EndedVault(id: "personal", name: "Personal", summary: "85 photos", editable: false),
            EndedVault(id: "work", name: "Work", summary: "12 photos", editable: false)
        ]
        let assigned = PlanEnding.assign(vaults: vaults, keepID: "personal")
        XCTAssertEqual(assigned.map(\.id), ["personal", "work"])
        XCTAssertEqual(assigned.map(\.summary), ["85 photos", "12 photos"])
        XCTAssertTrue(assigned[0].editable)
        XCTAssertFalse(assigned[1].editable)
        XCTAssertTrue(PlanAccess.canAdd(tier: .free, vaultEditable: true, kind: .photo, used: 99))
        XCTAssertFalse(PlanAccess.canAdd(tier: .free, vaultEditable: true, kind: .photo, used: 100))
        XCTAssertFalse(PlanAccess.canAdd(tier: .free, vaultEditable: false, kind: .photo, used: 0))
        XCTAssertTrue(PlanAccess.canAdd(tier: .trial, vaultEditable: true, kind: .video, used: 10))
        XCTAssertTrue(PlanAccess.canAdd(tier: .lifetime, vaultEditable: true, kind: .note, used: 40))
    }

    func testTrialReminderIsDaySixAndOnlyWhenAllowed() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let fire = TrialReminder.fireDate(trialStart: start, calendar: calendar)
        XCTAssertEqual(fire.timeIntervalSince(start), 6 * 86_400)
        XCTAssertTrue(TrialReminder.shouldSchedule(fire: fire, now: start, notificationsAllowed: true, alreadyScheduled: false))
        XCTAssertFalse(TrialReminder.shouldSchedule(fire: fire, now: start, notificationsAllowed: false, alreadyScheduled: false))
        XCTAssertFalse(TrialReminder.shouldSchedule(fire: fire, now: start, notificationsAllowed: true, alreadyScheduled: true))
        XCTAssertFalse(TrialReminder.body.localizedCaseInsensitiveContains("expires"))
    }

    func testCopyAvoidsBannedClaims() {
        let text = PaywallCopy.scannedText.lowercased()
        for banned in ["encrypted", "military", "unhackable", "nobody can see", "monthly", "last chance", "locked out"] {
            XCTAssertFalse(text.contains(banned), banned)
        }
    }

    func testOfflineAndTrialUsedVariants() {
        XCTAssertEqual(PaywallCopy.variant(trialEligible: true, selected: .yearly, offline: false), "yearly")
        XCTAssertEqual(PaywallCopy.variant(trialEligible: false, selected: .yearly, offline: false), "trial_used")
        XCTAssertEqual(PaywallCopy.variant(trialEligible: true, selected: .weekly, offline: true), "offline")
        XCTAssertEqual(PaywallCopy.header(trigger: .limitVideos, trialEligible: true, limitKind: .video, itemCount: 0).title, "Room for all your videos.")
    }
}
