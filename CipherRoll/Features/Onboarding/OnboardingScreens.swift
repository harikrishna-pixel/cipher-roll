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
                ScrollView(showsIndicators: false) {
                    VStack(spacing: CipherSpace.s16) {
                        DemoIllustration()
                            .padding(.top, CipherSpace.s8)
                        VStack(alignment: .leading, spacing: CipherSpace.s12) {
                            Text("Private photos, locked\non this iPhone.")
                                .font(CipherFont.title)
                                .foregroundStyle(CipherColor.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("Move photos out of your camera roll into a vault only you can open.")
                                .font(CipherFont.body)
                                .foregroundStyle(CipherColor.sub)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, CipherSpace.s24)
                    }
                }
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
    private let openTiles = ["OnboardingMountain", "OnboardingPug", "OnboardingLake"]
    private let lockedTiles = ["OnboardingLockedMountain", "OnboardingLockedPug", "OnboardingLockedLake"]

    var body: some View {
        VStack(spacing: CipherSpace.s12) {
            VStack(alignment: .leading, spacing: CipherSpace.s12) {
                Label("Camera roll", systemImage: "photo.on.rectangle")
                    .font(CipherFont.button)
                    .foregroundStyle(CipherColor.ink)
                HStack(spacing: CipherSpace.s8) {
                    ForEach(openTiles, id: \.self) { name in
                        photoTile(name)
                    }
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
                    ForEach(lockedTiles, id: \.self) { name in
                        lockedTile(name)
                    }
                }
            }
            .padding(CipherSpace.s16)
            .background(CipherColor.hero, in: RoundedRectangle(cornerRadius: CipherRadius.card))
        }
        .padding(.horizontal, CipherSpace.s24)
    }

    private func photoTile(_ name: String) -> some View {
        Image(name)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .accessibilityHidden(true)
    }

    private func lockedTile(_ name: String) -> some View {
        Image(name)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 12))
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
            VStack(alignment: .leading, spacing: CipherSpace.s12) {
                HStack {
                    CipherBackButton(action: onBack)
                    Spacer()
                    Text("Question 1 of 2")
                        .font(CipherFont.caption)
                        .foregroundStyle(CipherColor.sub)
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: CipherSpace.s16) {
                        Text("What do you want to\nkeep private?")
                            .font(CipherFont.title)
                            .foregroundStyle(CipherColor.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("We will set up your vault around your answer. You can change it later.")
                            .font(CipherFont.body)
                            .foregroundStyle(CipherColor.sub)
                            .fixedSize(horizontal: false, vertical: true)
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
                    }
                }
                CipherPageDots(count: 6, index: 1)
                    .padding(.top, CipherSpace.s4)
                Button("Continue", action: onContinue)
                    .buttonStyle(CipherGoldButtonStyle())
                    .disabled(selected == nil)
                    .opacity(selected == nil ? 0.45 : 1)
                    .padding(.bottom, CipherSpace.s4)
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
        .frame(maxWidth: .infinity, minHeight: 156, alignment: .topLeading)
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
                HStack(spacing: -14) {
                    goalThumb("OnboardingMountain", rotation: -8)
                    goalThumb("OnboardingPug", rotation: 4)
                    goalThumb("OnboardingLake", rotation: 10)
                }
                .padding(.horizontal, 8)
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
                        .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                    RoundedRectangle(cornerRadius: 6).fill(CipherColor.hero).frame(width: 52, height: 34)
                        .overlay(alignment: .leading) {
                            Circle().fill(CipherColor.gold.opacity(0.85)).frame(width: 10, height: 10).padding(6)
                        }
                        .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                }
            case .notes:
                RoundedRectangle(cornerRadius: 8).fill(Color(red: 0.96, green: 0.86, blue: 0.55))
                    .frame(width: 78, height: 52)
                    .overlay(alignment: .topLeading) {
                        VStack(alignment: .leading, spacing: 4) {
                            Capsule().fill(CipherColor.amber).frame(width: 36, height: 4)
                            Capsule().fill(CipherColor.amber.opacity(0.7)).frame(width: 24, height: 4)
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.square.fill").font(.system(size: 10))
                                Capsule().fill(CipherColor.amber.opacity(0.55)).frame(width: 20, height: 4)
                            }
                            .foregroundStyle(CipherColor.amber)
                        }
                        .padding(8)
                    }
                    .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
            case .all:
                HStack(spacing: 6) {
                    mini(CipherColor.hero, "photo")
                    mini(CipherColor.gold, "doc.text")
                    mini(CipherColor.tintInk, "key")
                    mini(CipherColor.ink, "lock.fill")
                }
            }
        }
    }

    private func goalThumb(_ name: String, rotation: Double) -> some View {
        Image(name)
            .resizable()
            .scaledToFill()
            .frame(width: 40, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(.white, lineWidth: 2))
            .rotationEffect(.degrees(rotation))
            .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
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
            VStack(alignment: .leading, spacing: CipherSpace.s12) {
                HStack {
                    CipherBackButton(action: onBack)
                    Spacer()
                    Text("Question 2 of 2")
                        .font(CipherFont.caption)
                        .foregroundStyle(CipherColor.sub)
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: CipherSpace.s16) {
                        Text("How do you want to\nunlock?")
                            .font(CipherFont.title)
                            .foregroundStyle(CipherColor.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Next you will create the lock. Each vault can have its own.")
                            .font(CipherFont.body)
                            .foregroundStyle(CipherColor.sub)
                            .fixedSize(horizontal: false, vertical: true)
                        option(.biometry, biometryName, "Fastest. A PIN or phrase is still your backup.", CipherIcon.face.image)
                        option(.secret, "PIN or phrase", "Type a code or your own words.", Image(systemName: "circle.grid.3x3.fill"))
                        option(.pattern, "Pattern", "Draw a shape on a grid.", Image(systemName: "circle.grid.3x3"))
                    }
                }
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

    var body: some View {
        CipherScreen {
            VStack(alignment: .leading, spacing: CipherSpace.s16) {
                CipherBackButton(action: onBack)
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: CipherSpace.s16) {
                        CipherIcon.image.image
                            .foregroundStyle(CipherColor.gold)
                            .frame(width: 64, height: 64)
                            .background(CipherColor.hero, in: RoundedRectangle(cornerRadius: 18))
                        Text("Choose the photos to\nlock")
                            .font(CipherFont.title)
                            .foregroundStyle(CipherColor.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("iPhone will ask for photo access. You decide what CipherRoll can see.")
                            .font(CipherFont.body)
                            .foregroundStyle(CipherColor.sub)
                            .fixedSize(horizontal: false, vertical: true)
                        VStack(alignment: .leading, spacing: CipherSpace.s12) {
                            bullet("Pick Limited access to share only the photos you choose.")
                            bullet("CipherRoll does not upload your photos.")
                            bullet("You can change access any time in iPhone Settings.")
                        }
                        .padding(.top, CipherSpace.s8)
                    }
                }
                CipherPageDots(count: 6, index: 3)
                Button("Continue", action: onContinue)
                    .buttonStyle(CipherGoldButtonStyle())
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

struct FirstLockDoneView: View {
    var onRemoveOriginal: () -> Void
    var onKeepOriginal: () -> Void
    var onGoToVault: () -> Void

    var body: some View {
        CipherScreen {
            VStack(spacing: CipherSpace.s16) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: CipherSpace.s16) {
                        Text("Your first lock")
                            .font(CipherFont.caption)
                            .foregroundStyle(CipherColor.sub)
                            .padding(.top, CipherSpace.s8)
                        Text("Your first photo is locked")
                            .font(CipherFont.title)
                            .foregroundStyle(CipherColor.ink)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        ZStack(alignment: .bottomLeading) {
                            Image("OnboardingFirstLock")
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: 280)
                                .clipShape(RoundedRectangle(cornerRadius: CipherRadius.card))
                            HStack(spacing: 6) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("Locked in Personal")
                                    .font(CipherFont.caption)
                            }
                            .foregroundStyle(CipherColor.ink)
                            .padding(.horizontal, 12)
                            .frame(minHeight: 32)
                            .background(CipherColor.gold.opacity(0.92), in: Capsule())
                            .padding(CipherSpace.s12)
                        }
                        HStack(alignment: .top, spacing: CipherSpace.s12) {
                            Image(systemName: "info.circle.fill")
                                .foregroundStyle(CipherColor.tintInk)
                                .frame(width: 22, height: 22)
                            Text("The original is still in Photos. If you remove it, iOS keeps it in Recently Deleted for about 30 days.")
                                .font(CipherFont.caption)
                                .foregroundStyle(CipherColor.sub)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(CipherSpace.s16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(CipherColor.card, in: RoundedRectangle(cornerRadius: CipherRadius.card))
                        .overlay(RoundedRectangle(cornerRadius: CipherRadius.card).stroke(CipherColor.line, lineWidth: 1))
                        Button("Remove original from Photos", action: onRemoveOriginal)
                            .buttonStyle(CipherOutlineButtonStyle())
                        CipherTextButton(title: "Keep original", action: onKeepOriginal)
                    }
                }
                Button("Go to my vault", action: onGoToVault)
                    .buttonStyle(CipherGoldButtonStyle())
            }
            .padding(CipherSpace.s20)
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
                    .fixedSize(horizontal: false, vertical: true)
                Text("Skip typing your \(backup) each time.")
                    .font(CipherFont.body)
                    .foregroundStyle(CipherColor.sub)
                    .fixedSize(horizontal: false, vertical: true)
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
