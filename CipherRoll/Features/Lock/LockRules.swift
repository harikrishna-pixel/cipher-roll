import LocalAuthentication
import SwiftUI

enum LockKind: String, Codable, CaseIterable, Identifiable {
    case pin
    case pattern
    case phrase
    case calculator
    case password

    var id: String { rawValue }

    var analyticsValue: String {
        switch self {
        case .pin: "pin"
        case .pattern: "pattern"
        case .phrase: "phrase"
        case .calculator: "calc_pin"
        case .password: "password"
        }
    }

    var backupTitle: String {
        switch self {
        case .pin, .calculator: "PIN"
        case .pattern: "pattern"
        case .phrase: "phrase"
        case .password: "password"
        }
    }
}

enum OnboardingGoal: String, CaseIterable, Identifiable {
    case photos
    case documents
    case notes
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .photos: "Photos & videos"
        case .documents: "Documents & IDs"
        case .notes: "Notes"
        case .all: "All of it"
        }
    }

    var detail: String {
        switch self {
        case .photos: "Camera roll, screenshots, clips"
        case .documents: "Passport, cards, PDFs"
        case .notes: "Lists, codes, private thoughts"
        case .all: "Photos, files and notes together"
        }
    }
}

enum UnlockChoice: String, CaseIterable, Identifiable {
    case biometry
    case secret
    case pattern

    var id: String { rawValue }
}

enum SetupStep: Equatable {
    case demo
    case privateQuestion
    case unlockQuestion
    case photos
    case choose
    case enterSecret
    case confirmSecret
    case faceOffer
    case recovery
    case recoveryTest
}

enum RecoveryPurpose: Equatable {
    /// Re-enter the words shown during setup.
    case confirmWords
    /// Forgotten lock. A matching key sets a new PIN.
    case replaceLock
}

enum AppRoute: Equatable {
    case onboarding
    case locked
    case unlocked
}

enum PinDraft {
    static let minimumDigits = 6
    static let maximumDigits = 12

    static func canContinue(_ pin: String) -> Bool {
        pin.count >= minimumDigits && pin.count <= maximumDigits && pin.allSatisfy { $0 >= "0" && $0 <= "9" }
    }

    static func appending(_ digit: String, to pin: String) -> String {
        guard digit.count == 1, digit.allSatisfy({ $0 >= "0" && $0 <= "9" }), pin.count < maximumDigits else { return pin }
        return pin + digit
    }
}

enum PatternDraft {
    static let minimumDots = 6
    static let dotCount = 9

    static func canSubmit(_ dots: [Int]) -> Bool {
        dots.count >= minimumDots && Set(dots).count == dots.count && dots.allSatisfy { (0..<dotCount).contains($0) }
    }
}

enum PhraseDraft {
    static let minimumCharacters = 8

    static func canContinue(_ text: String) -> Bool {
        text.count >= minimumCharacters
    }

    static func strength(of text: String) -> (label: String, fraction: CGFloat) {
        if text.count >= 16 { return ("Strong", 0.86) }
        if text.count >= minimumCharacters { return ("Good", 0.55) }
        return ("Too short", 0.22)
    }
}

enum RecoveryConfirmation {
    static func allowsSave(tested: Bool) -> Bool { tested }

    static func words(from draft: String) -> [String] {
        draft.lowercased().split { $0.isWhitespace }.map(String.init)
    }
}

enum BiometryAttempt {
    static func shouldFallBackToSecret(failures: Int) -> Bool { failures >= 2 }
}

enum AppSwitcherPolicy {
    static func covers(_ phase: ScenePhase) -> Bool {
        phase != .active
    }

    static func locksOnReturn(from phase: ScenePhase) -> Bool {
        phase == .background
    }
}

enum BiometryLabel {
    static func current() -> String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return name(for: context.biometryType)
    }

    static func name(for type: LABiometryType) -> String {
        switch type {
        case .touchID: "Touch ID"
        case .faceID: "Face ID"
        case .opticID: "Optic ID"
        default: "Biometrics"
        }
    }

    static func symbol(named name: String) -> String {
        switch name {
        case "Touch ID": "touchid"
        case "Optic ID": "opticid"
        case "Face ID": "faceid"
        default: "lock"
        }
    }
}

enum LockCopy {
    static let pinDetail = "At least 6 digits. Quick to enter."
    static let patternDetail = "Draw a shape on a grid."
    static let phraseDetail = "Your own words. Longer is stronger."
    static let calculatorDetail = "Looks like a calculator."
    static let passwordDetail = "At least 8 characters."
    static let patternHint = "Connect at least 6 dots"
    static let recoveryWarning = "Opens your vaults if you forget your PIN. It cannot recover deleted items or restore files if you lose this iPhone. Keep it somewhere safe, not in Photos."
    static let savedKeyHint = "This button turns on after you pass the test."
    static let vaultReadyLine = "Vault contents stay on this iPhone."

