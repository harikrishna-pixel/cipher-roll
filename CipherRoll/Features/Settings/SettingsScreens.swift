import SwiftUI

struct ConsentScreen: View {
    var onAllow: () -> Void
    var onNotNow: () -> Void
    var onPrivacy: () -> Void

    var body: some View {
        CipherScreen {
            ScrollView {
            VStack(spacing: CipherSpace.s16) {
                CipherIcon.shield.image
                    .foregroundStyle(CipherColor.tintInk)
                    .frame(width: 36, height: 36)
                    .frame(width: 72, height: 72)
                    .background(CipherColor.tint, in: RoundedRectangle(cornerRadius: 18))
                Text(SettingsCopy.consentTitle)
                    .font(CipherFont.title)
                    .foregroundStyle(CipherColor.ink)
                    .multilineTextAlignment(.center)
                Text(SettingsCopy.consentBody)
                    .font(CipherFont.body)
                    .foregroundStyle(CipherColor.sub)
                    .multilineTextAlignment(.center)
                Text(SettingsCopy.consentChange)
                    .font(CipherFont.caption)
                    .foregroundStyle(CipherColor.sub)
                    .multilineTextAlignment(.center)
                Button("Allow", action: onAllow).buttonStyle(CipherGoldButtonStyle())
                Button("Not now", action: onNotNow)
                    .font(CipherFont.button)
                    .foregroundStyle(CipherColor.sub)
                    .frame(minHeight: 44)
                Button("Privacy policy", action: onPrivacy)
                    .font(CipherFont.button)
                    .foregroundStyle(CipherColor.link)
                    .frame(minHeight: CipherA11y.minimumTarget)
            }
            .padding(CipherSpace.s24)
            .frame(maxWidth: 560)
            }
        }
    }
}

struct SettingsHome: View {
    @ObservedObject var settings: SettingsModel
    var planTitle: String
    var planDetail: String
    var lockTitle: String
    var recoveryTitle: String
    var trashCount: Int
    var onUpgrade: () -> Void
    var onLockType: () -> Void
    var onLockAfter: () -> Void
    var onPrivacy: () -> Void
    var onRecovery: () -> Void
    var onSelfie: () -> Void
    var onSecurity: () -> Void
    var onTrash: () -> Void
    var onExport: () -> Void
    var onDecoy: () -> Void
    var onRestore: () -> Void
    var onManage: () -> Void
    var onLock: () -> Void
    var onHelp: () -> Void = {}
    var onInvite: () -> Void = {}
    var onMoreApps: () -> Void = {}
    var onFeedback: () -> Void = {}
    var onBackupExport: () -> Void = {}
    var onBackupRestore: () -> Void = {}

    var body: some View {
        CipherScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: CipherSpace.s16) {
                    Text("Settings").font(CipherFont.title).foregroundStyle(CipherColor.ink)
                    if let message = settings.message {
                        Text(message).font(CipherFont.caption).foregroundStyle(CipherColor.sub)
                    }
                    planCard
                    section("Security") {
                        row("Lock type", lockTitle, onLockType)
                        row("Lock after", settings.lockDelay.title, onLockAfter)
                        row("Hide app preview", "On", onPrivacy)
                        row("Recovery key", recoveryTitle, onRecovery)
                        row("Break-in selfie", settings.breakIn ? "On" : "Off", onSelfie)
                        row("Decoy vault", "Pro", onDecoy)
                    }
                    section("Data") {
                        row("Security and storage", "Not backed up", onSecurity)
                        row("Recently Deleted", trashCount == 1 ? "1 item" : "\(trashCount) items", onTrash)
                        row("Export a backup", "", onBackupExport)
                        row("Restore from backup", "", onBackupRestore)
                        row("Export all items", "", onExport)
                    }
                    section("Plan and support") {
                        row("Restore purchases", "", onRestore)
                        row("Manage subscription", "", onManage)
                        row("Privacy and lock", "", onPrivacy)
                        row("Help", "", onHelp)
                        row("Invite a friend", "", onInvite)
                        row("More from Marberx", "", onMoreApps)
                        row("Send feedback", "", onFeedback)
                    }
                    Button("Lock", action: onLock).buttonStyle(CipherGoldButtonStyle())
                }
                .padding(CipherSpace.s20)
            }
        }
    }

    private var planCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(planTitle).font(CipherFont.button).foregroundStyle(.white)
                Text(planDetail).font(CipherFont.caption).foregroundStyle(Color.white.opacity(0.75))
            }
            Spacer()
            Button("Upgrade", action: onUpgrade)
                .font(CipherFont.button)
                .foregroundStyle(CipherColor.onGold)
                .padding(.horizontal, 16)
                .frame(minHeight: 44)
                .background(CipherColor.gold, in: Capsule())
                .buttonStyle(.plain)
        }
        .padding(CipherSpace.s16)
        .background(CipherColor.hero, in: RoundedRectangle(cornerRadius: CipherRadius.card))
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: CipherSpace.s8) {
            Text(title.uppercased()).font(CipherFont.caption).foregroundStyle(CipherColor.sub)
            VStack(spacing: 0) { content() }
                .background(CipherColor.card, in: RoundedRectangle(cornerRadius: CipherRadius.card))
        }
    }

    private func row(_ title: String, _ value: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).font(CipherFont.button).foregroundStyle(CipherColor.ink)
                Spacer()
                if !value.isEmpty {
                    Text(value).font(CipherFont.caption).foregroundStyle(CipherColor.sub)
                }
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(CipherColor.sub)
            }
            .padding(.horizontal, CipherSpace.s16)
            .frame(minHeight: 52)
        }
        .buttonStyle(.plain)
    }
}

