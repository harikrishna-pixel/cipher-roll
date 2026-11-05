import PhotosUI
import SwiftUI
import UIKit

enum LibraryPage: Hashable {
    case kind(ItemKind)
    case albums(ItemKind)
    case album(ItemKind, String)
    case trash
    case search
    case viewer(UUID)
    case note(UUID?)
    case settings
    case privacy
    case security
    case decoy
    case selfie
    case appIcon
    case photoDenied
    case help
    case helpArticle(String)
    case moreApps
    case notifications
    case samples
    case backupExport
    case backupRestore
}

struct LibraryRoot: View {
    @ObservedObject var library: LibraryModel
    @ObservedObject var plan: PlanModel
    @ObservedObject var settings: SettingsModel
    @ObservedObject var lock: AppLockModel
    var shortcut: String
    var onLock: () -> Void
    @State private var path: [LibraryPage] = []
    @State private var showVaults = false
    @State private var showUsage = false
    @State private var showMove = false
    @State private var showDelay = false
    @State private var decoyPIN = ""
    @State private var welcome: WelcomeCard?
    @State private var showRecap = false
    @State private var showInvite = false
    @State private var showContact = false
    @State private var showBackupExport = false
    @State private var showBackupRestore = false
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var usesSidebar: Bool { CipherLayout.usesSidebar(sizeClass) }

    var body: some View {
        libraryChrome
            .modifier(PlanCover(plan: plan, regular: usesSidebar))
    }

