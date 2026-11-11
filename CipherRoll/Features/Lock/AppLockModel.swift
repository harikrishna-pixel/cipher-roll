import LocalAuthentication
import Photos
import SwiftUI
import UIKit

@MainActor
final class AppLockModel: ObservableObject {
    @Published var route: AppRoute = .onboarding
    @Published var step: SetupStep = .demo
    @Published var goal: OnboardingGoal?
    @Published var unlockChoice: UnlockChoice = .biometry
    @Published var lockKind: LockKind = .pin
    @Published var biometryOn = false
    @Published var cameFromChooser = false
    /// True when Choose lock was opened from Create PIN → Other options.
    private var chooseCameFromPinOptions = false
    @Published var pin = ""
    @Published var phrase = ""
    @Published var password = ""
    @Published var pattern: [Int] = []
    @Published var phraseVisible = false
    @Published var recoveryWords: [String] = []
    @Published var recoveryTested = false
    @Published var recoveryPurpose: RecoveryPurpose = .confirmWords
    @Published var recoveryDraft = ""
    @Published var replacementPin = ""
    @Published var message: String?
    @Published var busy = false
    @Published var coverVisible = false
    @Published var showSecretLock = false
    @Published var shareURL: URL?
    @Published private(set) var vaultID: UUID?

    let biometryName: String
    private let vault: VaultService
    private let secrets: BiometrySecretStoring
    private let defaults: UserDefaults
    private let analytics: any AnalyticsClient
    private var firstSecret: LockSecret?
    private var confirmSecret: LockSecret?
    @Published private(set) var session: UnlockedSession?
    private var armLock = false
    private var backgroundedAt: Date?
    private var biometryStarted = false
    private var faceFailures = 0
    private var wrongAttempts = 0
    private let preferencesKind = "app.cipherroll.lock.kind"
    private let preferencesBiometry = "app.cipherroll.lock.biometry"
    private let preferencesGoal = "app.cipherroll.onboarding.goal"

    init(
        vault: VaultService = VaultServiceFactory.makeForApp(),
        secrets: BiometrySecretStoring = BiometryStoreFactory.make(),
        defaults: UserDefaults = AppGroupDefaults.suite,
        analytics: any AnalyticsClient = NoOpAnalyticsClient(),
        biometryName: String = BiometryLabel.current()
    ) {
        self.vault = vault
        self.secrets = secrets
        self.defaults = defaults
        self.analytics = analytics
        self.biometryName = biometryName
        try? vault.sweepInterruptedWork()
        restore()
    }

    func sceneChanged(to phase: ScenePhase) {
        coverVisible = AppSwitcherPolicy.covers(phase)
        if AppSwitcherPolicy.locksOnReturn(from: phase) {
            backgroundedAt = Date()
            armLock = vaultID != nil
        }
        if phase == .active, armLock {
            armLock = false
            coverVisible = false
            let delay = LockDelay(rawValue: defaults.integer(forKey: SettingsKeys.lockDelay)) ?? .immediately
            if LockDelay.shouldLock(since: backgroundedAt, delay: delay, now: Date()) {
                lockAfterBackground()
            }
        }
    }

    func selectGoal(_ goal: OnboardingGoal) {
        self.goal = goal
        defaults.set(goal.rawValue, forKey: preferencesGoal)
    }

    func continueFromDemo() { step = .privateQuestion }
    func skipDemo() {
        // Skip welcome + questions; go straight to Create PIN with Face ID path defaults.
        unlockChoice = .biometry
        lockKind = .pin
        biometryOn = true
        cameFromChooser = false
        chooseCameFromPinOptions = false
        clearEntry()
        step = .enterSecret
        analytics.track("onboarding_step_viewed", properties: ["step": "create_pin", "via": "skip"])
    }

    func continueFromPrivateQuestion() {
        guard goal != nil else {
            message = "Choose one to continue."
            return
        }
        message = nil
        step = .unlockQuestion
    }

    func selectUnlock(_ choice: UnlockChoice) {
        unlockChoice = choice
    }

    func continueFromUnlockQuestion() {
        message = nil
        step = .photos
    }

