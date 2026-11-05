import SwiftUI

struct OnboardingDemoView: View {
    var onStart: () -> Void
    var onSkip: () -> Void

    var body: some View {
        CipherScreen {
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("Skip", action: onSkip)
                        .font(CipherFont.button)
                        .foregroundStyle(CipherColor.sub)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .padding(.horizontal, CipherSpace.s8)
                DemoIllustration()
                    .padding(.top, CipherSpace.s8)
                Spacer(minLength: CipherSpace.s20)
                VStack(alignment: .leading, spacing: CipherSpace.s12) {
                    Text("Private photos, locked\non this iPhone.")
                        .font(CipherFont.title)
                        .foregroundStyle(CipherColor.ink)
                    Text("Move photos out of your camera roll into a vault only you can open.")
                        .font(CipherFont.body)
                        .foregroundStyle(CipherColor.sub)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, CipherSpace.s24)
                Spacer(minLength: CipherSpace.s16)
                CipherPageDots(count: 6, index: 0)
                    .padding(.bottom, CipherSpace.s16)
                Button("Get started", action: onStart)
                    .buttonStyle(CipherGoldButtonStyle())
                    .padding(.horizontal, CipherSpace.s24)
                    .padding(.bottom, CipherSpace.s16)
            }
        }
    }
}

private struct DemoIllustration: View {
    var body: some View {
        VStack(spacing: CipherSpace.s12) {
            VStack(alignment: .leading, spacing: CipherSpace.s12) {
                Label("Camera roll", systemImage: "photo.on.rectangle")
                    .font(CipherFont.button)
                    .foregroundStyle(CipherColor.ink)
                HStack(spacing: CipherSpace.s8) {
                    tile(colors: [Color(red: 0.29, green: 0.56, blue: 0.72), Color(red: 0.95, green: 0.71, blue: 0.42)])
                    tile(colors: [Color(red: 0.93, green: 0.75, blue: 0.22), Color(red: 0.85, green: 0.62, blue: 0.16)])
                    tile(colors: [Color(red: 0.45, green: 0.62, blue: 0.55), Color(red: 0.20, green: 0.32, blue: 0.38)])
                }
            }
            .padding(CipherSpace.s16)
            .background(CipherColor.card, in: RoundedRectangle(cornerRadius: CipherRadius.card))
            Image(systemName: "arrow.down")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(CipherColor.sub)
                .frame(width: 36, height: 36)
                .background(CipherColor.tint, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: CipherSpace.s12) {
                HStack(spacing: CipherSpace.s12) {
                    CipherIcon.lock.image
                        .foregroundStyle(CipherColor.gold)
                        .frame(width: 36, height: 36)
                        .background(CipherColor.ink.opacity(0.18), in: RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Personal vault")
                            .font(CipherFont.button)
                            .foregroundStyle(.white)
                        Text("Locked. Only you can open it.")
                            .font(CipherFont.caption)
                            .foregroundStyle(Color.white.opacity(0.72))
                    }
                }
                HStack(spacing: CipherSpace.s8) {
                    lockedTile(tint: Color(red: 0.35, green: 0.48, blue: 0.58))
                    lockedTile(tint: Color(red: 0.72, green: 0.58, blue: 0.16))
                    lockedTile(tint: Color(red: 0.28, green: 0.40, blue: 0.36))
                }
            }
            .padding(CipherSpace.s16)
            .background(CipherColor.hero, in: RoundedRectangle(cornerRadius: CipherRadius.card))
        }
        .padding(.horizontal, CipherSpace.s24)
    }

    private func tile(colors: [Color]) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
            .frame(height: 72)
            .accessibilityHidden(true)
    }

    private func lockedTile(tint: Color) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(tint.opacity(0.85))
            .frame(height: 64)
            .overlay {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)
    }
}

struct PrivateQuestionView: View {
    var selected: OnboardingGoal?
    var message: String?
    var onBack: () -> Void
    var onSelect: (OnboardingGoal) -> Void
    var onContinue: () -> Void

    private let columns = [GridItem(.flexible(), spacing: CipherSpace.s12), GridItem(.flexible(), spacing: CipherSpace.s12)]