    private var homeDashboard: some View {
        HomeDashboard(
            shortcut: shortcut,
            itemCount: library.counts.total,
            chip: chipTitle,
            chipButton: chipButton,
            counts: library.counts,
            recent: Array(library.activeItems.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }.prefix(8)),
            thumbs: library.thumbs,
            onSearch: { path.append(.search) },
            onLock: onLock,
            onChip: {
                library.trackChip()
                showUsage = true
            },
            onChipAction: {
                if plan.tier.removesLimits {
                    plan.manage()
                } else {
                    plan.present(.homeChip, itemCount: library.counts.total)
                }
            },
            onVaults: { showVaults = true },
            onKind: { path.append(.kind($0)) },
            onOpen: { path.append(page(for: $0)) },
            onAdd: { library.beginAdd() },
            onSettings: { path.append(.settings) },
            welcome: welcome
        )
        .navigationDestination(for: LibraryPage.self) { page in
            destination(page)
        }
    }

    @ViewBuilder
    private var libraryChrome: some View {
        if usesSidebar {
            NavigationSplitView {
                LibrarySidebar(
                    itemCount: library.counts.total,
                    onHome: { path = [] },
                    onKind: { path = [.kind($0)] },
                    onSettings: { path = [.settings] },
                    onHelp: { path = [.help] }
                )
            } detail: {
                libraryStack
            }
            .navigationSplitViewStyle(.balanced)
        } else if VerticalBar.isActive {
            TabView {
                libraryStack.tabItem { Label("Photos", systemImage: "photo") }
                libraryStack.tabItem { Label("Videos", systemImage: "play.rectangle") }
                libraryStack.tabItem { Label("Files", systemImage: "doc") }
                libraryStack.tabItem { Label("Notes", systemImage: "note.text") }
                libraryStack.tabItem { Label("Settings", systemImage: "slider.horizontal.3") }
            }
        } else {
            libraryStack
        }
    }

    private var libraryStack: some View {
        NavigationStack(path: $path) {
            homeDashboard
        }
        .sheet(isPresented: $showVaults) {
            VaultSwitcherSheet(onClose: { showVaults = false }, onNewVault: {
                showVaults = false
                plan.present(.secondVault)
            })
        }
        .sheet(isPresented: $showUsage) {
            UsageSheet(counts: library.counts, onManage: {
                showUsage = false
                path.append(.trash)
            }, onUpgrade: {
                showUsage = false
                plan.present(.usageSheet, itemCount: library.counts.total)
            })
        }
        .sheet(isPresented: Binding(
            get: { library.importScreen != nil },
            set: { if !$0 { library.importScreen = nil } }
        )) {
            ImportContainer(library: library)
                .cipherCenteredSheet()
        }
        .sheet(isPresented: $showMove) {
            MoveSheet(albums: library.albums(kind: .photo) + library.albums(kind: .file), onPick: { name in
                library.move(Array(library.selected), album: name)
                showMove = false
            }, onClose: { showMove = false })
        }
        .onChange(of: library.requestedPage) { page in
            if let page {
                path.append(page)
                library.requestedPage = nil
            }
        }
        .fullScreenCover(isPresented: $library.showPhotoDenied) {
            PhotoDeniedScreen(onBack: { library.showPhotoDenied = false }, onChoose: { library.showPhotoDenied = false; library.beginAdd() })
        }
        .sheet(isPresented: $plan.showRestoreNone) {
            RestoreNoneSheet(onPlans: {
                plan.showRestoreNone = false
                plan.present(.settings)
            }, onRetry: {
                plan.showRestoreNone = false
                Task { await plan.restore() }
            }, onClose: { plan.showRestoreNone = false })
                .cipherCenteredSheet()
        }
        .sheet(isPresented: $showDelay) {
            LockDelaySheet(selected: settings.lockDelay, onPick: {
                settings.setDelay($0)
                showDelay = false
            }, onClose: { showDelay = false })
        }
        .sheet(isPresented: $showBackupExport) {
            BackupExportScreen(library: library, analytics: settings.gate, onBack: { showBackupExport = false })
                .cipherCenteredSheet()
        }
        .sheet(isPresented: $showBackupRestore) {
            BackupRestoreScreen(
                library: library,
                analytics: settings.gate,
                onBack: { showBackupRestore = false },
                onOpen: {
                    showBackupRestore = false
                    onLock()
                }
            )
            .cipherCenteredSheet()
        }
        .onChange(of: library.limitHit) { kind in
            guard let kind else { return }
            library.limitHit = nil
            plan.present(PaywallTrigger.limit(kind), limitKind: kind, itemCount: library.counts.total)
        }
        .onChange(of: plan.tier) { _ in
            library.applyPlan(removesLimits: plan.tier.removesLimits)
        }
        .onAppear {
            library.applyPlan(removesLimits: plan.tier.removesLimits)
            for item in library.activeItems.prefix(12) { library.thumbnail(for: item) }
            noteReturn()
            if let kind = ShareLimitHandoff.consume() {
                plan.present(PaywallTrigger.limit(kind), limitKind: kind, itemCount: library.counts.total)
            }
        }
        .onChange(of: library.importScreen) { screen in
            guard case .done(let count, _) = screen, count > 0 else { return }
            let added = AppGroupDefaults.suite.integer(forKey: RetentionKeys.addedThisWeek) + count
            AppGroupDefaults.suite.set(added, forKey: RetentionKeys.addedThisWeek)
            library.toast = CipherToast(kind: .success, title: "\(count) items imported safely", action: "View")
            if !AppGroupDefaults.suite.bool(forKey: RetentionKeys.notificationAsked) {
                path.append(.notifications)
            } else {
                ReviewRequester.request(moment: "import_done", analytics: settings.gate)
            }
        }
        .sheet(isPresented: $showRecap) {
            WeeklyRecapSheet(
                added: AppGroupDefaults.suite.integer(forKey: RetentionKeys.addedThisWeek),
                blocked: AppGroupDefaults.suite.integer(forKey: RetentionKeys.wrongAttempts),
                planLine: plan.tier == .free ? "You are on the Free plan." : "You are on Pro.",
                onDone: {
                    AppGroupDefaults.suite.set(Date(), forKey: RetentionKeys.lastRecap)
                    settings.gate.track("recap_dismissed", properties: [:])
                    showRecap = false
                    ReviewRequester.request(moment: "weekly_recap", analytics: settings.gate)
                },
                onUsage: {
                    showRecap = false
                    showUsage = true
                }
            )
        }
        .sheet(isPresented: $showInvite) {
            InviteFriendSheet(
                email: AppGroupDefaults.suite.string(forKey: RetentionKeys.inviteEmail) ?? "",
                code: inviteCode(),
                onShare: { message in
                    settings.gate.track("invite_link_shared", properties: [:])
                    SharePresenter.share(items: [SharePayload(data: Data(message.utf8), name: "Invite.txt")])
                },
                onClose: { showInvite = false },
                onOpened: { settings.gate.track("invite_entry_opened", properties: [:]) }
            )
        }
        .sheet(isPresented: $showContact) {
            ContactSupportSheet(onClose: { showContact = false })
        }
        .safeAreaInset(edge: .bottom) {
            if let toast = library.toast {
                ToastBanner(toast: toast) {
                    if toast.kind == .undo { library.undoLastTrash() }
                    library.toast = nil
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(ToastRules.seconds)) {
                        if library.toast?.id == toast.id { library.toast = nil }
                    }
                }
            }
        }
    }

    private func noteReturn() {
        let defaults = AppGroupDefaults.suite
        let now = Date()
        _ = RetentionSession.begin(defaults: defaults)
        let last = defaults.object(forKey: RetentionKeys.lastOpen) as? Date
        let shown = defaults.string(forKey: RetentionKeys.welcomeShownDay) ?? ""
        if let variant = WelcomeRules.variant(lastOpen: last, now: now, alreadyShownDay: shown) {
            let hour = Calendar.current.component(.hour, from: now)
            welcome = WelcomeCopy.card(
                variant: variant,
                itemCount: library.counts.total,
                added: defaults.integer(forKey: RetentionKeys.addedThisWeek),
                hour: hour
            )
            defaults.set(WelcomeRules.dayKey(now), forKey: RetentionKeys.welcomeShownDay)
            settings.gate.track("welcome_back_shown", properties: ["variant": variant.rawValue, "action": "shown"])
        }
        if defaults.object(forKey: RetentionKeys.lastRecap) == nil {
            defaults.set(now, forKey: RetentionKeys.lastRecap)
        } else if RecapRules.shouldShow(last: defaults.object(forKey: RetentionKeys.lastRecap) as? Date, now: now, itemCount: library.counts.total) {
            showRecap = true
            settings.gate.track("recap_shown", properties: [:])
        }
        defaults.set(now, forKey: RetentionKeys.lastOpen)
    }

    private func inviteCode() -> String {
        let defaults = AppGroupDefaults.suite
        let existing = defaults.string(forKey: RetentionKeys.inviteCode)
        let code = ReferralRules.code(stored: existing)
        if existing == nil { defaults.set(code, forKey: RetentionKeys.inviteCode) }
        return code
    }

    private var chipTitle: String {
        if plan.tier == .free {
            let nearest = FreePlanChip.nearest(library.counts)
            return FreePlanChip.title(kind: nearest.kind, used: nearest.used, limit: nearest.limit)
        }
        return PaywallCopy.chip(tier: plan.tier).title
    }

    private var chipButton: String {
        PaywallCopy.chip(tier: plan.tier).button
    }

    private func page(for item: LibraryItem) -> LibraryPage {
        item.kind == .note ? .note(item.id) : .viewer(item.id)
    }

    @ViewBuilder
    private func destination(_ page: LibraryPage) -> some View {
        switch page {
        case .kind(let kind):
            ItemGridView(library: library, kind: kind, album: nil, path: $path, onMove: { showMove = true })
        case .albums(let kind):
            AlbumGridView(library: library, kind: kind, path: $path)
        case .album(let kind, let name):
            ItemGridView(library: library, kind: kind, album: name, path: $path, onMove: { showMove = true })
        case .trash:
            TrashView(library: library)
        case .search:
            SearchView(library: library, path: $path)
        case .viewer(let id):
            ItemViewer(library: library, id: id)
        case .note(let id):
            NoteEditor(library: library, id: id)
        case .settings:
            settingsHome
        case .privacy:
            PrivacyLockScreen(
                settings: settings,
                calculatorOn: lock.lockKind == .calculator,
                onCalculator: { on in
                    if on, lock.lockKind == .pin {
                        lock.setLockKind(.calculator)
                    } else if !on, lock.lockKind == .calculator {
                        lock.setLockKind(.pin)
                    }
                },
                onIcons: { path.append(.appIcon) },
                onBack: { path.removeLast() }
            )
        case .security:
            SecurityStorageScreen(
                recovery: "Verified",
                freeSpace: StorageRoom.freeSpaceLabel(),
                onBack: { path.removeLast() },
                onExport: { exportAll() },
                onBackup: { openBackupExport() },
                onRestoreBackup: { openBackupRestore() }
            )
        case .decoy:
            DecoySetupScreen(
                itemCount: library.counts.total,
                needsPlan: !plan.tier.removesLimits,
                pin: decoyPIN,
                message: lock.message,
                onBack: { path.removeLast() },
                onDigit: { if decoyPIN.count < 12 { decoyPIN.append($0) } },
                onDelete: { if !decoyPIN.isEmpty { decoyPIN.removeLast() } },
                onCreate: {
                    lock.createDecoy(pin: decoyPIN) { ok in
                        if ok {
                            decoyPIN = ""
                            path.removeLast()
                        }
                    }
                },
                onPlan: { plan.present(.decoyVault) }
            )
        case .selfie:
            SelfieScreen(settings: settings, onBack: { path.removeLast() })
        case .appIcon:
            AppIconScreen(settings: settings, onBack: { path.removeLast() })
        case .photoDenied:
            PhotoDeniedScreen(onBack: { path.removeLast() }, onChoose: { path.removeLast(); library.beginAdd() })
        case .help:
            HelpListScreen(
                onBack: { path.removeLast() },
                onOpen: { article in
                    settings.gate.track("help_article_opened", properties: ["slug": article.slug])
                    path.append(.helpArticle(article.slug))
                },
                onContact: {
                    settings.gate.track("support_contacted", properties: [:])
                    showContact = true
                }
            )
        case .helpArticle(let slug):
            if let article = HelpCatalog.articles.first(where: { $0.slug == slug }) {
                HelpArticleScreen(article: article, onBack: { path.removeLast() })
            }
        case .moreApps:
            MoreAppsScreen(
                onBack: { path.removeLast() },
                onOpen: { settings.gate.track("more_apps_opened", properties: [:]) },
                onTap: { app in
                    settings.gate.track("more_apps_tapped", properties: ["app": app.rawValue])
                    UIApplication.shared.open(app.searchURL)
                }
            )
        case .notifications:
            NotificationPrimerScreen(
                onAllow: {
                    AppGroupDefaults.suite.set(true, forKey: RetentionKeys.notificationAsked)
                    settings.gate.track("notification_prompt_shown", properties: [:])
                    QuietNotifications.ask(analytics: settings.gate)
                    path.removeLast()
                },
                onNotNow: {
                    AppGroupDefaults.suite.set(true, forKey: RetentionKeys.notificationAsked)
                    path.removeLast()
                },
                onSamples: { path.append(.samples) }
            )
        case .samples:
            NotificationSamplesScreen(onBack: { path.removeLast() })
        case .backupExport:
            BackupExportScreen(library: library, analytics: settings.gate, onBack: { path.removeLast() })
        case .backupRestore:
            BackupRestoreScreen(library: library, analytics: settings.gate, onBack: { path.removeLast() }, onOpen: onLock)
        }
    }

    private var settingsHome: some View {
        let nearest = FreePlanChip.nearest(library.counts)
        return SettingsHome(
            settings: settings,
            planTitle: plan.tier == .free ? "Free plan" : PaywallCopy.chip(tier: plan.tier).title,
            planDetail: plan.tier == .free
                ? "\(nearest.used) of \(nearest.limit) \(FreePlanChip.label(nearest.kind)) · 1 vault"
                : "Limits removed · 1 vault",
            lockTitle: lock.lockKind.backupTitle,
            recoveryTitle: "Verified",
            trashCount: library.trashedItems.count,
            onUpgrade: { plan.present(.settings, itemCount: library.counts.total) },
            onLockType: { path.append(.privacy) },
            onLockAfter: { showDelay = true },
            onPrivacy: { path.append(.privacy) },
            onRecovery: {
                settings.message = "Your recovery key was saved when the vault was created. It covers the real vault only."
            },
            onSelfie: { path.append(.selfie) },
            onSecurity: {
                settings.gate.track("backup_status_viewed", properties: ["status": "not_backed_up"])
                path.append(.security)
            },
            onTrash: { path.append(.trash) },
            onExport: { exportAll() },
            onDecoy: { path.append(.decoy) },
            onRestore: { Task { await plan.restore() } },
            onManage: { plan.manage() },
            onLock: onLock,
            onHelp: { path.append(.help) },
            onInvite: { showInvite = true },
            onMoreApps: { path.append(.moreApps) },
            onFeedback: {
                settings.gate.track("feedback_opened", properties: [:])
                showContact = true
            },
            onBackupExport: { openBackupExport() },
            onBackupRestore: { openBackupRestore() }
        )
    }

    private func openBackupExport() {
        if usesSidebar {
            showBackupExport = true
        } else {
            path.append(.backupExport)
        }
    }

    private func openBackupRestore() {
        if usesSidebar {
            showBackupRestore = true
        } else {
            path.append(.backupRestore)
        }
    }

    private func exportAll() {
        let payloads = library.activeItems.compactMap { item -> SharePayload? in
            guard let data = library.read(item.id) else { return nil }
            return SharePayload(data: data, name: item.displayName)
        }
        SharePresenter.share(items: payloads)
    }
}

