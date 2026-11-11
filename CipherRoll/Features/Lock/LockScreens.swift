import SwiftUI

struct CreatePinView: View {
    var title: String
    var detail: String
    var stepLabel: String
    var pin: String
    var message: String?
    var showsOtherOptions: Bool
    var onBack: () -> Void
    var onDigit: (String) -> Void
    var onDelete: () -> Void
    var onContinue: () -> Void
    var onOther: () -> Void

    var body: some View {
        CipherScreen {
            VStack(spacing: CipherSpace.s12) {
                HStack {
                    CipherBackButton(action: onBack)
                    Spacer()
                    Text(stepLabel)
                        .font(CipherFont.caption)
                        .foregroundStyle(CipherColor.sub)
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                ScrollView(showsIndicators: false) {
                    VStack(spacing: CipherSpace.s12) {
                        Text(title)
                            .font(CipherFont.title)
                            .foregroundStyle(CipherColor.ink)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(detail)
                            .font(CipherFont.body)
                            .foregroundStyle(CipherColor.sub)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                        PinDots(count: pin.count)
                            .padding(.top, CipherSpace.s4)
                        if showsOtherOptions {
                            Button("Other options", action: onOther)
                                .font(CipherFont.button)
                                .foregroundStyle(CipherColor.link)
                                .frame(minHeight: 44)
                        }
                        StatusLine(text: message)
                    }
                    .frame(maxWidth: .infinity)
                }
                Spacer(minLength: CipherSpace.s8)
                if PinDraft.canContinue(pin) {
                    Button("Continue", action: onContinue)
                        .buttonStyle(CipherGoldButtonStyle())
                }
                PinPad(showsBiometry: false, onDigit: onDigit, onDelete: onDelete, onBiometry: {})
            }
            .padding(CipherSpace.s20)
            .onChange(of: pin) { value in
                // Six dots are shown. Once they are filled, continue so the pad does not keep growing.
                // Skip empty resets (clearEntry) so confirm→create does not re-fire.
                guard value.count == PinDraft.minimumDigits else { return }
                onContinue()
            }
        }
    }
}

struct ChooseLockView: View {
    var biometryName: String
    var kind: LockKind
    var phrase: String
    var password: String
    var visible: Bool
    var biometryOn: Bool
    var message: String?
    var onBack: () -> Void
    var onSelect: (LockKind) -> Void
    var onPhrase: (String) -> Void
    var onPassword: (String) -> Void
    var onToggleVisible: () -> Void
    var onBiometry: (Bool) -> Void
    var onContinue: () -> Void