    func finishPhotos(requestAccess: Bool) {
        if requestAccess {
            analytics.track("permission_requested", properties: ["type": "photos_delete_originals"])
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { [analytics] status in
                let result: String
                switch status {
                case .authorized: result = "authorized"
                case .limited: result = "limited"
                case .denied: result = "denied"
                case .restricted: result = "restricted"
                default: result = "not_determined"
                }
                analytics.track("permission_result", properties: ["type": "photos_delete_originals", "result": result])
            }
        }
        step = .firstLock
        analytics.track("onboarding_step_viewed", properties: ["step": "first_lock"])
    }

    func continueFromFirstLock() {
        chooseCameFromPinOptions = false
        switch unlockChoice {
        case .biometry:
            lockKind = .pin
            biometryOn = true
            cameFromChooser = false
            step = .enterSecret
            analytics.track("onboarding_step_viewed", properties: ["step": "create_pin"])
        case .pattern:
            lockKind = .pattern
            biometryOn = false
            cameFromChooser = false
            step = .enterSecret
        case .secret:
            cameFromChooser = true
            step = .choose
        }
    }

    func openOtherLockOptions() {
        cameFromChooser = true
        chooseCameFromPinOptions = true
        step = .choose
    }

    func selectKind(_ kind: LockKind) {
        lockKind = kind
        message = nil
    }

    func continueFromChooser() {
        switch lockKind {
        case .pin, .pattern, .calculator:
            cameFromChooser = true
            clearEntry()
            step = .enterSecret
            if lockKind == .pin {
                analytics.track("onboarding_step_viewed", properties: ["step": "create_pin"])
            }
        case .phrase:
            guard PhraseDraft.canContinue(phrase) else {
                message = "Use 8 or more characters."
                return
            }
            confirmSecret = .phrase(phrase)
            phrase = ""
            phraseVisible = false
            message = nil
            step = .confirmSecret
        case .password:
            guard PhraseDraft.canContinue(password) else {
                message = "Use 8 or more characters."
                return
            }
            confirmSecret = .password(password)
            password = ""
            phraseVisible = false
            message = nil
            step = .confirmSecret
        }
    }

    func appendDigit(_ digit: String) {
        pin = PinDraft.appending(digit, to: pin)
    }

    func deleteDigit() {
        guard !pin.isEmpty else { return }
        pin.removeLast()
    }

    func submitPin() {
        guard PinDraft.canContinue(pin) else {
            message = "Choose at least 6 digits."
            return
        }
        message = nil
        if step == .enterSecret {
            confirmSecret = .pin(pin)
            pin = ""
            step = .confirmSecret
            return
        }
        guard case .pin(let expected) = confirmSecret, expected == pin else {
            pin = ""
            message = "PINs did not match. Enter it again."
            return
        }
        create(secret: .pin(pin))
    }

    func submitPattern(_ drawn: [Int]? = nil) {
        let current = drawn ?? pattern
        pattern = current
        guard PatternDraft.canSubmit(current) else {
            message = LockCopy.patternHint
            pattern = []
            return
        }
        message = nil
        if step == .enterSecret {
            confirmSecret = .pattern(current)
            pattern = []
            step = .confirmSecret
            return
        }
        guard case .pattern(let expected) = confirmSecret, expected == current else {
            pattern = []
            message = "Patterns did not match. Draw it again."
            return
        }
        create(secret: .pattern(current))
    }

    func submitPhraseConfirmation() {
        let entered: LockSecret = lockKind == .password ? .password(password) : .phrase(phrase)
        guard entered == confirmSecret else {
            phrase = ""
            password = ""
            message = "Those did not match. Enter it again."
            return
        }
        create(secret: entered)
    }

    func submitCalculator(_ digits: String) {
        guard PinDraft.canContinue(digits) else { return }
        if step == .enterSecret {
            confirmSecret = .pin(digits)
            message = nil
            step = .confirmSecret
            return
        }
        guard case .pin(let expected) = confirmSecret, expected == digits else {
            message = "That did not match. Enter the same digits, then tap =."
            return
        }
        create(secret: .pin(digits))
    }