private struct PlanCover: ViewModifier {
    @ObservedObject var plan: PlanModel
    var regular: Bool

    func body(content: Content) -> some View {
        if regular {
            content
                .sheet(item: $plan.paywall) { request in
                    PaywallScreen(plan: plan, request: request)
                        .cipherCenteredSheet()
                }
                .sheet(isPresented: $plan.showTrialEnded) {
                    TrialEndedScreen(plan: plan)
                        .cipherCenteredSheet()
                }
        } else {
            content
                .fullScreenCover(item: $plan.paywall) { request in
                    PaywallScreen(plan: plan, request: request)
                }
                .fullScreenCover(isPresented: $plan.showTrialEnded) {
                    TrialEndedScreen(plan: plan)
                }
        }
    }
}

enum SidebarPick: Hashable {
    case home
    case kind(ItemKind)
    case settings
    case help
}

struct LibrarySidebar: View {
    var itemCount: Int
    var onHome: () -> Void
    var onKind: (ItemKind) -> Void
    var onSettings: () -> Void
    var onHelp: () -> Void
    @State private var selection: SidebarPick = .home

    private let kinds: [ItemKind] = [.photo, .video, .file, .note]

    var body: some View {
        VStack(alignment: .leading, spacing: CipherSpace.s12) {
            Text("CipherRoll").font(CipherFont.h2).foregroundStyle(CipherColor.ink)
                .padding(.bottom, CipherSpace.s8)
            Text("VAULTS").font(CipherFont.caption).foregroundStyle(CipherColor.sub)
            row("Personal", ItemCountCopy.label(itemCount), "lock", selection == .home) {
                selection = .home
                onHome()
            }
            Text("LIBRARY").font(CipherFont.caption).foregroundStyle(CipherColor.sub)
                .padding(.top, CipherSpace.s8)
            ForEach(kinds, id: \.self) { kind in
                row(kindTitle(kind), nil, symbol(kind), selection == .kind(kind)) {
                    selection = .kind(kind)
                    onKind(kind)
                }
            }
            Spacer()
            row("Settings", nil, "slider.horizontal.3", selection == .settings) {
                selection = .settings
                onSettings()
            }
            row("Help and FAQ", nil, "questionmark.circle", selection == .help) {
                selection = .help
                onHelp()
            }
        }
        .padding(CipherSpace.s16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(CipherColor.card)
        .navigationSplitViewColumnWidth(min: 220, ideal: 280, max: 320)
    }

    private func symbol(_ kind: ItemKind) -> String {
        switch kind {
        case .photo: "photo"
        case .video: "play.rectangle"
        case .file: "doc"
        case .note: "note.text"
        }
    }

    private func row(_ title: String, _ detail: String?, _ symbol: String, _ selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: CipherSpace.s12) {
                Image(systemName: symbol)
                    .frame(width: 28, height: 28)
                    .foregroundStyle(selected ? CipherColor.tintInk : CipherColor.ink)
                    .background(selected ? CipherColor.tint : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 0) {
                    Text(title).font(CipherFont.button).foregroundStyle(CipherColor.ink)
                    if let detail {
                        Text(detail).font(CipherFont.caption).foregroundStyle(CipherColor.sub)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, CipherSpace.s8)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(selected ? CipherColor.tint : Color.clear, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct HomeDashboard: View {
    var shortcut: String
    var itemCount: Int
    var chip: String
    var chipButton: String
    var counts: UsageCounts
    var recent: [LibraryItem]
    var thumbs: [UUID: UIImage]
    var onSearch: () -> Void
    var onLock: () -> Void
    var onChip: () -> Void
    var onChipAction: () -> Void
    var onVaults: () -> Void
    var onKind: (ItemKind) -> Void
    var onOpen: (LibraryItem) -> Void
    var onAdd: () -> Void
    var onSettings: () -> Void
    var welcome: WelcomeCard? = nil
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var regular: Bool { CipherLayout.usesSidebar(sizeClass) }

    var body: some View {
        CipherScreen(width: .stage) {
            if regular {
                regularBody
            } else {
                phoneBody
            }
        }
    }

    private var phoneBody: some View {
        VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: CipherSpace.s16) {
                        header
                        hero
                        if let welcome { leftOff(welcome) }
                        chipRow
                        Button(action: onVaults) {
                            HStack(spacing: CipherSpace.s8) {
                                Text("Personal").font(CipherFont.h2).foregroundStyle(CipherColor.ink)
                                Image(systemName: "chevron.down").font(.system(size: 12, weight: .bold)).foregroundStyle(CipherColor.sub)
                            }
                        }
                        .accessibilityLabel("Vaults")
                        if itemCount > 0 { categoryGrid }
                        if itemCount == 0 {
                            empty
                        } else {
                            recentRow
                        }
                    }
                    .padding(CipherSpace.s20)
                    .padding(.bottom, 88)
                }
                tabBar
        }
    }

    private var header: some View {
        HStack {
            CipherIcon.lock.image
                .foregroundStyle(CipherColor.gold)
                .frame(width: 36, height: 36)
                .background(CipherColor.hero, in: RoundedRectangle(cornerRadius: 10))
            Text("CipherRoll").font(CipherFont.h2).foregroundStyle(CipherColor.ink)
            Spacer()
            iconButton("magnifyingglass", "Search", onSearch)
            iconButton("lock", "Lock", onLock)
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: CipherSpace.s8) {
            Text(welcome?.eyebrow ?? "Unlocks with \(shortcut)")
                .font(CipherFont.caption)
                .foregroundStyle(Color.white.opacity(0.75))
            Text(welcome?.title ?? ItemCountCopy.label(itemCount))
                .font(CipherFont.title)
                .foregroundStyle(.white)
            if let welcome {
                HStack {
                    chip(welcome.kept)
                    chip(WelcomeCopy.uploaded)
                }
            } else {
                Text("Stored on this iPhone")
                    .font(CipherFont.caption)
                    .foregroundStyle(Color.white.opacity(0.75))
            }
        }
        .padding(CipherSpace.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CipherColor.hero, in: RoundedRectangle(cornerRadius: CipherRadius.card))
    }

    private func chip(_ title: String) -> some View {
        Text(title)
            .font(CipherFont.caption)
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .frame(minHeight: 28)
            .background(Color.white.opacity(0.12), in: Capsule())
    }

    private func leftOff(_ card: WelcomeCard) -> some View {
        VStack(alignment: .leading, spacing: CipherSpace.s8) {
            Text("WHERE YOU LEFT OFF").font(CipherFont.caption).foregroundStyle(CipherColor.sub)
            Text(card.leftTitle).font(CipherFont.button).foregroundStyle(CipherColor.ink)
            Text(card.leftDetail).font(CipherFont.caption).foregroundStyle(CipherColor.sub)
            Button(card.action, action: onAdd).buttonStyle(CipherGoldButtonStyle())
        }
        .padding(CipherSpace.s16)
        .background(CipherColor.card, in: RoundedRectangle(cornerRadius: CipherRadius.card))
    }

    private var chipRow: some View {
        HStack {
            Button(action: onChip) {
                Text(chip).font(CipherFont.caption).foregroundStyle(CipherColor.ink)
            }
            .frame(minHeight: 44)
            Spacer()
            Button(chipButton, action: onChipAction)
                .font(CipherFont.button)
                .foregroundStyle(CipherColor.link)
                .frame(minHeight: 44)
        }
        .padding(.horizontal, CipherSpace.s16)
        .background(CipherColor.card, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(CipherColor.line, lineWidth: 1))
    }

    private var categoryGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: CipherSpace.s12) {
            category(.photo, "Photos", counts.photos, CipherIcon.image.image)
            category(.video, "Videos", counts.videos, CipherIcon.video.image)
            category(.file, "Files", counts.files, CipherIcon.file.image)
            category(.note, "Notes", counts.notes, CipherIcon.note.image)
        }
    }

