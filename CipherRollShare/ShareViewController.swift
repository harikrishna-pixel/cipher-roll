import SwiftUI
import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private let analytics = GatedAnalyticsClient()
    private var host: UIHostingController<ShareSaveView>?
    private var files: [(url: URL, kind: ItemKind, name: String)] = []
    private var session: UnlockedSession?
    private var saved = false
    private var limitMessage: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        analytics.allowed = AppGroupDefaults.suite.string(forKey: SettingsKeys.consent) == ConsentChoice.allowed.rawValue
        analytics.track("share_ext_opened", properties: ["source_app_type": "share"])
        view.backgroundColor = .clear
        loadAttachments()
    }

    private func loadAttachments() {
        let providers = extensionContext?.inputItems
            .compactMap { $0 as? NSExtensionItem }
            .flatMap { $0.attachments ?? [] } ?? []
        let group = DispatchGroup()
        let lock = NSLock()
        for provider in providers {
            group.enter()
            let type = provider.registeredTypeIdentifiers.first ?? "public.data"
            let kind = ShareRules.kind(for: type)
            if kind == .note, provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) { item, _ in
                    defer { group.leave() }
                    let text = (item as? String) ?? ""
                    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".txt")
                    try? Data(text.utf8).write(to: url)
                    lock.lock()
                    self.files.append((url, .note, "Note"))
                    lock.unlock()
                }
            } else {
                provider.loadFileRepresentation(forTypeIdentifier: type) { url, _ in
                    defer { group.leave() }
                    guard let url else { return }
                    let copy = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "-" + url.lastPathComponent)
                    try? FileManager.default.copyItem(at: url, to: copy)
                    lock.lock()
                    self.files.append((copy, kind, url.lastPathComponent))
                    lock.unlock()
                }
            }
        }
        group.notify(queue: .main) { [weak self] in
            self?.showLock()
        }
    }

    private func showLock() {
        let lock = ShareLockView(onCancel: { [weak self] in
            self?.finish(cancelled: true)
        }, onUnlock: { [weak self] pin in
            self?.unlock(pin)
        })
        let host = UIHostingController(rootView: lock)
        host.view.backgroundColor = .clear
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
        self.host = nil
    }

    private func unlock(_ pin: String) {
        let vault = VaultServiceFactory.makeForApp()
        guard let active = try? vault.realVaultID() else {
            limitMessage = "Open CipherRoll and create a vault first."
            showSheet(saved: false)
            return
        }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let opened = try? vault.unlock(activeVault: active, secret: .pin(pin))
            DispatchQueue.main.async {
                guard let self else { return }
                if let opened {
                    self.session = opened
                    self.analytics.track("share_ext_unlocked", properties: [:])
                    self.prepareLimit(opened)
                    self.showSheet(saved: false)
                } else {
                    self.limitMessage = "That PIN did not open the vault."
                    self.showSheet(saved: false)
                }
            }
        }
    }

    private func prepareLimit(_ opened: UnlockedSession) {
        guard let items = try? opened.libraryItems() else { return }
        let counts = UsageCounts.tally(items)
        let tier = AppGroupDefaults.suite.string(forKey: "app.cipherroll.plan.tier") ?? "free"
        let kind = files.first?.kind ?? .file
        let used = counts[kind]
        if tier == "free", used + files.count > ItemKindLimit.cap(kind) {
            limitMessage = ShareRules.limitMessage(kind: kind)
            ShareLimitHandoff.record(kind)
            analytics.track("share_ext_limit_hit", properties: ["type": kind.rawValue])
        }
    }

    private func showSheet(saved: Bool) {
        self.saved = saved
        let kind = files.first?.kind ?? .photo
        let view = ShareSaveView(
            unlockedWith: "Unlocked with PIN",
            count: max(files.count, saved ? files.count : files.count),
            kind: kind,
            vaultTitle: "Personal",
            previews: [CipherColor.tint, CipherColor.gold, CipherColor.hero],
            saved: saved,
            limitMessage: saved ? nil : limitMessage,
            onCancel: { [weak self] in self?.finish(cancelled: true) },
            onSave: { [weak self] in self?.save() },
            onOpen: { [weak self] in self?.openApp() },
            onDone: { [weak self] in self?.finish(cancelled: false) }
        )
        children.forEach { child in
            child.willMove(toParent: nil)
            child.view.removeFromSuperview()
            child.removeFromParent()
        }
        let controller = UIHostingController(rootView: view)
        controller.view.backgroundColor = .clear
        addChild(controller)
        controller.view.frame = self.view.bounds
        controller.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.view.addSubview(controller.view)
        controller.didMove(toParent: self)
        host = controller
    }

    private func save() {
        guard limitMessage == nil, let session else { return }
        let batch = files
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var savedCount = 0
            for file in batch {
                if (try? session.addItem(from: file.url, kind: file.kind, displayName: file.name)) != nil {
                    savedCount += 1
                }
                try? FileManager.default.removeItem(at: file.url)
            }
            DispatchQueue.main.async {
                guard let self else { return }
                let kind = batch.first?.kind ?? .file
                self.analytics.track("share_ext_saved", properties: [
                    "type": kind.rawValue,
                    "item_count_bucket": CountBucket.label(savedCount)
                ])
                self.showSheet(saved: true)
            }
        }
    }

    private func openApp() {
        if let url = URL(string: "cipherroll://home") {
            extensionContext?.open(url, completionHandler: nil)
        }
        finish(cancelled: false)
    }

    private func finish(cancelled: Bool) {
        if cancelled {
            analytics.track("share_ext_cancelled", properties: [:])
            extensionContext?.cancelRequest(withError: NSError(domain: "app.cipherroll.share", code: 0))
        } else {
            extensionContext?.completeRequest(returningItems: nil)
        }
    }
}

private struct ShareLockView: View {
    var onCancel: () -> Void
    var onUnlock: (String) -> Void
    @State private var pin = ""

    var body: some View {
        ScrollView {
        VStack(spacing: CipherSpace.s16) {
            Text("Unlock to save")
                .font(CipherFont.title)
                .foregroundStyle(CipherColor.ink)
            Text("At least 6 digits. The original stays in the other app.")
                .font(CipherFont.caption)
                .foregroundStyle(CipherColor.sub)
                .multilineTextAlignment(.center)
            HStack(spacing: 8) {
                ForEach(0..<max(pin.count, 6), id: \.self) { index in
                    Circle().fill(index < pin.count ? CipherColor.ink : CipherColor.line).frame(width: 12, height: 12)
                }
            }
            .accessibilityLabel("\(pin.count) digits")
            let rows = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], ["", "0", "del"]]
            VStack(spacing: 8) {
                ForEach(rows, id: \.self) { row in
                    HStack(spacing: 8) {
                        ForEach(row, id: \.self) { key in
                            Button(key == "del" ? "Delete" : key) {
                                if key == "del" {
                                    if !pin.isEmpty { pin.removeLast() }
                                } else if !key.isEmpty, pin.count < 12 {
                                    pin.append(key)
                                }
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
            Button("Continue") { onUnlock(pin) }
                .buttonStyle(CipherGoldButtonStyle())
                .disabled(!PinDraft.canContinue(pin))
            Button("Cancel", action: onCancel)
                .font(CipherFont.button)
                .foregroundStyle(CipherColor.link)
                .frame(minHeight: CipherA11y.minimumTarget)
        }
        .padding(CipherSpace.s24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CipherColor.bg)
    }
}