struct PrivacyLockScreen: View {
    @ObservedObject var settings: SettingsModel
    var calculatorOn: Bool
    var onCalculator: (Bool) -> Void
    var onIcons: () -> Void
    var onBack: () -> Void

    var body: some View {
        CipherScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: CipherSpace.s16) {
                    header("Privacy and lock", onBack)
                    card {
                        toggle("Share anonymous usage stats", SettingsCopy.usageDetail, settings.usageStatsOn) {
                            settings.setUsageStats($0)
                        }
                        Divider()
                        toggle("Break-in selfie", SettingsCopy.breakInDetail, settings.breakIn) { on in
                            settings.setBreakIn(on)
                        }
                    }
                    card {
                        toggle("Calculator-style lock", SettingsCopy.calculatorDetail, calculatorOn, onCalculator)
                        Divider()
                        Button(action: onIcons) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("App icon").font(CipherFont.button).foregroundStyle(CipherColor.ink)
                                    Text(SettingsCopy.iconDetail).font(CipherFont.caption).foregroundStyle(CipherColor.sub)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(CipherColor.sub)
                            }
                            .padding(CipherSpace.s16)
                        }
                        .buttonStyle(.plain)
                    }
                    Text(SettingsCopy.vaultStays).font(CipherFont.caption).foregroundStyle(CipherColor.sub)
                    Text(SettingsCopy.previewDetail).font(CipherFont.caption).foregroundStyle(CipherColor.sub)
                }
                .padding(CipherSpace.s20)
            }
        }
        .onAppear { settings.reloadPhotos() }
    }

    private func toggle(_ title: String, _ detail: String, _ on: Bool, _ action: @escaping (Bool) -> Void) -> some View {
        Toggle(isOn: Binding(get: { on }, set: action)) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(CipherFont.button).foregroundStyle(CipherColor.ink)
                Text(detail).font(CipherFont.caption).foregroundStyle(CipherColor.sub)
            }
        }
        .tint(CipherColor.gold)
        .padding(CipherSpace.s16)
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .background(CipherColor.card, in: RoundedRectangle(cornerRadius: CipherRadius.card))
    }

    private func header(_ title: String, _ back: @escaping () -> Void) -> some View {
        HStack {
            CipherBackButton(action: back)
            Text(title).font(CipherFont.h2).foregroundStyle(CipherColor.ink)
            Spacer()
        }
    }
}

struct SecurityStorageScreen: View {
    var recovery: String
    var freeSpace: String
    var onBack: () -> Void
    var onExport: () -> Void
    var onBackup: () -> Void = {}
    var onRestoreBackup: () -> Void = {}
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var regular: Bool { CipherLayout.usesSidebar(sizeClass) }

