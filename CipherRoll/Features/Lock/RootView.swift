import SwiftUI

struct RootView: View {
    @ObservedObject var model: AppLockModel
    @ObservedObject var settings: SettingsModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.analyticsClient) private var analytics
    @StateObject private var library = LibraryModel()
    @StateObject private var plan = PlanModel()
    @State private var showPrivacyFacts = false

    var body: some View {
        if settings.consent == nil {
            ConsentScreen(
                onAllow: settings.allowStats,
                onNotNow: settings.declineStats,
                onPrivacy: { showPrivacyFacts = true }
            )
            .alert("Privacy", isPresented: $showPrivacyFacts) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("\(SettingsCopy.consentBody)\n\n\(SettingsCopy.vaultStays)")
            }
        } else {
            unlockedShell
        }
    }

    private var unlockedShell: some View {
        ZStack {
            Group {
                switch model.route {
                case .onboarding:
                    onboarding
                case .locked:
                    locked
                case .unlocked:
                    LibraryRoot(
                        library: library,
                        plan: plan,
                        settings: settings,
                        lock: model,
                        shortcut: model.biometryOn ? model.biometryName : "your \(model.lockKind.backupTitle)",
                        onLock: {
                            #if DEBUG
                            model.softLockForTesting()
                            #else
                            model.lockFromInside()
                            #endif
                        }
                    )
                    .onAppear {
                        library.attach(model.session, analytics: analytics)
                        plan.attach(analytics)
                    }
                }
            }
            .opacity(model.coverVisible ? 0 : 1)
            if model.coverVisible {
                PrivacyCover()
            }
            if model.busy {
                ZStack {
                    Color.black.opacity(0.15).ignoresSafeArea()
                    ProgressView("Setting up your vault")
                        .font(CipherFont.caption)
                        .padding(CipherSpace.s20)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
                .accessibilityLabel("Setting up your vault")
            }
        }
        .onChange(of: scenePhase, perform: { phase in
            model.sceneChanged(to: phase)
        })
        .sheet(isPresented: Binding(
            get: { model.shareURL != nil },
            set: { if !$0 { model.finishedSharing() } }
        )) {
            if let url = model.shareURL {
                ActivitySheet(url: url, onDone: model.finishedSharing)
            }
        }
    }

    @ViewBuilder
    private var onboarding: some View {
        switch model.step {
        case .demo:
            OnboardingDemoView(onStart: model.continueFromDemo, onSkip: model.skipDemo)
        case .privateQuestion:
            PrivateQuestionView(
                selected: model.goal,
                message: model.message,
                onBack: model.back,
                onSelect: model.selectGoal,
                onContinue: model.continueFromPrivateQuestion
            )
        case .unlockQuestion:
            UnlockQuestionView(
                biometryName: model.biometryName,
                selected: model.unlockChoice,
                onBack: model.back,
                onSelect: model.selectUnlock,
                onContinue: model.continueFromUnlockQuestion
            )
        case .photos:
            PhotosPrimerView(
                onBack: model.back,
                onContinue: { model.finishPhotos(requestAccess: true) }
            )
        case .firstLock:
            FirstLockDoneView(
                onRemoveOriginal: model.continueFromFirstLock,
                onKeepOriginal: model.continueFromFirstLock,
                onGoToVault: model.continueFromFirstLock
            )
        case .choose:
            ChooseLockView(
                biometryName: model.biometryName,
                kind: model.lockKind,
                phrase: model.phrase,
                password: model.password,
                visible: model.phraseVisible,
                biometryOn: model.biometryOn,
                message: model.message,
                onBack: model.back,
                onSelect: model.selectKind,
                onPhrase: { model.phrase = $0 },
                onPassword: { model.password = $0 },
                onToggleVisible: { model.phraseVisible.toggle() },
                onBiometry: { model.biometryOn = $0 },
                onContinue: model.continueFromChooser
            )
        case .enterSecret, .confirmSecret:
            secretSetup
        case .onboardingImport:
            ImportContainer(
                library: library,
                isOnboarding: true,
                onOnboardingFinished: model.finishOnboardingImport
            )
            .onAppear {
                library.attach(model.session, analytics: analytics)
                if library.importScreen == nil {
                    library.beginAdd()
                }
            }
        case .faceOffer:
            FaceOfferView(
                biometryName: model.biometryName,
                backup: model.lockKind.backupTitle,
                message: model.message,
                onTurnOn: model.turnOnBiometry,
                onNotNow: model.skipBiometry
            )
        case .recovery:
            RecoverySetupView(
                words: model.recoveryWords,
                tested: model.recoveryTested,
                message: model.message,
                onCopy: model.copyRecovery,
                onFiles: model.makeRecoveryFile,
                onPrint: model.printRecovery,
                onTest: model.beginRecoveryTest,
                onSaved: model.confirmRecoverySaved
            )
        case .recoveryTest:
            RecoveryTestView(
                draft: model.recoveryDraft,
                replacementPin: model.replacementPin,
                needsNewPin: model.recoveryPurpose == .replaceLock,
                message: model.message,
                onBack: model.back,
                onDraft: { model.recoveryDraft = $0 },
                onPin: { model.replacementPin = String($0.filter { $0 >= "0" && $0 <= "9" }.prefix(12)) },
                onSubmit: model.recoveryPurpose == .replaceLock ? model.submitRecoveryUnlock : model.submitRecoveryTest
            )
        }
    }

    @ViewBuilder
    private var secretSetup: some View {
        switch model.lockKind {
        case .pin:
            CreatePinView(
                title: model.secretEntryTitle,
                detail: model.step == .confirmSecret
                    ? "Enter the same PIN again."
                    : "Choose at least 6 digits you will remember. More digits are stronger. You can add \(model.biometryName) next.",
                stepLabel: model.step == .confirmSecret ? "Step 2 of 3" : "Step 1 of 3",
                pin: model.pin,
                message: model.message,
                showsOtherOptions: model.step == .enterSecret,
                onBack: model.back,
                onDigit: { digit in
                    if model.pin.count < PinDraft.minimumDigits {
                        model.appendDigit(digit)
                    }
                },
                onDelete: model.deleteDigit,
                onContinue: model.submitPin,
                onOther: { model.openOtherLockOptions() }
            )
        case .pattern:
            PatternLockView(
                title: model.secretEntryTitle,
                subtitle: "Personal vault",
                dots: model.pattern,
                message: model.message,
                showsBiometry: false,
                biometryName: model.biometryName,
                showsRecovery: false,
                onBack: model.back,
                onClear: { model.pattern = []; model.message = nil },
                onChange: { model.pattern = $0 },
                onFinish: { model.submitPattern($0) },
                onBiometry: {},
                onRecovery: {}
            )
        case .calculator:
            CalculatorLockView(
                caption: model.secretEntryTitle,
                message: model.message,
                onBack: model.back,
                onEquals: model.submitCalculator
            )
            .id(model.step)
        case .phrase, .password:
            PhraseEntryView(
                title: model.secretEntryTitle,
                text: model.lockKind == .password ? model.password : model.phrase,
                visible: model.phraseVisible,
                message: model.message,
                onBack: model.back,
                onText: { model.lockKind == .password ? (model.password = $0) : (model.phrase = $0) },
                onToggleVisible: { model.phraseVisible.toggle() },
                onContinue: model.submitPhraseConfirmation
            )
        }
    }

    private var testingSoftLockSkip: (() -> Void)? {
        #if DEBUG
        model.skipSoftLockForTesting
        #else
        nil
        #endif
    }

    @ViewBuilder
    private var locked: some View {
        if model.biometryOn && !model.showSecretLock {
            FaceLockView(
                biometryName: model.biometryName,
                backup: model.lockKind.backupTitle,
                onSecret: model.useSecretInstead,
                onSwitch: model.switchVault
            )
            .onAppear(perform: model.beginAutomaticBiometry)
        } else {
            switch model.lockKind {
            case .pin, .calculator:
                if model.lockKind == .calculator {
                    CalculatorLockView(caption: nil, message: model.message, onEquals: model.unlockCalculator)
                } else {
                    PinLockView(
                        prompt: "Enter your PIN",
                        pin: model.pin,
                        message: model.message,
                        showsBiometry: model.biometryOn,
                        onDigit: model.appendDigit,
                        onDelete: model.deleteDigit,
                        onBiometry: model.retryBiometry,
                        onRecovery: model.beginRecoveryUnlock,
                        onUnlock: model.unlockPin,
                        onTestingSkip: testingSoftLockSkip
                    )
                }
            case .pattern:
                PatternLockView(
                    title: "Draw your pattern",
                    subtitle: "Personal vault",
                    dots: model.pattern,
                    message: model.message,
                    showsBiometry: model.biometryOn,
                    biometryName: model.biometryName,
                    onChange: { model.pattern = $0 },
                    onFinish: { model.unlockPattern($0) },
                    onBiometry: model.retryBiometry,
                    onRecovery: model.beginRecoveryUnlock
                )
            case .phrase, .password:
                PhraseLockView(
                    prompt: model.lockKind == .password ? "Enter your password" : "Enter your phrase",
                    text: model.lockKind == .password ? model.password : model.phrase,
                    visible: model.phraseVisible,
                    message: model.message,
                    showsBiometry: model.biometryOn,
                    onText: { model.lockKind == .password ? (model.password = $0) : (model.phrase = $0) },
                    onToggleVisible: { model.phraseVisible.toggle() },
                    onUnlock: model.lockKind == .password ? model.unlockPassword : model.unlockPhrase,
                    onBiometry: model.retryBiometry,
                    onRecovery: model.beginRecoveryUnlock
                )
            }
        }
    }
}