    private func category(_ kind: ItemKind, _ title: String, _ count: Int, _ icon: Image) -> some View {
        Button { onKind(kind) } label: {
            HStack(spacing: CipherSpace.s12) {
                icon.foregroundStyle(CipherColor.tintInk)
                    .frame(width: 36, height: 36)
                    .background(CipherColor.tint, in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(CipherFont.button).foregroundStyle(CipherColor.ink)
                    Text(ItemCountCopy.label(count)).font(CipherFont.caption).foregroundStyle(CipherColor.sub)
                }
                Spacer()
            }
            .padding(CipherSpace.s12)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .background(CipherColor.card, in: RoundedRectangle(cornerRadius: CipherRadius.card))
        }
        .buttonStyle(.plain)
    }

    private func stageCategory(_ kind: ItemKind, _ title: String, _ count: Int, _ icon: Image) -> some View {
        Button { onKind(kind) } label: {
            VStack(alignment: .leading, spacing: CipherSpace.s8) {
                icon.foregroundStyle(CipherColor.tintInk)
                    .frame(width: 36, height: 36)
                    .background(CipherColor.tint, in: RoundedRectangle(cornerRadius: 10))
                Text(title).font(CipherFont.button).foregroundStyle(CipherColor.ink).lineLimit(1)
                Text(ItemCountCopy.label(count)).font(CipherFont.caption).foregroundStyle(CipherColor.sub).lineLimit(1)
            }
            .padding(CipherSpace.s12)
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
            .background(CipherColor.card, in: RoundedRectangle(cornerRadius: CipherRadius.card))
        }
        .buttonStyle(.plain)
    }

