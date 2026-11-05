import SwiftUI

struct CipherGoldButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(CipherFont.button)
            .foregroundStyle(CipherColor.onGold)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .frame(minHeight: CipherA11y.minimumTarget)
            .padding(.horizontal, CipherSpace.s16)
            .background(CipherColor.gold, in: Capsule())
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(animation, value: configuration.isPressed)
    }

    private var animation: Animation {
        .easeOut(duration: CipherA11y.duration(reduceMotion: reduceMotion))
    }
}

struct CipherOutlineButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(CipherFont.button)
            .foregroundStyle(CipherColor.ink)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .frame(minHeight: CipherA11y.minimumTarget)
            .padding(.horizontal, CipherSpace.s16)
            .background(CipherColor.card, in: Capsule())
            .overlay(Capsule().stroke(CipherColor.line, lineWidth: 1.5))
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(animation, value: configuration.isPressed)
    }

    private var animation: Animation {
        .easeOut(duration: CipherA11y.duration(reduceMotion: reduceMotion))
    }
}