    var body: some View {
        CipherScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: CipherSpace.s12) {
                    HStack {
                        CipherBackButton(action: onBack)
                        Spacer()
                        Text("Personal vault")
                            .font(CipherFont.caption)
                            .foregroundStyle(CipherColor.sub)
                        Spacer()
                        Color.clear.frame(width: 44, height: 44)
                    }
                    Text("Choose how to unlock")
                        .font(CipherFont.title)
                        .foregroundStyle(CipherColor.ink)
                    Text("Each vault has its own lock. You can change it later in Settings.")
                        .font(CipherFont.body)
                        .foregroundStyle(CipherColor.sub)
                    row(.pin, "PIN", LockCopy.pinDetail, "circle.grid.3x3.fill")
                    row(.pattern, "Pattern", LockCopy.patternDetail, "circle.grid.3x3")
                    row(.phrase, "Custom phrase", LockCopy.phraseDetail, "key")
                    row(.calculator, "Calculator-style PIN", LockCopy.calculatorDetail, "plus.forwardslash.minus")
                    row(.password, "Password", LockCopy.passwordDetail, "textformat")
                    if kind == .phrase || kind == .password {
                        secretField
                    }
                    Toggle(isOn: Binding(get: { biometryOn }, set: onBiometry)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(biometryName) as a shortcut")
                                .font(CipherFont.body)
                                .foregroundStyle(CipherColor.ink)
                            Text(biometryOn
                                 ? "Next you will turn on \(biometryName) after your lock is created."
                                 : "Optional. You can turn this on after you create your lock.")
                                .font(CipherFont.caption)
                                .foregroundStyle(CipherColor.sub)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .tint(CipherColor.gold)
                    .padding(.horizontal, CipherSpace.s16)
                    .padding(.vertical, CipherSpace.s8)
                    .frame(minHeight: 56)
                    .background(CipherColor.card, in: RoundedRectangle(cornerRadius: CipherRadius.card))
                    StatusLine(text: message)
                }
                .padding(CipherSpace.s20)
            }
            .safeAreaInset(edge: .bottom) {
                Button("Continue", action: onContinue)
                    .buttonStyle(CipherGoldButtonStyle())
                    .padding(.horizontal, CipherSpace.s20)
                    .padding(.vertical, CipherSpace.s12)
                    .background(CipherColor.bg)
            }
        }
    }

    private var secretField: some View {
        let text = kind == .password ? password : phrase
        let strength = PhraseDraft.strength(of: text)
        return VStack(alignment: .leading, spacing: CipherSpace.s8) {
            Text(kind == .password ? "YOUR PASSWORD" : "YOUR CUSTOM PHRASE")
                .font(CipherFont.caption)
                .foregroundStyle(CipherColor.sub)
            HStack {
                Group {
                    if visible {
                        TextField(kind == .password ? "At least 8 characters" : "blue-kite-river-42", text: Binding(
                            get: { text },
                            set: { kind == .password ? onPassword($0) : onPhrase($0) }
                        ))
                    } else {
                        SecureField(kind == .password ? "At least 8 characters" : "Your words", text: Binding(
                            get: { text },
                            set: { kind == .password ? onPassword($0) : onPhrase($0) }
                        ))
                    }
                }
                .font(CipherFont.body)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .id(visible) // Rebuild so hide mode never keeps plaintext on screen.
                Button(action: onToggleVisible) {
                    Image(systemName: visible ? "eye.slash" : "eye")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(visible ? "Hide" : "Show")
            }
            .padding(.leading, CipherSpace.s16)
            .background(CipherColor.card, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(CipherColor.line, lineWidth: 1))
            strengthBar(strength)
            Text(kind == .password
                 ? "At least 8 characters."
                 : "8 or more characters. Use words you remember, not your name or birthday.")
                .font(CipherFont.caption)
                .foregroundStyle(CipherColor.sub)
        }
    }

    private func strengthBar(_ strength: (label: String, fraction: CGFloat)) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(CipherColor.line)
                    Capsule().fill(CipherColor.gold).frame(width: proxy.size.width * max(0, strength.fraction))
                }
            }
            .frame(height: 6)
            if !strength.label.isEmpty {
                Text(strength.label)
                    .font(CipherFont.caption)
                    .foregroundStyle(CipherColor.sub)
            }
        }
    }

    private func row(_ kind: LockKind, _ title: String, _ detail: String, _ symbol: String) -> some View {
        let selected = self.kind == kind
        return Button {
            onSelect(kind)
        } label: {
            HStack(spacing: CipherSpace.s12) {
                Image(systemName: symbol)
                    .foregroundStyle(CipherColor.tintInk)
                    .frame(width: 40, height: 40)
                    .background(CipherColor.tint, in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(CipherFont.button).foregroundStyle(CipherColor.ink)
                    Text(detail).font(CipherFont.caption).foregroundStyle(CipherColor.sub)
                }
                Spacer()
                Circle()
                    .fill(selected ? CipherColor.ink : Color.clear)
                    .overlay(Circle().stroke(selected ? CipherColor.ink : CipherColor.line, lineWidth: 1.5))
                    .frame(width: 22, height: 22)
            }
            .padding(CipherSpace.s12)
            .background(CipherColor.card, in: RoundedRectangle(cornerRadius: CipherRadius.card))
            .overlay(RoundedRectangle(cornerRadius: CipherRadius.card).stroke(selected ? CipherColor.ink : CipherColor.line, lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct PhraseEntryView: View {
    var title: String
    var text: String
    var visible: Bool
    var message: String?
    var onBack: () -> Void
    var onText: (String) -> Void
    var onToggleVisible: () -> Void
    var onContinue: () -> Void

    var body: some View {
        CipherScreen {
            VStack(alignment: .leading, spacing: CipherSpace.s16) {
                CipherBackButton(action: onBack)
                Text(title)
                    .font(CipherFont.title)
                    .foregroundStyle(CipherColor.ink)
                HStack {
                    Group {
                        if visible {
                            TextField("Type it again", text: Binding(get: { text }, set: onText))
                        } else {
                            SecureField("Type it again", text: Binding(get: { text }, set: onText))
                        }
                    }
                    .font(CipherFont.body)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .id(visible)
                    Button(action: onToggleVisible) {
                        Image(systemName: visible ? "eye.slash" : "eye")
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(visible ? "Hide" : "Show")
                }
                .padding(.leading, CipherSpace.s16)
                .background(CipherColor.card, in: RoundedRectangle(cornerRadius: 16))
                StatusLine(text: message)
                Button("Continue", action: onContinue)
                    .buttonStyle(CipherGoldButtonStyle())
                    .disabled(!PhraseDraft.canContinue(text))
                    .opacity(PhraseDraft.canContinue(text) ? 1 : 0.45)
                Spacer()
            }
            .padding(CipherSpace.s20)
        }
    }
}

struct RecoverySetupView: View {
    var words: [String]
    var tested: Bool
    var message: String?
    var onCopy: () -> Void
    var onFiles: () -> Void
    var onPrint: () -> Void
    var onTest: () -> Void
    var onSaved: () -> Void

    var body: some View {
        CipherScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: CipherSpace.s16) {
                    Text("Step 3 of 4")
                        .font(CipherFont.caption)
                        .foregroundStyle(CipherColor.sub)
                        .frame(maxWidth: .infinity)
                    Text("Save your recovery key")
                        .font(CipherFont.title)
                        .foregroundStyle(CipherColor.ink)
                    Text("If you forget your PIN, this key unlocks the vaults on this iPhone. We can't reset your PIN for you.")
                        .font(CipherFont.body)
                        .foregroundStyle(CipherColor.sub)
                    Text("24 words, in order.")
                        .font(CipherFont.caption)
                        .foregroundStyle(CipherColor.sub)
                    wordCard
                    HStack(spacing: CipherSpace.s8) {
                        action("Copy", "doc.on.doc", onCopy)
                        action("Files", "folder", onFiles)
                        action("Print", "printer", onPrint)
                    }
                    HStack(alignment: .top, spacing: CipherSpace.s12) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(CipherColor.tintInk)
                            .frame(width: 28, height: 28)
                            .background(CipherColor.tint, in: Circle())
                        Text(LockCopy.recoveryWarning)
                            .font(CipherFont.caption)
                            .foregroundStyle(CipherColor.ink)
                    }
                    .padding(CipherSpace.s12)
                    .background(CipherColor.card, in: RoundedRectangle(cornerRadius: CipherRadius.card))
                    StatusLine(text: message)
                }
                .padding(CipherSpace.s20)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: CipherSpace.s8) {
                    Button("Test my key", action: onTest)
                        .buttonStyle(CipherGoldButtonStyle())
                    Button("I saved my key", action: onSaved)
                        .buttonStyle(CipherOutlineButtonStyle())
                        .disabled(!RecoveryConfirmation.allowsSave(tested: tested))
                        .opacity(tested ? 1 : 0.4)
                        .accessibilityHint(tested ? "Continues" : LockCopy.savedKeyHint)
                    if !tested {
                        Text(LockCopy.savedKeyHint)
                            .font(CipherFont.caption)
                            .foregroundStyle(CipherColor.sub)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, CipherSpace.s20)
                .padding(.vertical, CipherSpace.s12)
                .background(CipherColor.bg)
            }
        }
    }

    private var wordCard: some View {
        VStack(alignment: .leading, spacing: CipherSpace.s12) {
            Label("Recovery key · created on this iPhone", systemImage: "arrow.triangle.2.circlepath")
                .font(CipherFont.caption)
                .foregroundStyle(Color.white.opacity(0.75))
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: CipherSpace.s4) {
                ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                    Text("\(index + 1). \(word)")
                        .font(CipherFont.caption)
                        .foregroundStyle(CipherColor.gold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(CipherSpace.s16)
        .background(CipherColor.hero, in: RoundedRectangle(cornerRadius: CipherRadius.card))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Recovery key, \(words.count) words")
    }

    private func action(_ title: String, _ symbol: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(CipherFont.button)
                .foregroundStyle(CipherColor.ink)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(CipherColor.card, in: Capsule())
                .overlay(Capsule().stroke(CipherColor.line, lineWidth: 1))
        }
    }
}

struct RecoveryTestView: View {
    var draft: String
    var replacementPin: String
    var needsNewPin: Bool
    var message: String?
    var onBack: () -> Void
    var onDraft: (String) -> Void
    var onPin: (String) -> Void
    var onSubmit: () -> Void

    var body: some View {
        CipherScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: CipherSpace.s16) {
                    CipherBackButton(action: onBack)
                    Text("Test your recovery key")
                        .font(CipherFont.title)
                        .foregroundStyle(CipherColor.ink)
                    Text(needsNewPin
                         ? "Type the 24 words in order. Then choose a new PIN of at least 6 digits."
                         : "Type the 24 words in order, separated by spaces.")
                        .font(CipherFont.body)
                        .foregroundStyle(CipherColor.sub)
                    TextEditor(text: Binding(get: { draft }, set: onDraft))
                        .font(CipherFont.body)
                        .frame(minHeight: 140)
                        .padding(CipherSpace.s8)
                        .scrollContentBackground(.hidden)
                        .background(CipherColor.card, in: RoundedRectangle(cornerRadius: 16))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .accessibilityLabel("Recovery words")
                    if needsNewPin {
                        SecureField("New PIN", text: Binding(get: { replacementPin }, set: onPin))
                            .keyboardType(.numberPad)
                            .font(CipherFont.body)
                            .padding(CipherSpace.s16)
                            .background(CipherColor.card, in: RoundedRectangle(cornerRadius: 16))
                            .accessibilityLabel("New PIN")
                    }
                    StatusLine(text: message)
                    Button(needsNewPin ? "Unlock" : "Check key", action: onSubmit)
                        .buttonStyle(CipherGoldButtonStyle())
                }
                .padding(CipherSpace.s20)
            }
        }
    }
}