    private var recentRow: some View {
        VStack(alignment: .leading, spacing: CipherSpace.s12) {
            HStack {
                Text("Recent").font(CipherFont.h2).foregroundStyle(CipherColor.ink)
                Spacer()
                Button("See all") { onKind(.photo) }
                    .font(CipherFont.button)
                    .foregroundStyle(CipherColor.link)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: CipherSpace.s8) {
                    ForEach(recent) { item in
                        Button { onOpen(item) } label: {
                            thumb(item).frame(width: 84, height: 84).clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .accessibilityLabel(item.displayName)
                    }
                }
            }
        }
    }

    private var empty: some View {
        VStack(spacing: CipherSpace.s12) {
            CipherIcon.image.image
                .foregroundStyle(CipherColor.tintInk)
                .frame(width: 56, height: 56)
                .background(CipherColor.tint, in: RoundedRectangle(cornerRadius: 16))
            Text("Add your first private photo")
                .font(CipherFont.h2)
                .foregroundStyle(CipherColor.ink)
                .multilineTextAlignment(.center)
            Text("Pick it from your camera roll. It is locked the moment it is imported.")
                .font(CipherFont.body)
                .foregroundStyle(CipherColor.sub)
                .multilineTextAlignment(.center)
            Button("Choose photos", action: onAdd)
                .buttonStyle(CipherGoldButtonStyle())
                .frame(maxWidth: 240)
            Button("Add a file or note instead", action: onAdd)
                .font(CipherFont.button)
                .foregroundStyle(CipherColor.link)
                .frame(minHeight: 44)
        }
        .padding(CipherSpace.s20)
        .frame(maxWidth: .infinity)
        .overlay(RoundedRectangle(cornerRadius: CipherRadius.card).stroke(CipherColor.line, style: StrokeStyle(lineWidth: 1, dash: [6])))
    }

