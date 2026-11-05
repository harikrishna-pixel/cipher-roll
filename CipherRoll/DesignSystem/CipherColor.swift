import SwiftUI
import UIKit

struct CipherPaletteEntry: Identifiable {
    let name: String
    let light: UInt32
    let dark: UInt32

    var id: String { name }

    var color: Color {
        Color(uiColor: uiColor)
    }

    var uiColor: UIColor {
        UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return CipherPaletteEntry.opaque(hex)
        }
    }

    fileprivate static func opaque(_ hex: UInt32) -> UIColor {
        let red = CGFloat((hex >> 16) & 0xFF) / 255
        let green = CGFloat((hex >> 8) & 0xFF) / 255
        let blue = CGFloat(hex & 0xFF) / 255
        return UIColor(red: red, green: green, blue: blue, alpha: 1)
    }
}

enum CipherColor {
    static let catalog: [CipherPaletteEntry] = [
        CipherPaletteEntry(name: "bg", light: 0xF4F5F7, dark: 0x0B1220),
        CipherPaletteEntry(name: "card", light: 0xFFFFFF, dark: 0x141E31),
        CipherPaletteEntry(name: "ink", light: 0x101828, dark: 0xF2F5FA),
        CipherPaletteEntry(name: "sub", light: 0x4F5A6D, dark: 0xB3BDD0),
        CipherPaletteEntry(name: "line", light: 0xDDE1E8, dark: 0x2A3754),
        CipherPaletteEntry(name: "hero", light: 0x14233B, dark: 0x1B2B4A),
        CipherPaletteEntry(name: "gold", light: 0xE0B050, dark: 0xE6BE6A),
        CipherPaletteEntry(name: "onGold", light: 0x14233B, dark: 0x14233B),
        CipherPaletteEntry(name: "tint", light: 0xE8EEF7, dark: 0x22324F),
        CipherPaletteEntry(name: "tintInk", light: 0x1F3A5F, dark: 0xB5CCF2),
        CipherPaletteEntry(name: "link", light: 0x1F3A5F, dark: 0xB5CCF2),
        CipherPaletteEntry(name: "amber", light: 0xB7791F, dark: 0xE8B04A),
        CipherPaletteEntry(name: "amberBg", light: 0xFFF4DC, dark: 0x3A2D12),
        CipherPaletteEntry(name: "danger", light: 0xC2412D, dark: 0xF0836F)
    ]

    static let bg = color("bg")
    static let card = color("card")
    static let ink = color("ink")
    static let sub = color("sub")
    static let line = color("line")
    static let hero = color("hero")
    static let gold = color("gold")
    static let onGold = color("onGold")
    static let tint = color("tint")
    static let tintInk = color("tintInk")
    static let link = color("link")
    static let amber = color("amber")
    static let amberBg = color("amberBg")
    static let danger = color("danger")

    static func entry(_ name: String) -> CipherPaletteEntry? {
        catalog.first { $0.name == name }
    }

    private static func color(_ name: String) -> Color {
        guard let entry = entry(name) else {
            preconditionFailure("Missing colour token \(name)")
        }
        return entry.color
    }
}