    var body: some View {
        CipherScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: CipherSpace.s16) {
                    HStack {
                        CipherBackButton(action: onBack)
                        Text("Security and storage").font(CipherFont.h2).foregroundStyle(CipherColor.ink)
                        Spacer()
                    }
                    VStack(spacing: 0) {
                        status("App lock", "Active")
                        status("Recovery key", recovery)
                        status(DeviceCopy.storageRow(regularWidth: regular), freeSpace)
                        status("Backup", "Not backed up")
                    }
                    .background(CipherColor.card, in: RoundedRectangle(cornerRadius: CipherRadius.card))
                    VStack(alignment: .leading, spacing: CipherSpace.s8) {
                        Text(DeviceCopy.storageTitle(regularWidth: regular))
                            .font(CipherFont.button).foregroundStyle(CipherColor.ink)
                        Text(DeviceCopy.storageWarning(regularWidth: regular))
                            .font(CipherFont.caption).foregroundStyle(CipherColor.sub)
                        Text(SettingsCopy.backupLater)
                            .font(CipherFont.caption).foregroundStyle(CipherColor.sub)
                    }
                    .padding(CipherSpace.s16)
                    .overlay(RoundedRectangle(cornerRadius: CipherRadius.card).stroke(CipherColor.amber, lineWidth: 1))
                    Button("Export a backup", action: onBackup)
                        .buttonStyle(CipherGoldButtonStyle())
                    Button("Restore from backup", action: onRestoreBackup)
                        .buttonStyle(CipherOutlineButtonStyle())
                    Button("Export all items", action: onExport)
                        .buttonStyle(CipherOutlineButtonStyle())
                    Text("Before getting a new iPhone: export your items, then import them on the new device.")
                        .font(CipherFont.caption).foregroundStyle(CipherColor.sub)
                }
                .padding(CipherSpace.s20)
            }
        }
    }

    private func status(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).font(CipherFont.button).foregroundStyle(CipherColor.ink)
            Spacer()
            Text(value).font(CipherFont.caption).foregroundStyle(CipherColor.sub)
        }
        .padding(.horizontal, CipherSpace.s16)
        .frame(minHeight: 52)
    }
}

struct DecoySetupScreen: View {
    var itemCount: Int
    var needsPlan: Bool
    var pin: String
    var message: String?
    var onBack: () -> Void
    var onDigit: (String) -> Void
    var onDelete: () -> Void
    var onCreate: () -> Void
    var onPlan: () -> Void

    var body: some View {
        CipherScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: CipherSpace.s16) {
                    HStack {
                        CipherBackButton(action: onBack)
                        Spacer()
                        Text("Decoy vault").font(CipherFont.button).foregroundStyle(CipherColor.ink)
                        Spacer()
                        Text("Pro")
                            .font(CipherFont.caption)
                            .foregroundStyle(CipherColor.onGold)
                            .padding(.horizontal, 10)
                            .frame(minHeight: 28)
                            .background(CipherColor.gold, in: Capsule())
                    }
                    Text(SettingsCopy.decoyTitle).font(CipherFont.title).foregroundStyle(CipherColor.ink)
                    Text(SettingsCopy.decoySubtitle).font(CipherFont.body).foregroundStyle(CipherColor.sub)
                    point(SettingsCopy.decoyOwn)
                    point(SettingsCopy.decoyPro)
                    point(SettingsCopy.decoyForgotten)
                    Text("Personal · \(ItemCountCopy.label(itemCount))").font(CipherFont.caption).foregroundStyle(CipherColor.sub)
                    Text(SettingsCopy.decoyPINDetail).font(CipherFont.caption).foregroundStyle(CipherColor.sub)
                    pinDots
                    if let message {
                        Text(message).font(CipherFont.caption).foregroundStyle(CipherColor.danger)
                    }
                    digitPad
                    Button(needsPlan ? "See plans" : "Create decoy vault", action: needsPlan ? onPlan : onCreate)
                        .buttonStyle(CipherGoldButtonStyle())
                        .disabled(!needsPlan && !PinDraft.canContinue(pin))
                }
                .padding(CipherSpace.s20)
            }
        }
    }

    private var pinDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<max(pin.count, 6), id: \.self) { index in
                Circle().fill(index < pin.count ? CipherColor.ink : CipherColor.line).frame(width: 12, height: 12)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel("\(pin.count) digits")
    }

    private var digitPad: some View {
        let rows = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], ["", "0", "del"]]
        return VStack(spacing: 8) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { key in
                        Button(key == "del" ? "Delete" : key) {
                            if key == "del" { onDelete() } else if !key.isEmpty { onDigit(key) }
                        }
                        .font(CipherFont.button)
                        .foregroundStyle(CipherColor.ink)
                        .frame(maxWidth: .infinity, minHeight: CipherA11y.minimumTarget)
                        .opacity(key.isEmpty ? 0 : 1)
                        .accessibilityHidden(key.isEmpty)
                    }
                }
            }
        }
    }

    private func point(_ text: String) -> some View {
        HStack(alignment: .top, spacing: CipherSpace.s8) {
            Image(systemName: "checkmark").foregroundStyle(CipherColor.tintInk)
            Text(text).font(CipherFont.body).foregroundStyle(CipherColor.ink)
        }
    }
}

struct SelfieScreen: View {
    @ObservedObject var settings: SettingsModel
    var onBack: () -> Void