    var body: some View {
        CipherScreen {
            VStack(alignment: .leading, spacing: CipherSpace.s16) {
                HStack {
                    CipherBackButton(action: onBack)
                    Spacer()
                    Text("Question 1 of 2")
                        .font(CipherFont.caption)
                        .foregroundStyle(CipherColor.sub)
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                Text("What do you want to\nkeep private?")
                    .font(CipherFont.title)
                    .foregroundStyle(CipherColor.ink)
                Text("We will set up your vault around your answer. You can change it later.")
                    .font(CipherFont.body)
                    .foregroundStyle(CipherColor.sub)
                LazyVGrid(columns: columns, spacing: CipherSpace.s12) {
                    ForEach(OnboardingGoal.allCases) { goal in
                        Button {
                            onSelect(goal)
                        } label: {
                            GoalCard(goal: goal, selected: selected == goal)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selected == goal ? .isSelected : [])
                    }
                }
                StatusLine(text: message)
                Spacer(minLength: CipherSpace.s12)
                CipherPageDots(count: 6, index: 1)
                Button("Continue", action: onContinue)
                    .buttonStyle(CipherGoldButtonStyle())
                    .disabled(selected == nil)
                    .opacity(selected == nil ? 0.45 : 1)
            }
            .padding(CipherSpace.s20)
        }
    }
}

private struct GoalCard: View {
    var goal: OnboardingGoal
    var selected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: CipherSpace.s12) {
            GoalArt(goal: goal)
                .frame(height: 72)
            Text(goal.title)
                .font(CipherFont.button)
                .foregroundStyle(CipherColor.ink)
            Text(goal.detail)
                .font(CipherFont.caption)
                .foregroundStyle(CipherColor.sub)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(CipherSpace.s12)
        .frame(maxWidth: .infinity, minHeight: 180, alignment: .topLeading)
        .background(CipherColor.card, in: RoundedRectangle(cornerRadius: CipherRadius.card))
        .overlay {
            RoundedRectangle(cornerRadius: CipherRadius.card)
                .stroke(selected ? CipherColor.ink : CipherColor.line, lineWidth: selected ? 2 : 1)
        }
        .overlay(alignment: .topTrailing) {
            if selected {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(CipherColor.onGold)
                    .frame(width: 22, height: 22)
                    .background(CipherColor.gold, in: Circle())
                    .padding(CipherSpace.s8)
            }
        }
    }
}

private struct GoalArt: View {
    var goal: OnboardingGoal

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12).fill(CipherColor.tint)
            switch goal {
            case .photos:
                HStack(spacing: -8) {
                    RoundedRectangle(cornerRadius: 6).fill(Color(red: 0.35, green: 0.55, blue: 0.62)).frame(width: 36, height: 44)
                    RoundedRectangle(cornerRadius: 6).fill(Color(red: 0.93, green: 0.75, blue: 0.22)).frame(width: 36, height: 44)
                }
            case .documents:
                HStack(spacing: -12) {
                    RoundedRectangle(cornerRadius: 6).fill(CipherColor.card).frame(width: 48, height: 36)
                        .overlay(alignment: .leading) {
                            VStack(alignment: .leading, spacing: 4) {
                                Capsule().fill(CipherColor.line).frame(width: 28, height: 4)
                                Capsule().fill(CipherColor.line).frame(width: 20, height: 4)
                            }
                            .padding(6)
                        }
                    RoundedRectangle(cornerRadius: 6).fill(CipherColor.hero).frame(width: 52, height: 34)
                }
            case .notes:
                RoundedRectangle(cornerRadius: 8).fill(Color(red: 0.96, green: 0.86, blue: 0.55))
                    .frame(width: 78, height: 52)
                    .overlay(alignment: .topLeading) {
                        VStack(alignment: .leading, spacing: 4) {
                            Capsule().fill(CipherColor.amber).frame(width: 36, height: 4)
                            Capsule().fill(CipherColor.amber.opacity(0.7)).frame(width: 24, height: 4)
                        }
                        .padding(8)
                    }
            case .all:
                HStack(spacing: 6) {
                    mini(CipherColor.hero, "photo")
                    mini(CipherColor.gold, "doc.text")
                    mini(CipherColor.tintInk, "key")
                }
            }
        }
    }

    private func mini(_ color: Color, _ symbol: String) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(color.opacity(0.2))
            .frame(width: 28, height: 28)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(color)
            }
    }
}

struct UnlockQuestionView: View {
    var biometryName: String
    var selected: UnlockChoice
    var onBack: () -> Void
    var onSelect: (UnlockChoice) -> Void
    var onContinue: () -> Void