    private var tabBar: some View {
        HStack {
            tab("Vault", "lock", onLock)
            Button(action: onAdd) {
                Text("+ Add")
                    .font(CipherFont.button)
                    .foregroundStyle(CipherColor.onGold)
                    .frame(minWidth: 140, minHeight: 52)
                    .background(CipherColor.gold, in: Capsule())
            }
            .accessibilityLabel("Add")
            tab("Settings", "slider.horizontal.3", onSettings)
        }
        .padding(.horizontal, CipherSpace.s20)
        .padding(.vertical, CipherSpace.s12)
        .background(CipherColor.bg)
    }

    private var regularBody: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: CipherSpace.s16) {
                    VStack(alignment: .leading, spacing: CipherSpace.s8) {
                        HStack(alignment: .center, spacing: CipherSpace.s12) {
                            Text("Personal").font(CipherFont.title).foregroundStyle(CipherColor.ink)
                            Spacer()
                            Button(action: onChip) {
                                Text(chip)
                                    .font(CipherFont.caption)
                                    .foregroundStyle(CipherColor.ink)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 12)
                                    .frame(minHeight: 36)
                                    .background(CipherColor.card, in: Capsule())
                            }
                            iconButton("magnifyingglass", "Search", onSearch)
                            iconButton("lock", "Lock", onLock)
                        }
                        Text("\(ItemCountCopy.label(itemCount)) kept safe on this iPhone")
                            .font(CipherFont.caption)
                            .foregroundStyle(CipherColor.sub)
                    }
                    if let welcome { leftOff(welcome) }
                    if itemCount > 0 {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: CipherSpace.s12), count: 4), spacing: CipherSpace.s12) {
                            stageCategory(.photo, "Photos", counts.photos, CipherIcon.image.image)
                            stageCategory(.video, "Videos", counts.videos, CipherIcon.video.image)
                            stageCategory(.file, "Files", counts.files, CipherIcon.file.image)
                            stageCategory(.note, "Notes", counts.notes, CipherIcon.note.image)
                        }
                        recentGrid
                    } else {
                        empty
                    }
                }
                .padding(CipherSpace.s20)
                .padding(.bottom, 80)
            }
            Button(action: onAdd) {
                Text("+ Add")
                    .font(CipherFont.button)
                    .foregroundStyle(CipherColor.onGold)
                    .padding(.horizontal, 22)
                    .frame(minHeight: 52)
                    .background(CipherColor.gold, in: Capsule())
            }
            .accessibilityLabel("Add")
            .padding(CipherSpace.s20)
        }
    }

    private var recentGrid: some View {
        VStack(alignment: .leading, spacing: CipherSpace.s12) {
            Text("Recently added").font(CipherFont.h2).foregroundStyle(CipherColor.ink)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: CipherSpace.s12)], spacing: CipherSpace.s12) {
                ForEach(recent) { item in
                    Button { onOpen(item) } label: {
                        thumb(item)
                            .frame(minHeight: 140)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .accessibilityLabel(item.displayName)
                }
            }
        }
    }

    private func tab(_ title: String, _ symbol: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 18, weight: .semibold))
                Text(title).font(CipherFont.caption)
            }
            .foregroundStyle(CipherColor.ink)
            .frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    private func iconButton(_ symbol: String, _ label: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(CipherColor.ink)
                .frame(width: 44, height: 44)
                .background(CipherColor.card, in: Circle())
        }
        .accessibilityLabel(label)
    }

    @ViewBuilder
    private func thumb(_ item: LibraryItem) -> some View {
        if let image = thumbs[item.id] {
            Image(uiImage: image).resizable().scaledToFill()
        } else {
            CipherColor.tint.overlay {
                kindIcon(item.kind).foregroundStyle(CipherColor.tintInk)
            }
        }
    }
}

