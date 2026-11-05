import LocalAuthentication
import XCTest
@testable import CipherRoll

final class LayoutRulesTests: XCTestCase {
    func testSidebarFollowsRegularWidth() {
        XCTAssertTrue(CipherLayout.usesSidebar(.regular))
        XCTAssertFalse(CipherLayout.usesSidebar(.compact))
        XCTAssertFalse(CipherLayout.usesSidebar(nil))
        XCTAssertEqual(CipherLayout.formMaxWidth, 560)
    }

    func testBiometryNamesComeFromTheType() {
        XCTAssertEqual(BiometryLabel.name(for: .faceID), "Face ID")
        XCTAssertEqual(BiometryLabel.name(for: .touchID), "Touch ID")
        if #available(iOS 17.0, *) {
            XCTAssertEqual(BiometryLabel.name(for: .opticID), "Optic ID")
        }
        XCTAssertEqual(BiometryLabel.symbol(named: "Touch ID"), "touchid")
        XCTAssertEqual(BiometryLabel.symbol(named: "Face ID"), "faceid")
        XCTAssertNotEqual(BiometryLabel.current().isEmpty, true)
    }

    func testHelpUsesTheDeviceBiometryName() {
        let article = HelpCatalog.articles.first { $0.slug == "face-id" }
        let shown = HelpCatalog.showing(article!, biometry: "Touch ID")
        XCTAssertEqual(shown.question, "Is Touch ID the only lock?")
        XCTAssertTrue(shown.answer.contains("Face ID or Touch ID"))
        XCTAssertFalse(shown.question.contains("{biometry}"))
    }

    func testWideWarningsSayDevice() {
        XCTAssertEqual(DeviceCopy.storageTitle(regularWidth: false), "Your vault lives only on this iPhone")
        XCTAssertEqual(DeviceCopy.storageTitle(regularWidth: true), "Your vault lives only on this device")
        XCTAssertTrue(DeviceCopy.storageWarning(regularWidth: true).contains("this device"))
        XCTAssertTrue(DeviceCopy.storageWarning(regularWidth: false).contains("this iPhone"))
        XCTAssertEqual(DeviceCopy.storageRow(regularWidth: true), "Device storage")
    }

    func testByteCountsStayShort() {
        XCTAssertEqual(ByteCountCopy.label(3_200_000), "3.2 MB")
        XCTAssertEqual(ByteCountCopy.label(220_000), "220 KB")
    }

    func testVerticalBarApiIsAbsentOnThisSDK() {
        XCTAssertFalse(VerticalBar.isActive)
    }
}