struct PinLockView: View {
    var prompt: String
    var pin: String
    var message: String?
    var showsBiometry: Bool
    var onDigit: (String) -> Void
    var onDelete: () -> Void
    var onBiometry: () -> Void
    var onRecovery: () -> Void
    var onUnlock: () -> Void = {}
    var onTestingSkip: (() -> Void)? = nil

    var body: some View {
        CipherScreen {
            VStack(spacing: CipherSpace.s12) {
                Spacer(minLength: CipherSpace.s24)
                Group {
                    if let onTestingSkip {
                        Button(action: onTestingSkip) {
                            lockMark
                        }
                        .accessibilityLabel("Skip soft lock")
                    } else {
                        lockMark
                    }
                }
                Text("Personal")
                    .font(CipherFont.titleSmall)
                    .foregroundStyle(CipherColor.ink)
                Text(prompt)
                    .font(CipherFont.body)
                    .foregroundStyle(CipherColor.sub)
                PinDots(count: pin.count)
                StatusLine(text: message)
                if PinDraft.canContinue(pin) {
                    Button("Unlock", action: onUnlock)
                        .buttonStyle(CipherGoldButtonStyle())
                }
                Spacer(minLength: CipherSpace.s8)
                PinPad(showsBiometry: showsBiometry, onDigit: onDigit, onDelete: onDelete, onBiometry: onBiometry)
                Button("Use recovery key", action: onRecovery)
                    .font(CipherFont.button)
                    .foregroundStyle(CipherColor.link)
                    .frame(minHeight: 44)
            }
            .padding(CipherSpace.s20)
        }
    }

