import Foundation

enum CipherA11y {
    static let minimumTarget: CGFloat = 44
    /// 150 ms sits inside the 120–180 ms Reduce Motion fade.
    static let reducedMotion: Double = CipherMotion.reduced
    static let standardMotion: Double = CipherMotion.standard

    static func duration(reduceMotion: Bool) -> Double {
        reduceMotion ? reducedMotion : standardMotion
    }
}

enum ItemCountCopy {
    static func label(_ count: Int) -> String {
        count == 1 ? "1 item" : "\(count) items"
    }
}

enum Contrast {
    /// WCAG relative-luminance ratio for two opaque sRGB colours.
    static func ratio(_ foreground: UInt32, _ background: UInt32) -> Double {
        let lighter = max(luminance(foreground), luminance(background))
        let darker = min(luminance(foreground), luminance(background))
        return (lighter + 0.05) / (darker + 0.05)
    }

    static func passesBodyText(_ foreground: UInt32, _ background: UInt32) -> Bool {
        ratio(foreground, background) >= 4.5
    }

    private static func luminance(_ hex: UInt32) -> Double {
        func channel(_ value: UInt32) -> Double {
            let s = Double(value) / 255
            return s <= 0.04045 ? s / 12.92 : pow((s + 0.055) / 1.055, 2.4)
        }
        let red = channel((hex >> 16) & 0xFF)
        let green = channel((hex >> 8) & 0xFF)
        let blue = channel(hex & 0xFF)
        return 0.2126 * red + 0.7152 * green + 0.0722 * blue
    }
}