struct ActivitySheet: UIViewControllerRepresentable {
    var url: URL
    var onDone: () -> Void

    func makeUIViewController(context: Context) -> ActivityHost {
        ActivityHost(url: url, onDone: onDone)
    }

    func updateUIViewController(_ controller: ActivityHost, context: Context) {}
}

final class ActivityHost: UIViewController {
    private let url: URL
    private let onDone: () -> Void
    private var presentedSheet = false

    init(url: URL, onDone: @escaping () -> Void) {
        self.url = url
        self.onDone = onDone
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !presentedSheet else { return }
        presentedSheet = true
        let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        activity.popoverPresentationController?.sourceView = view
        activity.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
        activity.completionWithItemsHandler = { [onDone] _, _, _, _ in
            onDone()
        }
        present(activity, animated: true)
    }
}

enum ScreenshotLaunch {
    static var screenName: String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-screen"), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }
}

struct ScreenshotRoot: View {
    var name: String

    var body: some View {
        switch name {
        case "question1":
            PrivateQuestionView(selected: .photos, message: nil, onBack: {}, onSelect: { _ in }, onContinue: {})
        case "question2":
            UnlockQuestionView(biometryName: BiometryLabel.current(), selected: .biometry, onBack: {}, onSelect: { _ in }, onContinue: {})
        case "photos":
            PhotosPrimerView(onBack: {}, onContinue: {})
        case "createPin":
            CreatePinView(
                title: "Create a PIN",
                detail: "Choose at least 6 digits you will remember. More digits are stronger. You can add \(BiometryLabel.current()) next.",
                stepLabel: "Step 1 of 3",
                pin: "1357",
                message: nil,
                showsOtherOptions: true,
                onBack: {}, onDigit: { _ in }, onDelete: {}, onContinue: {}, onOther: {}
            )
        case "choose":
            ChooseLockView(
                biometryName: BiometryLabel.current(),
                kind: .phrase,
                phrase: "blue-kite-river-42",
                password: "",
                visible: true,
                biometryOn: true,
                message: nil,
                onBack: {}, onSelect: { _ in }, onPhrase: { _ in }, onPassword: { _ in },
                onToggleVisible: {}, onBiometry: { _ in }, onContinue: {}
            )
        case "recovery":
            RecoverySetupView(
                words: [
                    "abandon", "ability", "able", "about", "above", "absent", "absorb", "abstract",
                    "absurd", "abuse", "access", "accident", "account", "accuse", "achieve", "acid",
                    "acoustic", "acquire", "across", "act", "action", "actor", "actress", "actual"
                ],
                tested: false,
                message: nil,
                onCopy: {}, onFiles: {}, onPrint: {}, onTest: {}, onSaved: {}
            )
        case "lockPin":
            PinLockView(prompt: "Enter your PIN", pin: "13", message: nil, showsBiometry: true, onDigit: { _ in }, onDelete: {}, onBiometry: {}, onRecovery: {})
        case "lockPhrase":
            PhraseLockView(prompt: "Enter your phrase", text: "blue river", visible: false, message: nil, showsBiometry: true, onText: { _ in }, onToggleVisible: {}, onUnlock: {}, onBiometry: {}, onRecovery: {})
        case "lockPassword":
            PhraseLockView(prompt: "Enter your password", text: "correct horse", visible: false, message: nil, showsBiometry: false, onText: { _ in }, onToggleVisible: {}, onUnlock: {}, onBiometry: {}, onRecovery: {})
        case "calculator":
            CalculatorLockView(caption: nil, message: nil, onEquals: { _ in })
        case "face":
            FaceLockView(biometryName: BiometryLabel.current(), backup: "PIN", onSecret: {}, onSwitch: {})
        case "homeEmpty", "homeFree", "homeTrial", "usage", "vaults",
             "importAdd", "importOver", "importProgress", "importPaused", "importDone",
             "photoGrid", "select", "albums", "search", "trash",
             "photoViewer", "fileViewer", "note":
            LibraryScreenshot(name: name)
        case "consent", "settings", "privacy", "security", "decoy", "selfie", "appIcon", "photoDenied", "restoreNone":
            SettingsScreenshot(name: name)
        case "shareSave":
            ShareSaveView(
                unlockedWith: "Unlocked with \(BiometryLabel.current())", count: 3, kind: .photo, vaultTitle: "Personal",
                previews: [CipherColor.tint, CipherColor.gold, CipherColor.hero], saved: false, limitMessage: nil,
                onCancel: {}, onSave: {}, onOpen: {}, onDone: {}
            )
        case "shareSaved":
            ShareSaveView(
                unlockedWith: "Unlocked with \(BiometryLabel.current())", count: 3, kind: .photo, vaultTitle: "Personal",
                previews: [CipherColor.tint, CipherColor.gold, CipherColor.hero], saved: true, limitMessage: nil,
                onCancel: {}, onSave: {}, onOpen: {}, onDone: {}
            )
        case "welcomeDaily":
            welcomeShot(.daily, added: 12)
        case "welcomeAway":
            welcomeShot(.away, added: 0)
        case "recap":
            WeeklyRecapSheet(added: 18, blocked: 2, planLine: "You are on the Free plan.", onDone: {}, onUsage: {})
        case "invite":
            InviteFriendSheet(email: "", code: "PRB7", onShare: { _ in }, onClose: {}, onOpened: {})
        case "notifications":
            NotificationPrimerScreen(onAllow: {}, onNotNow: {}, onSamples: {})
        case "samples":
            NotificationSamplesScreen(onBack: {})
        case "moreApps":
            MoreAppsScreen(onBack: {}, onOpen: {}, onTap: { _ in })
        case "help":
            HelpListScreen(onBack: {}, onOpen: { _ in }, onContact: {})
        case "toasts":
            ToastGalleryScreen()
        case "paywallOnboarding", "paywallExit", "paywallTrialUsed", "paywallLimit",
             "paywallValue", "paywallWeekly", "paywallLifetime", "paywallOffline", "trialEnded":
            PaywallScreenshot(name: name)
        case "pattern":
            PatternLockView(
                title: "Draw your pattern",
                subtitle: "Personal vault",
                dots: [0, 3, 6, 7, 4, 2],
                message: nil,
                showsBiometry: true,
                biometryName: BiometryLabel.current(),
                onChange: { _ in }, onFinish: { _ in }, onBiometry: {}, onRecovery: {}
            )
        default:
            OnboardingDemoView(onStart: {}, onSkip: {})
        }
    }

    private func welcomeShot(_ variant: WelcomeVariant, added: Int) -> some View {
        let card = WelcomeCopy.card(variant: variant, itemCount: 52, added: added, hour: 19)
        return HomeDashboard(
            shortcut: BiometryLabel.current(),
            itemCount: 52,
            chip: "Free plan · 43 of 100 photos",
            chipButton: "Upgrade",
            counts: UsageCounts(photos: 43, videos: 8, files: 1, notes: 0),
            recent: [],
            thumbs: [:],
            onSearch: {}, onLock: {}, onChip: {}, onChipAction: {}, onVaults: {},
            onKind: { _ in }, onOpen: { _ in }, onAdd: {}, onSettings: {},
            welcome: card
        )
    }
}
