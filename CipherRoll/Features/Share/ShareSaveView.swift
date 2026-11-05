import SwiftUI

/// Share sheet used by the extension and by screenshots. It never offers to delete the original.
struct ShareSaveView: View {
    var unlockedWith: String
    var count: Int
    var kind: ItemKind
    var vaultTitle: String
    var previews: [Color]
    var saved: Bool
    var limitMessage: String?
    var onCancel: () -> Void
    var onSave: () -> Void
    var onOpen: () -> Void
    var onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: CipherSpace.s16) {
            Capsule().fill(CipherColor.line).frame(width: 36, height: 5).frame(maxWidth: .infinity)
            if saved {
                savedBody
            } else {
                readyBody
            }
        }
        .padding(CipherSpace.s20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .background(Color.black.opacity(0.25).ignoresSafeArea())
    }

    private var readyBody: some View {
        VStack(alignment: .leading, spacing: CipherSpace.s16) {
            HStack {
                Image(systemName: "lock.fill")
                    .foregroundStyle(CipherColor.gold)
                    .frame(width: 44, height: 44)
                    .background(CipherColor.hero, in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Save to CipherRoll").font(CipherFont.button).foregroundStyle(CipherColor.ink)
                    Text(unlockedWith).font(CipherFont.caption).foregroundStyle(CipherColor.sub)
                }
                Spacer()
                Button("Cancel", action: onCancel)
                    .font(CipherFont.button)
                    .foregroundStyle(CipherColor.link)
                    .frame(minHeight: 44)
            }
            HStack(spacing: CipherSpace.s8) {
                ForEach(Array(previews.enumerated()), id: \.offset) { _, color in
                    RoundedRectangle(cornerRadius: 10).fill(color).frame(width: 54, height: 54)
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading) {
                    Text("\(count) \(ShareRules.noun(count, kind))").font(CipherFont.button).foregroundStyle(CipherColor.ink)
                    Text("selected to save").font(CipherFont.caption).foregroundStyle(CipherColor.sub)
                }
                .accessibilityElement(children: .combine)
            }
            HStack {
                Image(systemName: "lock").foregroundStyle(CipherColor.ink)
                VStack(alignment: .leading) {
                    Text("Save to").font(CipherFont.caption).foregroundStyle(CipherColor.sub)
                    Text(vaultTitle).font(CipherFont.button).foregroundStyle(CipherColor.ink)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(CipherColor.sub)
            }
            .padding(CipherSpace.s12)
            .background(CipherColor.card, in: RoundedRectangle(cornerRadius: CipherRadius.card))
            .overlay(RoundedRectangle(cornerRadius: CipherRadius.card).stroke(CipherColor.line, lineWidth: 1))
            Text(ShareRules.originalStays).font(CipherFont.caption).foregroundStyle(CipherColor.sub)
            if let limitMessage {
                Text(limitMessage).font(CipherFont.caption).foregroundStyle(CipherColor.ink)
            }
            Button(ShareRules.saveButton(count: count), action: onSave)
                .buttonStyle(CipherGoldButtonStyle())
                .disabled(limitMessage != nil || count == 0)
        }
        .padding(CipherSpace.s16)
        .background(CipherColor.bg, in: RoundedRectangle(cornerRadius: 28))
    }

    private var savedBody: some View {
        VStack(spacing: CipherSpace.s16) {
            Image(systemName: "checkmark")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(CipherColor.gold)
                .frame(width: 64, height: 64)
                .background(CipherColor.hero, in: RoundedRectangle(cornerRadius: 16))
                .accessibilityHidden(true)
            Text(ShareRules.savedTitle(vault: vaultTitle))
                .font(CipherFont.titleSmall)
                .foregroundStyle(CipherColor.ink)
            Text(ShareRules.savedDetail(count: count, kind: kind))
                .font(CipherFont.body)
                .foregroundStyle(CipherColor.sub)
                .multilineTextAlignment(.center)
            HStack(spacing: CipherSpace.s8) {
                ForEach(Array(previews.enumerated()), id: \.offset) { _, color in
                    RoundedRectangle(cornerRadius: 10).fill(color).frame(width: 54, height: 54)
                }
            }
            Button("Open CipherRoll", action: onOpen).buttonStyle(CipherGoldButtonStyle())
            Button("Done", action: onDone)
                .font(CipherFont.button)
                .foregroundStyle(CipherColor.link)
                .frame(minHeight: 44)
        }
        .frame(maxWidth: .infinity)
        .padding(CipherSpace.s16)
        .background(CipherColor.bg, in: RoundedRectangle(cornerRadius: 28))
    }
}