    private var lockMark: some View {
        CipherIcon.lock.image
            .foregroundStyle(CipherColor.gold)
            .frame(width: 64, height: 64)
            .background(CipherColor.hero, in: RoundedRectangle(cornerRadius: 18))
    }
}

struct PhraseLockView: View {
    var prompt: String
    var text: String
    var visible: Bool
    var message: String?
    var showsBiometry: Bool
    var onText: (String) -> Void
    var onToggleVisible: () -> Void
    var onUnlock: () -> Void
    var onBiometry: () -> Void
    var onRecovery: () -> Void

    var body: some View {
        CipherScreen {
            VStack(spacing: CipherSpace.s16) {
                Spacer(minLength: CipherSpace.s20)
                CipherIcon.lock.image
                    .foregroundStyle(CipherColor.gold)
                    .frame(width: 64, height: 64)
                    .background(CipherColor.hero, in: RoundedRectangle(cornerRadius: 18))
                Text("Personal")
                    .font(CipherFont.titleSmall)
                    .foregroundStyle(CipherColor.ink)
                Text(prompt)
                    .font(CipherFont.body)
                    .foregroundStyle(CipherColor.sub)
                HStack {
                    Group {
                        if visible {
                            TextField(prompt, text: Binding(get: { text }, set: onText))
                        } else {
                            SecureField(prompt, text: Binding(get: { text }, set: onText))
                        }
                    }
                    .font(CipherFont.body)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.go)
                    .onSubmit(onUnlock)
                    Button(action: onToggleVisible) {
                        Image(systemName: visible ? "eye.slash" : "eye")
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(visible ? "Hide" : "Show")
                }
                .padding(.leading, CipherSpace.s16)
                .background(CipherColor.card, in: Capsule())
                .overlay(Capsule().stroke(CipherColor.line, lineWidth: 1))
                HStack(spacing: CipherSpace.s12) {
                    Button("Unlock", action: onUnlock)
                        .buttonStyle(CipherGoldButtonStyle())
                    if showsBiometry {
                        Button(action: onBiometry) {
                            CipherIcon.face.image
                                .foregroundStyle(CipherColor.ink)
                                .frame(width: 52, height: 52)
                                .background(CipherColor.card, in: Circle())
                                .overlay(Circle().stroke(CipherColor.line, lineWidth: 1))
                        }
                        .accessibilityLabel(BiometryLabel.current())
                    }
                }
                Button("Use recovery key", action: onRecovery)
                    .font(CipherFont.button)
                    .foregroundStyle(CipherColor.link)
                    .frame(minHeight: 44)
                StatusLine(text: message)
                Spacer()
            }
            .padding(CipherSpace.s24)
        }
    }
}