struct UsageSheet: View {
    var counts: UsageCounts
    var onManage: () -> Void
    var onUpgrade: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: CipherSpace.s16) {
            HStack(spacing: CipherSpace.s12) {
                Text("\(ringPercent)%")
                    .font(CipherFont.caption)
                    .foregroundStyle(CipherColor.ink)
                    .frame(width: 54, height: 54)
                    .background(Circle().stroke(CipherColor.line, lineWidth: 6))
                    .overlay(Circle().trim(from: 0, to: CGFloat(ringPercent) / 100).stroke(CipherColor.hero, lineWidth: 6).rotationEffect(.degrees(-90)))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Free plan usage").font(CipherFont.h2).foregroundStyle(CipherColor.ink)
                    Text(ringPercent < 80 ? "Plenty of space left." : "One limit is getting close.")
                        .font(CipherFont.caption).foregroundStyle(CipherColor.sub)
                }
            }
            bar("Photos", counts.photos, 100)
            bar("Videos", counts.videos, 10)
            bar("Files", counts.files, 10)
            bar("Notes", counts.notes, 10)
            Text("A plan removes CipherRoll limits. Your iPhone storage still applies.")
                .font(CipherFont.caption)
                .foregroundStyle(CipherColor.sub)
            HStack(spacing: CipherSpace.s12) {
                Button("Manage items", action: onManage).buttonStyle(CipherOutlineButtonStyle())
                Button("Upgrade", action: onUpgrade).buttonStyle(CipherGoldButtonStyle())
            }
        }
        .padding(CipherSpace.s20)
        .presentationDetents([.medium])
    }

    private var ringPercent: Int {
        let parts = [
            Double(counts.photos) / 100,
            Double(counts.videos) / 10,
            Double(counts.files) / 10,
            Double(counts.notes) / 10
        ]
        return Int((parts.max() ?? 0) * 100)
    }

    private func bar(_ title: String, _ used: Int, _ limit: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(CipherFont.button).foregroundStyle(CipherColor.ink)
                Spacer()
                Text("\(used) of \(limit)").font(CipherFont.caption).foregroundStyle(CipherColor.sub)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(CipherColor.line)
                    Capsule().fill(CipherColor.hero).frame(width: proxy.size.width * CGFloat(used) / CGFloat(max(limit, 1)))
                }
            }
            .frame(height: 6)
        }
    }
}