    func back() {
        message = nil
        switch step {
        case .demo:
            break
        case .privateQuestion:
            step = .demo
        case .unlockQuestion:
            step = .privateQuestion
        case .photos:
            step = .unlockQuestion
        case .firstLock:
            step = .photos
        case .choose:
            if chooseCameFromPinOptions {
                chooseCameFromPinOptions = false
                lockKind = .pin
                clearEntry()
                step = .enterSecret
            } else {
                step = .firstLock
            }
        case .enterSecret:
            clearEntry()
            step = cameFromChooser ? .choose : .firstLock
        case .confirmSecret:
            clearEntry()
            if lockKind == .phrase || lockKind == .password {
                confirmSecret = nil
                step = .choose
            } else {
                step = .enterSecret
            }
        case .onboardingImport, .faceOffer, .recovery:
            break
        case .recoveryTest:
            if recoveryPurpose == .replaceLock {
                route = .locked
                showSecretLock = true
                recoveryDraft = ""
                replacementPin = ""
            } else {
                step = .recovery
            }
        }
    }

    func turnOnBiometry() {
        guard let secret = firstSecret else {
            finishFaceStep(enabled: false)
            return
        }
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            message = "\(biometryName) is not set up on this device. You can still unlock with your \(lockKind.backupTitle)."
            return
        }
        analytics.track("permission_requested", properties: ["type": "face_id"])
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Turn on \(biometryName) as a shortcut") { [weak self] success, evalError in
            Task { @MainActor in
                guard let self else { return }
                guard success else {
                    self.message = self.biometryMessage(evalError)
                    self.analytics.track("permission_result", properties: ["type": "face_id", "result": "denied"])
                    return
                }
                do {
                    try self.secrets.save(secret)
                    self.analytics.track("permission_result", properties: ["type": "face_id", "result": "authorized"])
                    self.finishFaceStep(enabled: true)
                } catch {
                    self.message = "\(self.biometryName) could not be turned on. Your \(self.lockKind.backupTitle) still works."
                }
            }
        }
    }

    func skipBiometry() {
        try? secrets.delete()
        finishFaceStep(enabled: false)
    }

    func copyRecovery() {
        UIPasteboard.general.string = recoveryWords.joined(separator: " ")
        analytics.track("recovery_key_saved", properties: ["how": "copy"])
        message = "Copied. Store it somewhere safe, not in Photos."
    }

    func makeRecoveryFile() {
        let text = recoveryWords.joined(separator: " ")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("CipherRoll-recovery-key.txt")
        do {
            try ProtectedFile.write(Data(text.utf8), to: url)
            shareURL = url
            analytics.track("recovery_key_saved", properties: ["how": "files"])
        } catch {
            message = "The key could not be prepared for Files."
        }
    }

    func finishedSharing() {
        if let shareURL {
            try? FileManager.default.removeItem(at: shareURL)
        }
        shareURL = nil
    }

    func printRecovery() {
        let formatter = UISimpleTextPrintFormatter(text: recoveryWords.joined(separator: "\n"))
        let controller = UIPrintInteractionController.shared
        controller.printFormatter = formatter
        controller.present(animated: true)
        analytics.track("recovery_key_saved", properties: ["how": "print"])
    }

    func beginRecoveryTest() {
        recoveryPurpose = .confirmWords
        recoveryDraft = ""
        message = nil
        step = .recoveryTest
    }

    func submitRecoveryTest() {
        let words = RecoveryConfirmation.words(from: recoveryDraft)
        guard words.count == 24 else {
            message = "Enter all 24 words, in order."
            analytics.track("recovery_key_tested", properties: ["result": "fail"])
            return
        }
        do {
            try vault.testRecoveryWords(words)
            recoveryTested = true
            recoveryDraft = ""
            message = "Key matches."
            step = .recovery
            analytics.track("recovery_key_tested", properties: ["result": "pass"])
        } catch {
            message = "That key did not match."
            analytics.track("recovery_key_tested", properties: ["result": "fail"])
        }
    }

    func confirmRecoverySaved() {
        guard RecoveryConfirmation.allowsSave(tested: recoveryTested) else { return }
        do {
            try vault.confirmRecoveryWordsSaved()
            recoveryWords = []
            message = nil
            pin = ""
            analytics.track("onboarding_completed", properties: goal.map { ["goal": $0.rawValue] } ?? [:])
            route = .locked
            showSecretLock = !biometryOn
            biometryStarted = false
        } catch {
            message = friendly(error)
        }
    }

    func beginAutomaticBiometry() {
        guard biometryOn, !showSecretLock, !biometryStarted, route == .locked else { return }
        guard vault.allowsAutomaticBiometry() else { return }
        biometryStarted = true
        evaluateBiometry()
    }

    func retryBiometry() {
        showSecretLock = false
        biometryStarted = false
        faceFailures = 0
        message = nil
        beginAutomaticBiometry()
    }

    func useSecretInstead() {
        showSecretLock = true
        biometryStarted = true
        pin = ""
        pattern = []
        phrase = ""
        password = ""
        message = nil
    }

    func switchVault() {
        message = nil
    }

    func createDecoy(pin: String, done: @escaping (Bool) -> Void) {
        guard PinDraft.canContinue(pin) else {
            message = LockCopy.pinDetail
            done(false)
            return
        }
        let secret = LockSecret.pin(pin)
        busy = true
        DispatchQueue.global(qos: .userInitiated).async { [vault] in
            do {
                _ = try vault.createVault(secret: secret, role: .decoy)
                DispatchQueue.main.async { [weak self] in
                    self?.busy = false
                    done(true)
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.busy = false
                    self?.message = "Choose a different PIN."
                    done(false)
                }
            }
        }
    }

    func setLockKind(_ kind: LockKind) {
        lockKind = kind
        defaults.set(kind.rawValue, forKey: preferencesKind)
        analytics.track("lock_type_set", properties: [
            "lock_type": kind.analyticsValue,
            "face_id_on": biometryOn ? "true" : "false"
        ])
    }

    func unlockPin() {
        #if DEBUG
        if session != nil {
            skipSoftLockForTesting()
            return
        }
        #endif
        guard PinDraft.canContinue(pin), let vaultID else { return }
        unlock(.pin(pin), vault: vaultID, method: "secret")
    }

    func unlockPattern(_ drawn: [Int]? = nil) {
        let current = drawn ?? pattern
        pattern = current
        guard PatternDraft.canSubmit(current), let vaultID else {
            message = LockCopy.patternHint
            pattern = []
            return
        }
        unlock(.pattern(current), vault: vaultID, method: "secret")
    }

    func unlockPhrase() {
        guard PhraseDraft.canContinue(phrase), let vaultID else { return }
        unlock(.phrase(phrase), vault: vaultID, method: "secret")
    }

    func unlockPassword() {
        guard PhraseDraft.canContinue(password), let vaultID else { return }
        unlock(.password(password), vault: vaultID, method: "secret")
    }

    func unlockCalculator(_ digits: String) {
        guard PinDraft.canContinue(digits), let vaultID else { return }
        unlock(.pin(digits), vault: vaultID, method: "secret")
    }

    func beginRecoveryUnlock() {
        recoveryPurpose = .replaceLock
        recoveryDraft = ""
        replacementPin = ""
        message = nil
        route = .onboarding
        step = .recoveryTest
    }

    func submitRecoveryUnlock() {
        guard let vaultID else { return }
        let words = RecoveryConfirmation.words(from: recoveryDraft)
        guard words.count == 24 else {
            message = "Enter all 24 words, in order."
            return
        }
        guard PinDraft.canContinue(replacementPin) else {
            message = "Choose a new PIN of at least 6 digits."
            return
        }
        let secret = LockSecret.pin(replacementPin)
        busy = true
        DispatchQueue.global(qos: .userInitiated).async { [vault] in
            do {
                let session = try vault.unlockWithRecovery(vault: vaultID, words: words, newSecret: secret)
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.busy = false
                    self.session = session
                    self.lockKind = .pin
                    self.defaults.set(LockKind.pin.rawValue, forKey: self.preferencesKind)
                    self.recoveryDraft = ""
                    self.replacementPin = ""
                    self.route = .unlocked
                    self.analytics.track("recovery_used", properties: ["result": "pass"])
                    self.analytics.track("vault_unlocked", properties: ["method": "secret"])
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.busy = false
                    self?.message = "That key did not match."
                    self?.analytics.track("recovery_used", properties: ["result": "fail"])
                }
            }
        }
    }

    func lockFromInside() {
        session?.lock()
        session = nil
        clearEntry()
        route = .locked
        showSecretLock = !biometryOn
        biometryStarted = false
        faceFailures = 0
    }

    #if DEBUG
    /// Testing only: cover the vault UI without wiping the session, so the lock icon can skip back in.
    func softLockForTesting() {
        clearEntry()
        route = .locked
        showSecretLock = true
        biometryStarted = false
        faceFailures = 0
    }

    func skipSoftLockForTesting() {
        guard session != nil else { return }
        clearEntry()
        message = nil
        route = .unlocked
    }
    #endif

    var secretEntryTitle: String {
        if step == .confirmSecret {
            switch lockKind {
            case .pin: return "Confirm your PIN"
            case .pattern: return "Draw it again"
            case .calculator: return "Enter it again"
            case .phrase: return "Confirm your phrase"
            case .password: return "Confirm your password"
            }
        }
        switch lockKind {
        case .pin: return "Create a PIN"
        case .pattern: return "Draw your pattern"
        case .calculator: return "Enter at least 6 digits, then tap ="
        case .phrase: return "Create a phrase"
        case .password: return "Create a password"
        }
    }

    var useSecretTitle: String {
        switch lockKind {
        case .pin, .calculator: "Use PIN instead"
        case .pattern: "Use pattern instead"
        case .phrase: "Use phrase instead"
        case .password: "Use password instead"
        }
    }

    private func restore() {
        if let raw = defaults.string(forKey: preferencesKind), let kind = LockKind(rawValue: raw) {
            lockKind = kind
        }
        biometryOn = defaults.bool(forKey: preferencesBiometry)
        if let raw = defaults.string(forKey: preferencesGoal), let stored = OnboardingGoal(rawValue: raw) {
            goal = stored
        }
        guard let id = try? vault.realVaultID() else {
            route = .onboarding
            step = .demo
            return
        }
        vaultID = id
        if let pending = try? vault.pendingRecoveryWords(), !pending.isEmpty {
            recoveryWords = pending
            recoveryTested = (try? vault.recoveryWordsWereTested()) ?? false
            route = .onboarding
            step = .recovery
            return
        }
        route = .locked
        showSecretLock = !biometryOn
    }

    func finishOnboardingImport() {
        analytics.track("onboarding_step_viewed", properties: ["step": "import_done"])
        if biometryOn {
            step = .faceOffer
            analytics.track("onboarding_step_viewed", properties: ["step": "face_id_offer"])
        } else {
            firstSecret = nil
            if recoveryWords.isEmpty {
                route = .unlocked
            } else {
                step = .recovery
            }
        }
    }

    private func create(secret: LockSecret) {
        guard !busy else { return }
        busy = true
        message = nil
        // Secure Enclave / Keychain wrapping must stay on the main thread on device.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            do {
                let created = try self.vault.createVault(secret: secret, role: .real)
                self.vaultID = created.id
                self.firstSecret = secret
                self.recoveryWords = created.recoveryWords ?? []
                self.recoveryTested = false
                self.defaults.set(self.lockKind.rawValue, forKey: self.preferencesKind)
                self.analytics.track("lock_type_set", properties: [
                    "lock_type": self.lockKind.analyticsValue,
                    "face_id_on": self.biometryOn ? "true" : "false"
                ])
                if let words = created.recoveryWords, !words.isEmpty {
                    self.analytics.track("recovery_key_created", properties: [:])
                }
                // Leave the confirm screen before clearing digits / dropping the busy cover
                // so the UI does not flash an empty PIN pad.
                do {
                    let opened = try self.vault.unlock(activeVault: created.id, secret: secret)
                    self.session = opened
                    self.step = .onboardingImport
                    self.analytics.track("onboarding_step_viewed", properties: ["step": "import"])
                } catch {
                    self.continueAfterCreateWithoutImport()
                }
                self.clearEntry()
                self.busy = false
            } catch {
                self.busy = false
                self.message = self.friendly(error)
            }
        }
    }

    private func continueAfterCreateWithoutImport() {
        if biometryOn {
            step = .faceOffer
            analytics.track("onboarding_step_viewed", properties: ["step": "face_id_offer"])
        } else {
            firstSecret = nil
            step = recoveryWords.isEmpty ? .demo : .recovery
            if recoveryWords.isEmpty { route = .locked }
        }
    }

    private func finishFaceStep(enabled: Bool) {
        biometryOn = enabled
        defaults.set(enabled, forKey: preferencesBiometry)
        firstSecret = nil
        clearEntry()
        message = nil
        if recoveryWords.isEmpty {
            route = .locked
            showSecretLock = !enabled
        } else {
            step = .recovery
        }
    }

    private func unlock(_ secret: LockSecret, vault vaultID: UUID, method: String) {
        guard !busy else { return }
        busy = true
        message = nil
        let vault = vault
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let opened = try vault.unlock(activeVault: vaultID, secret: secret)
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.busy = false
                    self.session = opened
                    self.clearEntry()
                    self.route = .unlocked
                    self.wrongAttempts = 0
                    self.analytics.track("vault_unlocked", properties: UnlockAnalytics.properties(method: method))
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.busy = false
                    self.clearEntry()
                    self.wrongAttempts += 1
                    let seen = self.defaults.integer(forKey: RetentionKeys.wrongAttempts)
                    self.defaults.set(seen + 1, forKey: RetentionKeys.wrongAttempts)
                    self.message = self.friendly(error)
                    if BreakInPolicy.shouldCapture(enabled: self.defaults.bool(forKey: SettingsKeys.breakIn), attempts: self.wrongAttempts) {
                        BreakInStore.capture()
                    }
                }
            }
        }
    }

    private func evaluateBiometry() {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        context.localizedFallbackTitle = useSecretTitle
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            showSecretLock = true
            return
        }
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Unlock Personal") { [weak self] success, evalError in
            Task { @MainActor in
                guard let self else { return }
                if success {
                    do {
                        guard let secret = try self.secrets.load(context: context), let vaultID = self.vaultID else {
                            self.showSecretLock = true
                            return
                        }
                        self.unlock(secret, vault: vaultID, method: "face_id")
                    } catch {
                        self.showSecretLock = true
                    }
                    return
                }
                if let code = (evalError as? LAError)?.code {
                    switch code {
                    case .userCancel, .appCancel, .systemCancel:
                        return
                    case .userFallback:
                        self.useSecretInstead()
                        return
                    default:
                        break
                    }
                }
                self.faceFailures += 1
                if BiometryAttempt.shouldFallBackToSecret(failures: self.faceFailures) {
                    self.useSecretLockAfterFailures()
                } else {
                    self.biometryStarted = false
                    self.beginAutomaticBiometry()
                }
            }
        }
    }

    private func useSecretLockAfterFailures() {
        showSecretLock = true
        message = "Enter your \(lockKind.backupTitle)."
    }

    private func lockAfterBackground() {
        session?.lock()
        session = nil
        clearEntry()
        faceFailures = 0
        biometryStarted = false
        if let pending = try? vault.pendingRecoveryWords(), !pending.isEmpty {
            recoveryWords = pending
            route = .onboarding
            step = .recovery
            return
        }
        guard vaultID != nil else { return }
        route = .locked
        showSecretLock = !biometryOn
    }

    private func clearEntry() {
        pin = ""
        phrase = ""
        password = ""
        pattern = []
        phraseVisible = false
    }

    private func biometryMessage(_ error: Error?) -> String {
        if let code = (error as? LAError)?.code, code == .userCancel || code == .userFallback {
            return "\(biometryName) was not turned on. Your \(lockKind.backupTitle) still works."
        }
        return "\(biometryName) did not succeed. You can try again or tap Not now."
    }

    private func friendly(_ error: Error) -> String {
        guard let error = error as? VaultError else { return "Something went wrong. Try again." }
        switch error {
        case .secretTooShort:
            return "Use at least 6 digits, or 8 characters for a phrase or password."
        case .authenticationFailed:
            return "That did not match."
        case .lockedOut:
            return "Too many tries. Wait, then try again."
        case .noPasscode:
            return "Set a device passcode, then try again."
        case .recoveryNotTested:
            return LockCopy.savedKeyHint
        case .secretInvalid:
            return "Choose a different lock."
        case .wrapFailed:
            return "The vault could not be saved on this iPhone. Set a passcode in Settings, then try again."
        default:
            return "Something went wrong. Try again."
        }
    }
}