    var body: some View {
        CipherScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: CipherSpace.s16) {
                    HStack {
                        CipherBackButton(action: onBack)
                        Spacer()
                        Text("Break-in selfie").font(CipherFont.button).foregroundStyle(CipherColor.ink)
                        Spacer()
                        Color.clear.frame(width: 44, height: 44)
                    }
                    Text(SettingsCopy.selfieTitle).font(CipherFont.title).foregroundStyle(CipherColor.ink)
                    Text(SettingsCopy.selfieDetail).font(CipherFont.body).foregroundStyle(CipherColor.sub)
                    ForEach(settings.photos) { photo in
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Failed attempt · \(photo.date.formatted(date: .abbreviated, time: .shortened))")
                                    .font(CipherFont.button).foregroundStyle(CipherColor.ink)
                                Text("3 wrong PINs · photo saved on this iPhone")
                                    .font(CipherFont.caption).foregroundStyle(CipherColor.sub)
                            }
                            Spacer()
                            Button("Delete") { settings.deletePhoto(photo) }
                                .font(CipherFont.caption)
                                .foregroundStyle(CipherColor.danger)
                                .frame(minHeight: 44)
                        }
                    }
                    point(SettingsCopy.selfieStays)
                    point(SettingsCopy.selfieSee)
                    point(SettingsCopy.selfieOff)
                    Button(settings.breakIn ? "Turn off" : "Allow camera access") {
                        settings.setBreakIn(!settings.breakIn)
                    }
                    .buttonStyle(CipherGoldButtonStyle())
                }
                .padding(CipherSpace.s20)
            }
        }
        .onAppear { settings.reloadPhotos() }
    }

    private func point(_ text: String) -> some View {
        HStack(alignment: .top, spacing: CipherSpace.s8) {
            Image(systemName: "checkmark").foregroundStyle(CipherColor.tintInk)
            Text(text).font(CipherFont.body).foregroundStyle(CipherColor.ink)
        }
    }
}

struct AppIconScreen: View {
    @ObservedObject var settings: SettingsModel
    var onBack: () -> Void

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        CipherScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: CipherSpace.s16) {
                    HStack {
                        CipherBackButton(action: onBack)
                        Text("App icon").font(CipherFont.h2).foregroundStyle(CipherColor.ink)
                        Spacer()
                    }
                    Text("Change how CipherRoll looks on your home screen.")
                        .font(CipherFont.body).foregroundStyle(CipherColor.sub)
                    LazyVGrid(columns: columns, spacing: CipherSpace.s16) {
                        ForEach(AppIconChoice.allCases) { choice in
                            Button {
                                settings.selectIcon(choice)
                            } label: {
                                VStack {
                                    RoundedRectangle(cornerRadius: 18)
                                        .fill(color(choice))
                                        .frame(width: 72, height: 72)
                                        .overlay {
                                            if settings.icon == choice {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundStyle(CipherColor.gold)
                                                    .offset(x: 28, y: -28)
                                            }
                                        }
                                    Text(choice.title).font(CipherFont.caption).foregroundStyle(CipherColor.ink)
                                }
                            }
                            .buttonStyle(.plain)
                            .frame(minHeight: 44)
                            .accessibilityLabel(choice.title)
                        }
                    }
                    Text(SettingsCopy.iconNote)
                        .font(CipherFont.caption)
                        .foregroundStyle(CipherColor.sub)
                        .padding(CipherSpace.s16)
                        .background(CipherColor.card, in: RoundedRectangle(cornerRadius: CipherRadius.card))
                    if let message = settings.message {
                        Text(message).font(CipherFont.caption).foregroundStyle(CipherColor.sub)
                    }
                }
                .padding(CipherSpace.s20)
            }
        }
    }

    private func color(_ choice: AppIconChoice) -> Color {
        switch choice {
        case .crLock: CipherColor.hero
        case .calculator: Color(red: 0.15, green: 0.16, blue: 0.18)
        case .notes: Color(red: 0.98, green: 0.95, blue: 0.86)
        case .weather: Color(red: 0.35, green: 0.62, blue: 0.95)
        case .utility: Color(red: 0.45, green: 0.48, blue: 0.52)
        }
    }
}

struct PhotoDeniedScreen: View {
    var onBack: () -> Void
    var onChoose: () -> Void