struct FaceLockView: View {
    var biometryName: String
    var backup: String
    var onSecret: () -> Void
    var onSwitch: () -> Void

    var body: some View {
        CipherScreen {
            VStack(spacing: CipherSpace.s16) {
                Capsule()
                    .fill(CipherColor.card)
                    .frame(width: 140, height: 36)
                    .overlay {
                        HStack(spacing: 6) {
                            CipherIcon.lock.image
                                .foregroundStyle(CipherColor.gold)
                            Text("Personal")
                                .font(CipherFont.button)
                                .foregroundStyle(CipherColor.ink)
                        }
                    }
                    .padding(.top, CipherSpace.s24)
                Spacer()
                CipherIcon.face.image
                    .foregroundStyle(CipherColor.gold)
                    .frame(width: 88, height: 88)
                    .background(CipherColor.hero, in: RoundedRectangle(cornerRadius: 24))
                    .padding(28)
                    .background(CipherColor.gold.opacity(0.18), in: Circle())
                Text("Welcome back")
                    .font(CipherFont.title)
                    .foregroundStyle(CipherColor.ink)
                Text("Look at your iPhone to unlock Personal.")
                    .font(CipherFont.body)
                    .foregroundStyle(CipherColor.sub)
                    .multilineTextAlignment(.center)
                Spacer()
                HStack(alignment: .top, spacing: CipherSpace.s12) {
                    CipherIcon.key.image
                        .frame(width: 22, height: 22)
                        .foregroundStyle(CipherColor.ink)
                    Text("Your lock for Personal: \(biometryName), with your \(backup) as backup.")
                        .font(CipherFont.caption)
                        .foregroundStyle(CipherColor.ink)
                }
                .padding(CipherSpace.s16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(CipherColor.card, in: RoundedRectangle(cornerRadius: CipherRadius.card))
                Button(action: onSecret) {
                    Text("Use \(backup) instead")
                        .font(CipherFont.button)
                        .foregroundStyle(CipherColor.ink)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(CipherColor.card, in: Capsule())
                        .overlay(Capsule().stroke(CipherColor.line, lineWidth: 1.5))
                }
                Button("Switch vault", action: onSwitch)
                    .font(CipherFont.button)
                    .foregroundStyle(CipherColor.link)
                    .frame(minHeight: 44)
            }
            .padding(CipherSpace.s24)
        }
    }
}

struct PatternLockView: View {
    var title: String
    var subtitle: String
    var dots: [Int]
    var message: String?
    var showsBiometry: Bool
    var biometryName: String
    var showsRecovery: Bool = true
    var onBack: (() -> Void)? = nil
    var onClear: (() -> Void)? = nil
    var onChange: ([Int]) -> Void
    var onFinish: ([Int]) -> Void
    var onBiometry: () -> Void
    var onRecovery: () -> Void

