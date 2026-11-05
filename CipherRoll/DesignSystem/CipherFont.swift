import SwiftUI

enum CipherFont {
    /// Title sits between 28 and 30, ExtraBold.
    static let title = custom("Manrope-ExtraBold", size: 30, relativeTo: .largeTitle)
    static let titleSmall = custom("Manrope-ExtraBold", size: 28, relativeTo: .title)
    static let h2 = custom("Manrope-ExtraBold", size: 20, relativeTo: .title3)
    static let body = custom("Manrope-Medium", size: 16, relativeTo: .body)
    static let button = custom("Manrope-SemiBold", size: 16, relativeTo: .body)
    static let caption = custom("Manrope-SemiBold", size: 13, relativeTo: .footnote)

    static let registeredNames = [
        "Manrope-Medium",
        "Manrope-SemiBold",
        "Manrope-Bold",
        "Manrope-ExtraBold"
    ]

    private static func custom(_ name: String, size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        .custom(name, size: size, relativeTo: style)
    }
}