    var body: some View {
        CipherScreen {
            VStack(alignment: .leading, spacing: CipherSpace.s16) {
                HStack {
                    CipherBackButton(action: onBack)
                    Spacer()
                    Text("Question 2 of 2")
                        .font(CipherFont.caption)
                        .foregroundStyle(CipherColor.sub)
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                Text("How do you want to\nunlock?")
                    .font(CipherFont.title)
                    .foregroundStyle(CipherColor.ink)
                Text("Next you will create the lock. Each vault can have its own.")
                    .font(CipherFont.body)
                    .foregroundStyle(CipherColor.sub)
                option(.biometry, biometryName, "Fastest. A PIN or phrase is still your backup.", CipherIcon.face.image)
                option(.secret, "PIN or phrase", "Type a code or your own words.", Image(systemName: "circle.grid.3x3.fill"))
                option(.pattern, "Pattern", "Draw a shape on a grid.", Image(systemName: "circle.grid.3x3"))
                Spacer(minLength: CipherSpace.s12)
                CipherPageDots(count: 6, index: 2)
                Button("Continue", action: onContinue)
                    .buttonStyle(CipherGoldButtonStyle())
            }
            .padding(CipherSpace.s20)
        }
    }

    private func option(_ choice: UnlockChoice, _ title: String, _ detail: String, _ icon: Image) -> some View {
        let selected = selected == choice
        return Button {
            onSelect(choice)
        } label: {
            HStack(spacing: CipherSpace.s12) {
                icon
                    .foregroundStyle(CipherColor.tintInk)
                    .frame(width: 40, height: 40)
                    .background(CipherColor.tint, in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(CipherFont.button).foregroundStyle(CipherColor.ink)
                    Text(detail).font(CipherFont.caption).foregroundStyle(CipherColor.sub).fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Circle()
                    .fill(selected ? CipherColor.ink : Color.clear)
                    .overlay(Circle().stroke(selected ? CipherColor.ink : CipherColor.line, lineWidth: 1.5))
                    .frame(width: 22, height: 22)
            }
            .padding(CipherSpace.s12)
            .background(CipherColor.card, in: RoundedRectangle(cornerRadius: CipherRadius.card))
            .overlay {
                RoundedRectangle(cornerRadius: CipherRadius.card)
                    .stroke(selected ? CipherColor.ink : CipherColor.line, lineWidth: selected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct PhotosPrimerView: View {
    var onBack: () -> Void
    var onContinue: () -> Void
    var onNotNow: () -> Void

    var body: some View {
        CipherScreen {
            VStack(alignment: .leading, spacing: CipherSpace.s16) {
                CipherBackButton(action: onBack)
                CipherIcon.image.image
                    .foregroundStyle(CipherColor.gold)
                    .frame(width: 64, height: 64)
                    .background(CipherColor.hero, in: RoundedRectangle(cornerRadius: 18))
                Text("Choose the photos to\nlock")
                    .font(CipherFont.title)
                    .foregroundStyle(CipherColor.ink)
                Text("iPhone will ask for photo access. You decide what CipherRoll can see.")
                    .font(CipherFont.body)
                    .foregroundStyle(CipherColor.sub)
                VStack(alignment: .leading, spacing: CipherSpace.s12) {
                    bullet("Pick Limited access to share only the photos you choose.")
                    bullet("CipherRoll does not upload your photos.")
                    bullet("You can change access any time in iPhone Settings.")
                }
                .padding(.top, CipherSpace.s8)
                Spacer()
                CipherPageDots(count: 6, index: 3)
                Button("Continue", action: onContinue)
                    .buttonStyle(CipherGoldButtonStyle())
                CipherTextButton(title: "Not now", action: onNotNow)
                    .frame(maxWidth: .infinity)
            }
            .padding(CipherSpace.s20)
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: CipherSpace.s12) {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(CipherColor.tintInk)
                .frame(width: 22, height: 22)
                .background(CipherColor.tint, in: Circle())
            Text(text)
                .font(CipherFont.body)
                .foregroundStyle(CipherColor.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct FaceOfferView: View {
    var biometryName: String
    var backup: String
    var message: String?
    var onTurnOn: () -> Void
    var onNotNow: () -> Void

    var body: some View {
        CipherScreen {
            VStack(spacing: CipherSpace.s16) {
                Spacer(minLength: CipherSpace.s24)
                Text("Step 3 of 3")
                    .font(CipherFont.caption)
                    .foregroundStyle(CipherColor.sub)
                CipherIcon.face.image
                    .foregroundStyle(CipherColor.gold)
                    .frame(width: 84, height: 84)
                    .background(CipherColor.hero, in: RoundedRectangle(cornerRadius: 24))
                Text("Unlock faster\nwith \(biometryName)")
                    .font(CipherFont.title)
                    .foregroundStyle(CipherColor.ink)
                    .multilineTextAlignment(.center)
                Text("Skip typing your \(backup) each time.")
                    .font(CipherFont.body)
                    .foregroundStyle(CipherColor.sub)
                VStack(alignment: .leading, spacing: CipherSpace.s12) {
                    bullet("Your \(backup) always works as a backup.")
                    bullet("\(biometryName) is handled by iOS. CipherRoll never sees your biometric data.")
                    bullet("You can turn it off any time in Settings.")
                }
                .padding(.top, CipherSpace.s8)
                StatusLine(text: message)
                Spacer()
                Button("Turn on \(biometryName)", action: onTurnOn)
                    .buttonStyle(CipherGoldButtonStyle())
                CipherTextButton(title: "Not now", action: onNotNow)
            }
            .padding(CipherSpace.s24)
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: CipherSpace.s12) {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(CipherColor.tintInk)
                .frame(width: 22, height: 22)
                .background(CipherColor.tint, in: Circle())
            Text(text)
                .font(CipherFont.body)
                .foregroundStyle(CipherColor.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