    var body: some View {
        CipherScreen {
            VStack(spacing: CipherSpace.s16) {
                HStack {
                    if let onBack {
                        CipherBackButton(action: onBack)
                    } else {
                        Color.clear.frame(width: 44, height: 44)
                    }
                    Spacer()
                    if let onClear, !dots.isEmpty {
                        Button("Clear", action: onClear)
                            .font(CipherFont.button)
                            .foregroundStyle(CipherColor.link)
                            .frame(minHeight: 44)
                    }
                }
                CipherIcon.lock.image
                    .foregroundStyle(CipherColor.tintInk)
                    .frame(width: 56, height: 56)
                    .background(CipherColor.tint, in: RoundedRectangle(cornerRadius: 16))
                Text(title)
                    .font(CipherFont.titleSmall)
                    .foregroundStyle(CipherColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(CipherFont.body)
                    .foregroundStyle(CipherColor.sub)
                PatternGrid(dots: dots, onComplete: { drawn in
                    onChange(drawn)
                    onFinish(drawn)
                })
                    .frame(width: 260, height: 260)
                    .accessibilityLabel("Pattern grid")
                Text(message ?? LockCopy.patternHint)
                    .font(CipherFont.caption)
                    .foregroundStyle(message == nil ? CipherColor.sub : CipherColor.danger)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                HStack(spacing: CipherSpace.s24) {
                    if showsBiometry {
                        Button(action: onBiometry) {
                            Label("Use \(biometryName)", systemImage: BiometryLabel.symbol(named: biometryName))
                                .font(CipherFont.button)
                                .foregroundStyle(CipherColor.link)
                                .frame(minHeight: 44)
                        }
                    }
                    if showsRecovery {
                        Button("Use recovery key", action: onRecovery)
                            .font(CipherFont.button)
                            .foregroundStyle(CipherColor.link)
                            .frame(minHeight: 44)
                    }
                }
            }
            .padding(CipherSpace.s20)
        }
    }
}

struct PatternGrid: View {
    var dots: [Int]
    var onComplete: ([Int]) -> Void
    @State private var dragging = false
    @State private var live: [Int] = []
    @Environment(\.colorScheme) private var scheme

    private var shown: [Int] { dragging ? live : dots }

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let points = positions(in: size)
            ZStack {
                Path { path in
                    guard let first = shown.first else { return }
                    path.move(to: points[first])
                    for index in shown.dropFirst() {
                        path.addLine(to: points[index])
                    }
                }
                .stroke(CipherColor.gold, style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                ForEach(0..<PatternDraft.dotCount, id: \.self) { index in
                    let selected = shown.contains(index)
                    Circle()
                        .fill(selected ? CipherColor.gold : CipherColor.line)
                        .frame(width: 18, height: 18)
                        .overlay {
                            Circle()
                                .stroke(CipherColor.gold.opacity(selected ? 0.35 : 0), lineWidth: 10)
                        }
                        .position(points[index])
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !dragging {
                            dragging = true
                            live = dots
                        }
                        guard let nearest = nearestDot(to: value.location, points: points) else { return }
                        if !live.contains(nearest) {
                            live.append(nearest)
                        }
                    }
                    .onEnded { _ in
                        let finished = live
                        dragging = false
                        live = []
                        // Pass the drawn dots directly so confirm/create never reads a stale empty pattern.
                        onComplete(finished)
                    }
            )
            .animation(nil, value: shown)
        }
    }

    private func positions(in size: CGFloat) -> [CGPoint] {
        let gap = size / 3
        return (0..<9).map { index in
            let column = CGFloat(index % 3)
            let row = CGFloat(index / 3)
            return CGPoint(x: gap * (column + 0.5), y: gap * (row + 0.5))
        }
    }

    private func nearestDot(to point: CGPoint, points: [CGPoint]) -> Int? {
        let hit = points.enumerated().min { left, right in
            distance(left.element, point) < distance(right.element, point)
        }
        guard let hit, distance(hit.element, point) < 36 else { return nil }
        return hit.offset
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }
}

struct CalculatorLockView: View {
    var caption: String?
    var message: String?
    var onBack: (() -> Void)? = nil
    var onEquals: (String) -> Void

