import SwiftUI

final class ThemePreviewModel: ObservableObject {
    enum Appearance: String, CaseIterable, Identifiable {
        case device = "Device"
        case light = "Light"
        case dark = "Dark"

        var id: String { rawValue }

        var colorScheme: ColorScheme? {
            switch self {
            case .device: nil
            case .light: .light
            case .dark: .dark
            }
        }
    }

    @Published var appearance: Appearance = .device
    @Published var buttonNote = "Navy text on gold."
}

struct ThemePreviewView: View {
    @StateObject private var model = ThemePreviewModel()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CipherSpace.s24) {
                    header
                    appearancePicker
                    typeSamples
                    iconSamples
                    colorSamples
                    componentSamples
                }
                .padding(CipherSpace.s20)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .background(CipherColor.bg)
            .navigationTitle("Design system")
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(model.appearance.colorScheme)
        .animation(motion, value: model.appearance)
    }

    private var motion: Animation {
        .easeOut(duration: reduceMotion ? CipherMotion.reduced : CipherMotion.standard)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: CipherSpace.s8) {
            Text("CipherRoll")
                .font(CipherFont.title)
                .foregroundStyle(CipherColor.ink)
            Text("Vault contents stay on this iPhone.")
                .font(CipherFont.body)
                .foregroundStyle(CipherColor.sub)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var appearancePicker: some View {
        Picker("Appearance", selection: $model.appearance) {
            ForEach(ThemePreviewModel.Appearance.allCases) { appearance in
                Text(appearance.rawValue).tag(appearance)
            }
        }
        .pickerStyle(.segmented)
        .frame(minHeight: 44)
    }

    private var typeSamples: some View {
        VStack(alignment: .leading, spacing: CipherSpace.s12) {
            sectionTitle("Type")
            Text("Title 30")
                .font(CipherFont.title)
                .foregroundStyle(CipherColor.ink)
            Text("Title 28")
                .font(CipherFont.titleSmall)
                .foregroundStyle(CipherColor.ink)
            Text("Heading")
                .font(CipherFont.h2)
                .foregroundStyle(CipherColor.ink)
            Text("Body copy stays readable when text is larger.")
                .font(CipherFont.body)
                .foregroundStyle(CipherColor.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("Caption")
                .font(CipherFont.caption)
                .foregroundStyle(CipherColor.sub)
        }
    }

    private var iconSamples: some View {
        VStack(alignment: .leading, spacing: CipherSpace.s12) {
            sectionTitle("Icons")
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 72), spacing: CipherSpace.s8)],
                spacing: CipherSpace.s8
            ) {
                ForEach(CipherIcon.allCases) { icon in
                    icon.image
                        .color(CipherColor.ink)
                        .frame(width: 28, height: 28)
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityLabel(icon.accessibilityLabel)
                }
            }
        }
    }

    private var colorSamples: some View {
        VStack(alignment: .leading, spacing: CipherSpace.s12) {
            sectionTitle("Colours")
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 150), spacing: CipherSpace.s12)],
                spacing: CipherSpace.s12
            ) {
                ForEach(CipherColor.catalog) { entry in
                    swatch(entry)
                }
            }
        }
    }

    private var componentSamples: some View {
        VStack(alignment: .leading, spacing: CipherSpace.s16) {
            sectionTitle("Components")
            VStack(alignment: .leading, spacing: CipherSpace.s8) {
                Text("Card")
                    .font(CipherFont.h2)
                    .foregroundStyle(CipherColor.ink)
                Text(model.buttonNote)
                    .font(CipherFont.body)
                    .foregroundStyle(CipherColor.sub)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Chip")
                    .font(CipherFont.caption)
                    .foregroundStyle(CipherColor.tintInk)
                    .padding(.horizontal, CipherSpace.s12)
                    .frame(minHeight: 32)
                    .background(CipherColor.tint, in: Capsule())
            }
            .padding(CipherSpace.s16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CipherColor.card, in: RoundedRectangle(cornerRadius: CipherRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CipherRadius.card, style: .continuous)
                    .stroke(CipherColor.line, lineWidth: 1)
            )

            Button("Primary button") {
                model.buttonNote = "Navy text on gold."
            }
            .buttonStyle(CipherGoldButtonStyle())
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(CipherFont.caption)
            .foregroundStyle(CipherColor.sub)
            .accessibilityAddTraits(.isHeader)
    }

    private func swatch(_ entry: CipherPaletteEntry) -> some View {
        VStack(alignment: .leading, spacing: CipherSpace.s8) {
            RoundedRectangle(cornerRadius: CipherRadius.card, style: .continuous)
                .fill(entry.color)
                .frame(height: 44)
                .overlay(
                    RoundedRectangle(cornerRadius: CipherRadius.card, style: .continuous)
                        .stroke(CipherColor.line, lineWidth: 1)
                )
            Text(entry.name)
                .font(CipherFont.caption)
                .foregroundStyle(CipherColor.ink)
            Text("\(hex(entry.light)) / \(hex(entry.dark))")
                .font(CipherFont.caption)
                .foregroundStyle(CipherColor.sub)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private func hex(_ value: UInt32) -> String {
        String(format: "#%06X", value)
    }
}
