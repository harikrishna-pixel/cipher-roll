import SwiftUI

struct CipherScreen<Content: View>: View {
    var width: CipherWidth = .form
    @Environment(\.horizontalSizeClass) private var sizeClass
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            CipherColor.bg.ignoresSafeArea()
            framed
        }
    }

    @ViewBuilder
    private var framed: some View {
        let stage = width == .stage && CipherLayout.usesSidebar(sizeClass)
        if stage {
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            content()
                .frame(maxWidth: CipherLayout.formMaxWidth)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct CipherBackButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(CipherColor.ink)
                .frame(width: 44, height: 44)
                .background(CipherColor.card, in: Circle())
        }
        .accessibilityLabel("Back")
    }
}

struct CipherPageDots: View {
    var count: Int
    var index: Int
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { item in
                Capsule()
                    .fill(item == index ? active : CipherColor.line)
                    .frame(width: item == index ? 18 : 6, height: 6)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel("Step \(index + 1) of \(count)")
    }

    private var active: Color { scheme == .dark ? CipherColor.gold : CipherColor.hero }
}

struct CipherTextButton: View {
    var title: String
    var action: () -> Void

    var body: some View {
        Button(title, action: action)
            .font(CipherFont.button)
            .foregroundStyle(CipherColor.sub)
            .frame(minHeight: 44)
    }
}

struct StatusLine: View {
    var text: String?

    var body: some View {
        Text(text ?? " ")
            .font(CipherFont.caption)
            .foregroundStyle(CipherColor.danger)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 18)
            .accessibilityHidden(text == nil)
    }
}

struct PrivacyCover: View {
    var body: some View {
        ZStack {
            CipherColor.hero.ignoresSafeArea()
            VStack(spacing: CipherSpace.s12) {
                CipherIcon.lock.image
                    .foregroundStyle(CipherColor.gold)
                    .frame(width: 56, height: 56)
                    .background(CipherColor.card.opacity(0.15), in: RoundedRectangle(cornerRadius: 16))
                Text("CipherRoll")
                    .font(CipherFont.h2)
                    .foregroundStyle(CipherColor.gold)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("CipherRoll is covered")
    }
}

struct PinDots: View {
    var count: Int
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: CipherSpace.s8) {
            HStack(spacing: 12) {
                ForEach(0..<PinDraft.minimumDigits, id: \.self) { index in
                    Circle()
                        .fill(index < min(count, PinDraft.minimumDigits) ? active : Color.clear)
                        .overlay(Circle().stroke(active.opacity(index < count ? 1 : 0.35), lineWidth: 1.5))
                        .frame(width: 14, height: 14)
                }
            }
            if count > PinDraft.minimumDigits {
                Text("\(count) digits")
                    .font(CipherFont.caption)
                    .foregroundStyle(CipherColor.sub)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(count) digits entered")
    }

    private var active: Color { scheme == .dark ? CipherColor.gold : CipherColor.hero }
}

struct PinPad: View {
    var showsBiometry: Bool
    var onDigit: (String) -> Void
    var onDelete: () -> Void
    var onBiometry: () -> Void

    private let rows = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"]]

    var body: some View {
        VStack(spacing: CipherSpace.s16) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: CipherSpace.s20) {
                    ForEach(row, id: \.self) { digit in
                        key(digit) { onDigit(digit) }
                    }
                }
            }
            HStack(spacing: CipherSpace.s20) {
                if showsBiometry {
                    Button(action: onBiometry) {
                        CipherIcon.face.image
                            .foregroundStyle(CipherColor.ink)
                            .frame(width: 72, height: 72)
                    }
                    .accessibilityLabel(BiometryLabel.current())
                    .frame(width: 72)
                } else {
                    Color.clear.frame(width: 72, height: 72).accessibilityHidden(true)
                }
                key("0") { onDigit("0") }
                Button(action: onDelete) {
                    Image(systemName: "delete.left")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(CipherColor.ink)
                        .frame(width: 72, height: 72)
                        .background(CipherColor.card, in: Circle())
                }
                .accessibilityLabel("Delete")
            }
        }
    }

    private func key(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(CipherFont.titleSmall)
                .foregroundStyle(CipherColor.ink)
                .frame(width: 72, height: 72)
                .background(CipherColor.card, in: Circle())
        }
        .accessibilityLabel(title)
    }
}