    @State private var state = CalculatorEntry.State()

    var body: some View {
        CipherScreen {
            VStack(spacing: CipherSpace.s16) {
                if let onBack {
                    HStack {
                        CipherBackButton(action: onBack)
                        Spacer()
                    }
                }
                Spacer(minLength: CipherSpace.s12)
                if let caption {
                    Text(caption)
                        .font(CipherFont.caption)
                        .foregroundStyle(CipherColor.sub)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(state.display)
                    .font(CipherFont.title)
                    .foregroundStyle(CipherColor.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .accessibilityLabel("Display \(state.display)")
                if let message {
                    Text(message)
                        .font(CipherFont.caption)
                        .foregroundStyle(CipherColor.danger)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                VStack(spacing: CipherSpace.s12) {
                    HStack(spacing: CipherSpace.s12) {
                        function("C")
                        function("±")
                        function("%")
                        operation("÷")
                    }
                    HStack(spacing: CipherSpace.s12) {
                        number("7"); number("8"); number("9"); operation("×")
                    }
                    HStack(spacing: CipherSpace.s12) {
                        number("4"); number("5"); number("6"); operation("−")
                    }
                    HStack(spacing: CipherSpace.s12) {
                        number("1"); number("2"); number("3"); operation("+")
                    }
                    HStack(spacing: CipherSpace.s12) {
                        number("0", wide: true)
                        number(".")
                        operation("=")
                    }
                }
            }
            .padding(CipherSpace.s20)
        }
    }

    private func number(_ title: String, wide: Bool = false) -> some View {
        Button {
            press(title)
        } label: {
            Text(title)
                .font(CipherFont.titleSmall)
                .foregroundStyle(CipherColor.ink)
                .frame(maxWidth: .infinity, minHeight: 64)
                .background(CipherColor.card, in: Capsule())
        }
        .frame(maxWidth: wide ? .infinity : nil)
        .accessibilityLabel(calculatorName(title))
    }

    private func function(_ title: String) -> some View {
        Button {
            press(title)
        } label: {
            Text(title)
                .font(CipherFont.h2)
                .foregroundStyle(CipherColor.ink)
                .frame(maxWidth: .infinity, minHeight: 64)
                .background(CipherColor.line, in: Circle())
        }
        .accessibilityLabel(calculatorName(title))
    }

    private func operation(_ title: String) -> some View {
        Button {
            press(title)
        } label: {
            Text(title)
                .font(CipherFont.h2)
                .foregroundStyle(CipherColor.onGold)
                .frame(maxWidth: .infinity, minHeight: 64)
                .background(CipherColor.gold, in: Circle())
        }
        .accessibilityLabel(calculatorName(title))
    }

    private func calculatorName(_ title: String) -> String {
        switch title {
        case "C": "Clear"
        case "±": "Plus or minus"
        case "%": "Percent"
        case "÷": "Divide"
        case "×": "Multiply"
        case "−": "Minus"
        case "+": "Plus"
        case "=": "Equals"
        case ".": "Decimal"
        default: title
        }
    }

    private func press(_ key: String) {
        if let pin = CalculatorEntry.tap(key, state: &state) {
            onEquals(pin)
            state = CalculatorEntry.State()
        }
    }
}

struct UnlockedPlaceholderView: View {
    var onLock: () -> Void

    var body: some View {
        CipherScreen {
            VStack(spacing: CipherSpace.s16) {
                Spacer()
                CipherIcon.lock.image
                    .foregroundStyle(CipherColor.gold)
                    .frame(width: 64, height: 64)
                    .background(CipherColor.hero, in: RoundedRectangle(cornerRadius: 18))
                Text("Personal")
                    .font(CipherFont.title)
                    .foregroundStyle(CipherColor.ink)
                Text(LockCopy.vaultReadyLine)
                    .font(CipherFont.body)
                    .foregroundStyle(CipherColor.sub)
                    .multilineTextAlignment(.center)
                Spacer()
                Button("Lock", action: onLock)
                    .buttonStyle(CipherGoldButtonStyle())
            }
            .padding(CipherSpace.s24)
        }
    }
}
