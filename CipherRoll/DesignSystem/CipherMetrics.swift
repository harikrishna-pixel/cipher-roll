import CoreGraphics

enum CipherSpace {
    static let s4: CGFloat = 4
    static let s8: CGFloat = 8
    static let s12: CGFloat = 12
    static let s16: CGFloat = 16
    static let s20: CGFloat = 20
    static let s24: CGFloat = 24
}

enum CipherRadius {
    static let card: CGFloat = 20
    static let button: CGFloat = 28
    static let chip: CGFloat = 999
    static let sheet: CGFloat = 28
}

enum CipherMotion {
    static let standard: Double = 0.25
    static let reduced: Double = 0.15
}