    static let reviewStrings = [
        pinDetail, patternDetail, phraseDetail, calculatorDetail, passwordDetail,
        patternHint, recoveryWarning, savedKeyHint, vaultReadyLine,
        "Private photos, locked on this iPhone.",
        "Move photos out of your camera roll into a vault only you can open.",
        "Locked. Only you can open it.",
        "Choose at least 6 digits you will remember. More digits are stronger. You can add a biometric shortcut next.",
        "CipherRoll does not upload your photos."
    ]
}

enum LockSecretCodec {
    static func encode(_ secret: LockSecret) -> Data {
        switch secret {
        case .pin(let value):
            return Data("pin\n\(value)".utf8)
        case .password(let value):
            return Data("password\n\(value)".utf8)
        case .phrase(let value):
            return Data("phrase\n\(value)".utf8)
        case .pattern(let dots):
            return Data("pattern\n\(dots.map(String.init).joined(separator: ","))".utf8)
        }
    }

    static func decode(_ data: Data) throws -> LockSecret {
        guard let text = String(data: data, encoding: .utf8) else { throw VaultError.secretInvalid }
        let parts = text.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { throw VaultError.secretInvalid }
        let body = String(parts[1])
        switch parts[0] {
        case "pin": return .pin(body)
        case "password": return .password(body)
        case "phrase": return .phrase(body)
        case "pattern":
            let dots = body.split(separator: ",").compactMap { Int($0) }
            return .pattern(dots)
        default: throw VaultError.secretInvalid
        }
    }
}

enum CalculatorEntry {
    struct State: Equatable {
        var display = "0"
        var entry = ""
        var accumulator: Double?
        var pendingOperator: String?
        var fresh = true
    }

    /// Returns a PIN when "=" is tapped on an entry of at least 6 digits. Shorter entries stay on the calculator.
    static func tap(_ key: String, state: inout State) -> String? {
        switch key {
        case "C":
            state = State()
        case "±":
            toggleSign(&state)
        case "%":
            applyPercent(&state)
        case "+", "−", "×", "÷":
            pushOperator(key, state: &state)
        case "=":
            if PinDraft.canContinue(state.entry) {
                return state.entry
            }
            evaluate(state: &state, keepOperator: false)
        case ".":
            appendDecimal(&state)
        default:
            appendDigit(key, state: &state)
        }
        return nil
    }

    private static func appendDigit(_ digit: String, state: inout State) {
        guard digit.count == 1, digit.allSatisfy(\.isNumber) else { return }
        if state.fresh || state.display == "0" || state.display == "-0" {
            state.entry = digit
            state.display = digit
            state.fresh = false
        } else if state.entry.count < PinDraft.maximumDigits {
            state.entry.append(digit)
            state.display = state.entry
        }
    }

    private static func appendDecimal(_ state: inout State) {
        if state.fresh {
            state.entry = "0."
            state.display = "0."
            state.fresh = false
            return
        }
        guard !state.entry.contains(".") else { return }
        state.entry = state.entry.isEmpty ? "0." : state.entry + "."
        state.display = state.entry
    }

    private static func toggleSign(_ state: inout State) {
        guard state.display != "0" else { return }
        if state.display.hasPrefix("-") {
            state.display.removeFirst()
        } else {
            state.display = "-" + state.display
        }
        if state.entry.hasPrefix("-") {
            state.entry.removeFirst()
        } else if !state.entry.isEmpty {
            state.entry = "-" + state.entry
        }
    }

    private static func applyPercent(_ state: inout State) {
        let value = (Double(state.display) ?? 0) / 100
        state.display = format(value)
        state.entry = ""
        state.fresh = true
    }

    private static func pushOperator(_ symbol: String, state: inout State) {
        let current = Double(state.display) ?? 0
        if let pending = state.pendingOperator, let stored = state.accumulator, !state.fresh {
            state.accumulator = combine(stored, current, pending)
            state.display = format(state.accumulator ?? 0)
        } else {
            state.accumulator = current
        }
        state.pendingOperator = symbol
        state.entry = ""
        state.fresh = true
    }

    private static func evaluate(state: inout State, keepOperator: Bool) {
        let current = Double(state.display) ?? 0
        if let pending = state.pendingOperator, let stored = state.accumulator {
            let result = combine(stored, current, pending)
            state.display = format(result)
            state.accumulator = keepOperator ? result : nil
        }
        if !keepOperator { state.pendingOperator = nil }
        state.entry = ""
        state.fresh = true
    }

    private static func combine(_ left: Double, _ right: Double, _ symbol: String) -> Double {
        switch symbol {
        case "+": left + right
        case "−": left - right
        case "×": left * right
        case "÷": right == 0 ? 0 : left / right
        default: right
        }
    }

    private static func format(_ value: Double) -> String {
        if value.rounded() == value, abs(value) < 1_000_000_000 {
            return String(Int(value))
        }
        return String(value)
    }
}