struct VaultSwitcherSheet: View {
    var onClose: () -> Void
    var onNewVault: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: CipherSpace.s16) {
            Text("Vaults").font(CipherFont.h2).foregroundStyle(CipherColor.ink)
            HStack {
                CipherIcon.lock.image.foregroundStyle(CipherColor.tintInk)
                    .frame(width: 40, height: 40)
                    .background(CipherColor.tint, in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading) {
                    Text("Personal").font(CipherFont.button).foregroundStyle(CipherColor.ink)
                    Text("Unlocked · Free plan").font(CipherFont.caption).foregroundStyle(CipherColor.sub)
                }
                Spacer()
                Image(systemName: "checkmark").foregroundStyle(CipherColor.ink)
            }
            .padding(CipherSpace.s12)
            .overlay(RoundedRectangle(cornerRadius: CipherRadius.card).stroke(CipherColor.ink, lineWidth: 1.5))
            Button(action: onNewVault) {
                HStack {
                    Image(systemName: "plus")
                        .frame(width: 40, height: 40)
                        .background(CipherColor.tint, in: RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading) {
                        Text("New vault").font(CipherFont.button).foregroundStyle(CipherColor.ink)
                        Text("Its own lock and its own items").font(CipherFont.caption).foregroundStyle(CipherColor.sub)
                    }
                    Spacer()
                    Text("Pro")
                        .font(CipherFont.caption)
                        .foregroundStyle(CipherColor.onGold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(CipherColor.gold, in: Capsule())
                }
                .padding(CipherSpace.s12)
                .background(CipherColor.card, in: RoundedRectangle(cornerRadius: CipherRadius.card))
            }
            .buttonStyle(.plain)
            .accessibilityHint("A second vault needs a plan")
            Spacer()
        }
        .padding(CipherSpace.s20)
        .presentationDetents([.medium])
    }
}

struct SettingsStub: View {
    var onLock: () -> Void
    var onTrash: () -> Void
    var onRestore: () -> Void = {}
    var onManage: () -> Void = {}

    var body: some View {
        CipherScreen {
            VStack(alignment: .leading, spacing: CipherSpace.s16) {
                Text("Settings").font(CipherFont.title).foregroundStyle(CipherColor.ink)
                Button("Lock", action: onLock).buttonStyle(CipherGoldButtonStyle())
                Button("Restore purchases", action: onRestore)
                    .font(CipherFont.button)
                    .foregroundStyle(CipherColor.ink)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                Button("Manage subscription", action: onManage)
                    .font(CipherFont.button)
                    .foregroundStyle(CipherColor.ink)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                Button("Recently Deleted", action: onTrash)
                    .font(CipherFont.button)
                    .foregroundStyle(CipherColor.link)
                    .frame(minHeight: 44)
                Text("Privacy, backup, and the app icon are in a later pass.")
                    .font(CipherFont.caption)
                    .foregroundStyle(CipherColor.sub)
                Spacer()
            }
            .padding(CipherSpace.s20)
        }
    }
}

extension ImportScreen: Identifiable {
    var id: String {
        switch self {
        case .add: "add"
        case .overLimit: "over"
        case .progress: "progress"
        case .paused: "paused"
        case .done: "done"
        }
    }
}