    var body: some View {
        CipherScreen {
            ScrollView {
            VStack(alignment: .leading, spacing: CipherSpace.s16) {
                CipherBackButton(action: onBack)
                Text(SettingsCopy.photoDeniedTitle).font(CipherFont.title).foregroundStyle(CipherColor.ink)
                Text(SettingsCopy.photoDeniedDetail).font(CipherFont.body).foregroundStyle(CipherColor.sub)
                VStack(alignment: .leading, spacing: CipherSpace.s12) {
                    Text("1  Open iPhone Settings").font(CipherFont.button).foregroundStyle(CipherColor.ink)
                    Text("2  Tap Photos").font(CipherFont.button).foregroundStyle(CipherColor.ink)
                    Text("3  Choose Selected Photos (recommended)").font(CipherFont.button).foregroundStyle(CipherColor.ink)
                }
                .padding(CipherSpace.s16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(CipherColor.card, in: RoundedRectangle(cornerRadius: CipherRadius.card))
                Button("Open iPhone Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(CipherGoldButtonStyle())
                Button("Choose photos", action: onChoose)
                    .font(CipherFont.button)
                    .foregroundStyle(CipherColor.link)
                    .frame(minHeight: CipherA11y.minimumTarget)
            }
            .padding(CipherSpace.s20)
            }
        }
    }
}

struct RestoreNoneSheet: View {
    var onPlans: () -> Void
    var onRetry: () -> Void
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: CipherSpace.s16) {
            Text(SettingsCopy.restoreNoneTitle).font(CipherFont.h2).foregroundStyle(CipherColor.ink)
            Text(SettingsCopy.restoreNoneDetail)
                .font(CipherFont.body)
                .foregroundStyle(CipherColor.sub)
                .multilineTextAlignment(.center)
            Button("See plans", action: onPlans).buttonStyle(CipherGoldButtonStyle())
            Button("Try again", action: onRetry).buttonStyle(CipherOutlineButtonStyle())
            Button("Close", action: onClose)
                .font(CipherFont.button)
                .foregroundStyle(CipherColor.link)
                .frame(minHeight: 44)
        }
        .padding(CipherSpace.s24)
        .presentationDetents([.medium])
    }
}

struct LockDelaySheet: View {
    var selected: LockDelay
    var onPick: (LockDelay) -> Void
    var onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: CipherSpace.s12) {
            Text("Lock after").font(CipherFont.h2).foregroundStyle(CipherColor.ink)
            ForEach(LockDelay.allCases) { delay in
                Button {
                    onPick(delay)
                } label: {
                    HStack {
                        Text(delay.title).font(CipherFont.button).foregroundStyle(CipherColor.ink)
                        Spacer()
                        if delay == selected {
                            Image(systemName: "checkmark").foregroundStyle(CipherColor.ink)
                        }
                    }
                    .frame(minHeight: 44)
                }
            }
            Button("Close", action: onClose).frame(minHeight: 44)
            Spacer()
        }
        .padding(CipherSpace.s20)
        .presentationDetents([.medium])
    }
}

@MainActor
struct SettingsScreenshot: View {
    var name: String
    @StateObject private var settings: SettingsModel

    init(name: String) {
        self.name = name
        let defaults = UserDefaults(suiteName: "app.cipherroll.screenshots") ?? .standard
        let model = SettingsModel(gate: GatedAnalyticsClient(), defaults: defaults)
        _settings = StateObject(wrappedValue: model)
    }

    var body: some View {
        switch name {
        case "consent":
            ConsentScreen(onAllow: {}, onNotNow: {}, onPrivacy: {})
        case "privacy":
            PrivacyLockScreen(settings: settings, calculatorOn: false, onCalculator: { _ in }, onIcons: {}, onBack: {})
        case "security":
            SecurityStorageScreen(recovery: "Verified", freeSpace: "128 GB free", onBack: {}, onExport: {})
        case "decoy":
            DecoySetupScreen(
                itemCount: 43, needsPlan: true, pin: "", message: nil,
                onBack: {}, onDigit: { _ in }, onDelete: {}, onCreate: {}, onPlan: {}
            )
        case "selfie":
            SelfieScreen(settings: settings, onBack: {})
        case "appIcon":
            AppIconScreen(settings: settings, onBack: {})
        case "photoDenied":
            PhotoDeniedScreen(onBack: {}, onChoose: {})
        case "restoreNone":
            CipherScreen {
                RestoreNoneSheet(onPlans: {}, onRetry: {}, onClose: {})
            }
        default:
            SettingsHome(
                settings: settings,
                planTitle: "Free plan",
                planDetail: "43 of 100 photos · 1 vault",
                lockTitle: "PIN",
                recoveryTitle: "Verified",
                trashCount: 1,
                onUpgrade: {}, onLockType: {}, onLockAfter: {}, onPrivacy: {}, onRecovery: {},
                onSelfie: {}, onSecurity: {}, onTrash: {}, onExport: {}, onDecoy: {},
                onRestore: {}, onManage: {}, onLock: {}
            )
        }
    }
}
