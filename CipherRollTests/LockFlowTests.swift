import LocalAuthentication
import XCTest
@testable import CipherRoll

final class LockFlowTests: XCTestCase {
    func testPINContinueNeedsSixDigits() {
        XCTAssertFalse(PinDraft.canContinue("1357"))
        XCTAssertFalse(PinDraft.canContinue("13579"))
        XCTAssertTrue(PinDraft.canContinue("135790"))
        XCTAssertFalse(PinDraft.canContinue("13579a"))
        XCTAssertEqual(PinDraft.appending("1", to: "135790"), "1357901")
        XCTAssertEqual(PinDraft.appending("1", to: String(repeating: "1", count: 12)), String(repeating: "1", count: 12))
    }

    func testPatternNeedsSixUniqueDots() {
        XCTAssertFalse(PatternDraft.canSubmit([0, 1, 2, 3]))
        XCTAssertFalse(PatternDraft.canSubmit([0, 1, 2, 3, 4]))
        XCTAssertFalse(PatternDraft.canSubmit([0, 1, 2, 3, 4, 4]))
        XCTAssertTrue(PatternDraft.canSubmit([0, 3, 6, 7, 4, 2]))
    }

    func testSavedKeyStaysOffUntilTheTestPasses() {
        XCTAssertFalse(RecoveryConfirmation.allowsSave(tested: false))
        XCTAssertTrue(RecoveryConfirmation.allowsSave(tested: true))
    }

    func testRecoveryDraftSplitsWords() {
        let words = RecoveryConfirmation.words(from: "  Abandon\nAbility  ABLE ")
        XCTAssertEqual(words, ["abandon", "ability", "able"])
    }

    func testTwoFaceIDFailuresMoveToTheSecretLock() {
        XCTAssertFalse(BiometryAttempt.shouldFallBackToSecret(failures: 1))
        XCTAssertTrue(BiometryAttempt.shouldFallBackToSecret(failures: 2))
    }

    func testAppSwitcherCoverShowsWhileInactive() {
        XCTAssertTrue(AppSwitcherPolicy.covers(.inactive))
        XCTAssertTrue(AppSwitcherPolicy.covers(.background))
        XCTAssertFalse(AppSwitcherPolicy.covers(.active))
        XCTAssertTrue(AppSwitcherPolicy.locksOnReturn(from: .background))
        XCTAssertFalse(AppSwitcherPolicy.locksOnReturn(from: .inactive))
    }

    func testPINChooserDoesNotOfferFourDigits() {
        XCTAssertFalse(LockCopy.pinDetail.contains("4"))
        XCTAssertEqual(LockCopy.pinDetail, "At least 6 digits. Quick to enter.")
        XCTAssertEqual(LockCopy.patternHint, "Connect at least 6 dots")
    }

    func testCopyAvoidsBannedClaims() {
        let banned = ["encrypted", "military", "unhackable", "nobody can see"]
        let joined = LockCopy.reviewStrings.joined(separator: "\n").lowercased()
        for word in banned {
            XCTAssertFalse(joined.contains(word), word)
        }
    }

    func testBiometryNameFollowsTheDevice() {
        XCTAssertEqual(BiometryLabel.name(for: .faceID), "Face ID")
        XCTAssertEqual(BiometryLabel.name(for: .touchID), "Touch ID")
        XCTAssertEqual(BiometryLabel.name(for: .none), "Biometrics")
    }

    func testCalculatorEqualsSubmitsOnlyALongEntry() {
        var state = CalculatorEntry.State()
        XCTAssertNil(CalculatorEntry.tap("1", state: &state))
        XCTAssertNil(CalculatorEntry.tap("+", state: &state))
        XCTAssertNil(CalculatorEntry.tap("2", state: &state))
        XCTAssertNil(CalculatorEntry.tap("=", state: &state))
        XCTAssertEqual(state.display, "3")

        state = CalculatorEntry.State()
        for digit in ["1", "3", "5", "7", "9", "0"] {
            XCTAssertNil(CalculatorEntry.tap(digit, state: &state))
        }
        XCTAssertEqual(CalculatorEntry.tap("=", state: &state), "135790")
    }

    func testSecretCodecRoundTrip() throws {
        let secrets: [LockSecret] = [
            .pin("135790"),
            .password("correct horse"),
            .phrase("blue-kite-river-42"),
            .pattern([0, 3, 6, 7, 4, 2])
        ]
        for secret in secrets {
            XCTAssertEqual(try LockSecretCodec.decode(LockSecretCodec.encode(secret)), secret)
        }
    }
}
