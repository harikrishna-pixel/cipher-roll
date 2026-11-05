import UIKit
import XCTest
@testable import CipherRoll

final class DesignSystemTests: XCTestCase {
    func testPaletteMatchesTheHandoff() {
        let expected: [String: (UInt32, UInt32)] = [
            "bg": (0xF4F5F7, 0x0B1220),
            "card": (0xFFFFFF, 0x141E31),
            "ink": (0x101828, 0xF2F5FA),
            "sub": (0x4F5A6D, 0xB3BDD0),
            "line": (0xDDE1E8, 0x2A3754),
            "hero": (0x14233B, 0x1B2B4A),
            "gold": (0xE0B050, 0xE6BE6A),
            "onGold": (0x14233B, 0x14233B),
            "tint": (0xE8EEF7, 0x22324F),
            "tintInk": (0x1F3A5F, 0xB5CCF2),
            "link": (0x1F3A5F, 0xB5CCF2),
            "amber": (0xB7791F, 0xE8B04A),
            "amberBg": (0xFFF4DC, 0x3A2D12),
            "danger": (0xC2412D, 0xF0836F)
        ]

        XCTAssertEqual(CipherColor.catalog.count, expected.count)
        for entry in CipherColor.catalog {
            let pair = expected[entry.name]
            XCTAssertEqual(pair?.0, entry.light, entry.name)
            XCTAssertEqual(pair?.1, entry.dark, entry.name)
        }
    }

    func testOnGoldStaysNavyInLightAndDark() {
        let entry = CipherColor.entry("onGold")
        let light = entry?.uiColor.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        let dark = entry?.uiColor.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
        XCTAssertEqual(light?.hexRGB, 0x14233B)
        XCTAssertEqual(dark?.hexRGB, 0x14233B)
    }

    func testBackgroundFollowsInterfaceStyle() {
        let entry = CipherColor.entry("bg")
        let light = entry?.uiColor.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        let dark = entry?.uiColor.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
        XCTAssertEqual(light?.hexRGB, 0xF4F5F7)
        XCTAssertEqual(dark?.hexRGB, 0x0B1220)
    }

    func testSpacingAndRadii() {
        XCTAssertEqual(
            [CipherSpace.s4, CipherSpace.s8, CipherSpace.s12, CipherSpace.s16, CipherSpace.s20, CipherSpace.s24],
            [4, 8, 12, 16, 20, 24]
        )
        XCTAssertEqual(CipherRadius.card, 20)
        XCTAssertEqual(CipherRadius.button, 28)
        XCTAssertEqual(CipherRadius.chip, 999)
        XCTAssertEqual(CipherRadius.sheet, 28)
    }

    func testIconSetMatchesTheHandoff() {
        XCTAssertEqual(
            CipherIcon.allCases.map(\.rawValue),
            ["lock", "image", "video", "file", "note", "key", "eye", "face", "shield", "search", "share"]
        )
    }

    func testManropeWeightsAreRegistered() {
        let registered = UIFont.familyNames
            .flatMap { UIFont.fontNames(forFamilyName: $0) }
            .filter { $0.localizedCaseInsensitiveContains("manrope") }
        for name in CipherFont.registeredNames {
            XCTAssertNotNil(UIFont(name: name, size: 16), "\(name) missing. Registered: \(registered)")
        }
    }

    func testNoOpAnalyticsAcceptsAnEvent() {
        let client = NoOpAnalyticsClient()
        client.track("app_opened", properties: [:])
    }
}

private extension UIColor {
    var hexRGB: UInt32 {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (UInt32(round(red * 255)) << 16)
            | (UInt32(round(green * 255)) << 8)
            | UInt32(round(blue * 255))
    }
}
