import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct BackupExportScreen: View {
    @ObservedObject var library: LibraryModel
    var analytics: any AnalyticsClient
    var onBack: () -> Void

    @State private var password = ""
    @State private var repeated = ""
    @State private var showPassword = false
    @State private var showRepeated = false
    @State private var working = false
    @State private var message: String?
    @State private var ready: Ready?
    @State private var saveFile = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var count: Int { library.activeItems.count }
    private var bytes: Int { library.activeItems.reduce(0) { $0 + $1.byteCount } }

    var body: some View {
        CipherScreen {
            if let ready {
                readyBody(ready)
            } else {
                form
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .fileExporter(
            isPresented: $saveFile,
            document: ready.map { BackupExportDocument(url: $0.url) },
            contentType: .data,
            defaultFilename: ready?.url.lastPathComponent
        ) { result in
            if case .success = result {
                analytics.track(BackupRules.saved, properties: BackupRules.properties(count: ready?.count ?? 0, destination: "files"))
            }
        }
    }

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CipherSpace.s16) {
                header("Export a backup")
                Text(BackupRules.intro)
                    .font(CipherFont.body)
                    .foregroundStyle(CipherColor.sub)
                vaultCard
                secretField("Backup password", text: $password, visible: $showPassword)
                secretField("Repeat password", text: $repeated, visible: $showRepeated)
                Text(BackupRules.passwordNote)
                    .font(CipherFont.caption)
                    .foregroundStyle(CipherColor.sub)
                warning
                if let message {
                    Text(message).font(CipherFont.caption).foregroundStyle(CipherColor.danger)
                }
                Spacer(minLength: CipherSpace.s16)
                Button(working ? "Working…" : "Create backup", action: create)
                    .buttonStyle(CipherGoldButtonStyle())
                    .disabled(working || !BackupRules.canCreate(password: password, repeated: repeated))
                    .opacity(BackupRules.canCreate(password: password, repeated: repeated) ? 1 : 0.45)
            }
            .padding(CipherSpace.s20)
        }
    }

    private func readyBody(_ ready: Ready) -> some View {
        VStack(alignment: .leading, spacing: CipherSpace.s16) {
            Spacer()
            mark
            Text("Backup ready.")
                .font(CipherFont.title)
                .foregroundStyle(CipherColor.ink)
                .frame(maxWidth: .infinity)
            Text("\(ItemCountCopy.label(ready.count)) from Personal.")
                .font(CipherFont.body)
                .foregroundStyle(CipherColor.sub)
                .frame(maxWidth: .infinity)
            HStack(spacing: CipherSpace.s12) {
                iconTile(system: "doc")
                VStack(alignment: .leading, spacing: CipherSpace.s4) {
                    Text(ready.url.lastPathComponent)
                        .font(CipherFont.button)
                        .foregroundStyle(CipherColor.ink)
                        .lineLimit(2)
                    Text("\(ByteCountCopy.label(ready.bytes)) · \(BackupRules.notSaved)")
                        .font(CipherFont.caption)
                        .foregroundStyle(CipherColor.sub)
                }
            }
            .padding(CipherSpace.s16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CipherColor.card, in: RoundedRectangle(cornerRadius: CipherRadius.card))
            infoCard(BackupRules.readyNote)
            Spacer()
            Button("Save to Files") { saveFile = true }
                .buttonStyle(CipherGoldButtonStyle())
            Button("Share") { share(ready) }
                .buttonStyle(CipherOutlineButtonStyle())
        }
        .padding(CipherSpace.s20)
    }

    private var vaultCard: some View {
        HStack(spacing: CipherSpace.s12) {
            iconTile(system: "lock")
            VStack(alignment: .leading, spacing: CipherSpace.s4) {
                Text("Personal").font(CipherFont.button).foregroundStyle(CipherColor.ink)
                Text("\(ItemCountCopy.label(count)) · about \(ByteCountCopy.label(bytes))")
                    .font(CipherFont.caption)
                    .foregroundStyle(CipherColor.sub)
            }
            Spacer()
            Button("Change") {}
                .font(CipherFont.button)
                .foregroundStyle(CipherColor.link)
                .frame(minHeight: CipherA11y.minimumTarget)
                .accessibilityLabel("Change vault")
        }
        .padding(CipherSpace.s16)
        .background(CipherColor.card, in: RoundedRectangle(cornerRadius: CipherRadius.card))
    }

    private var warning: some View {
        HStack(alignment: .top, spacing: CipherSpace.s12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(CipherColor.amber)
                .accessibilityHidden(true)
            Text(BackupRules.warning)
                .font(CipherFont.body)
                .foregroundStyle(CipherColor.ink)
        }
        .padding(CipherSpace.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CipherColor.amberBg, in: RoundedRectangle(cornerRadius: CipherRadius.card))
        .overlay(RoundedRectangle(cornerRadius: CipherRadius.card).stroke(CipherColor.amber, lineWidth: 1))
    }

    private func create() {
        guard BackupRules.canCreate(password: password, repeated: repeated) else { return }
        working = true
        message = nil
        let chosen = password
        analytics.track(BackupRules.exportStarted, properties: BackupRules.properties(count: count))
        do {
            let result = try library.exportBackup(password: chosen)
            password = ""
            repeated = ""
            ready = Ready(url: result.url, count: result.count, bytes: result.bytes)
            analytics.track(BackupRules.exportCompleted, properties: BackupRules.properties(count: result.count))
        } catch {
            message = BackupRules.message(for: error)
        }
        working = false
    }

    private func share(_ ready: Ready) {
        analytics.track(BackupRules.saved, properties: BackupRules.properties(count: ready.count, destination: "share"))
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.keyWindow?.rootViewController else { return }
        let controller = UIActivityViewController(activityItems: [ready.url], applicationActivities: nil)
        controller.popoverPresentationController?.sourceView = root.view
        controller.popoverPresentationController?.sourceRect = CGRect(x: root.view.bounds.midX, y: root.view.bounds.midY, width: 1, height: 1)
        root.present(controller, animated: !reduceMotion)
    }

    private func header(_ title: String) -> some View {
        HStack {
            CipherBackButton(action: onBack)
            Text(title).font(CipherFont.h2).foregroundStyle(CipherColor.ink)
            Spacer()
        }
    }

    private var mark: some View {
        ZStack {
            Circle().fill(CipherColor.tint).frame(width: 96, height: 96)
            Circle().fill(CipherColor.gold).frame(width: 72, height: 72)
            Image(systemName: "checkmark")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(CipherColor.onGold)
        }
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }

    private func iconTile(system: String) -> some View {
        Image(systemName: system)
            .foregroundStyle(CipherColor.tintInk)
            .frame(width: 44, height: 44)
            .background(CipherColor.tint, in: RoundedRectangle(cornerRadius: 12))
            .accessibilityHidden(true)
    }

    private func infoCard(_ text: String) -> some View {
        HStack(alignment: .top, spacing: CipherSpace.s12) {
            Image(systemName: "info.circle")
                .foregroundStyle(CipherColor.tintInk)
                .accessibilityHidden(true)
            Text(text).font(CipherFont.body).foregroundStyle(CipherColor.ink)
        }
        .padding(CipherSpace.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CipherColor.card, in: RoundedRectangle(cornerRadius: CipherRadius.card))
    }

    private func secretField(_ title: String, text: Binding<String>, visible: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: CipherSpace.s4) {
                Text(title).font(CipherFont.caption).foregroundStyle(CipherColor.sub)
                Group {
                    if visible.wrappedValue {
                        TextField(title, text: text)
                    } else {
                        SecureField(title, text: text)
                    }
                }
                .font(CipherFont.body)
                .foregroundStyle(CipherColor.ink)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            }
            Button {
                visible.wrappedValue.toggle()
            } label: {
                CipherIcon.eye.image
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(visible.wrappedValue ? "Hide password" : "Show password")
        }
        .padding(.horizontal, CipherSpace.s16)
        .padding(.vertical, CipherSpace.s8)
        .frame(minHeight: 64)
        .background(CipherColor.card, in: RoundedRectangle(cornerRadius: CipherRadius.card))
    }

    private struct Ready {
        var url: URL
        var count: Int
        var bytes: Int
    }
}

struct BackupRestoreScreen: View {
    @ObservedObject var library: LibraryModel
    var analytics: any AnalyticsClient
    var onBack: () -> Void
    var onOpen: () -> Void

    @State private var file: URL?
    @State private var fileName = ""
    @State private var fileBytes = 0
    @State private var password = ""
    @State private var pin = ""
    @State private var showPassword = false
    @State private var picking = false
    @State private var working = false
    @State private var message: String?
    @State private var wrong = false
    @State private var restored: RestoredVault?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        CipherScreen {
            if let restored {
                done(restored)
            } else {
                form
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .fileImporter(isPresented: $picking, allowedContentTypes: [.data, .item]) { result in
            guard case .success(let url) = result else {
                message = BackupRules.badFile
                return
            }
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            let copy = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "-" + url.lastPathComponent)
            do {
                if FileManager.default.fileExists(atPath: copy.path) {
                    try FileManager.default.removeItem(at: copy)
                }
                try FileManager.default.copyItem(at: url, to: copy)
                file = copy
                fileName = url.lastPathComponent
                fileBytes = (try? FileManager.default.attributesOfItem(atPath: copy.path)[.size] as? NSNumber)?.intValue ?? 0
                message = nil
                wrong = false
            } catch {
                message = BackupRules.badFile
            }
        }
    }

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CipherSpace.s16) {
                header("Restore from backup")
                Text(BackupRules.restoreIntro)
                    .font(CipherFont.body)
                    .foregroundStyle(CipherColor.sub)
                step(1, BackupRules.chooseFile, BackupRules.chooseFileDetail) {
                    Button(action: { picking = true }) {
                        HStack {
                            Image(systemName: "doc")
                                .foregroundStyle(CipherColor.tintInk)
                                .accessibilityHidden(true)
                            Text(fileName.isEmpty ? "Choose a file" : fileName)
                                .font(CipherFont.button)
                                .foregroundStyle(CipherColor.ink)
                                .lineLimit(1)
                            Spacer()
                            if fileBytes > 0 {
                                Text(ByteCountCopy.label(fileBytes))
                                    .font(CipherFont.caption)
                                    .foregroundStyle(CipherColor.sub)
                            }
                        }
                        .padding(CipherSpace.s12)
                        .frame(minHeight: CipherA11y.minimumTarget)
                        .background(CipherColor.tint, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .accessibilityLabel(BackupRules.chooseFile)
                }
                step(2, BackupRules.passwordTitle, BackupRules.passwordDetail) {
                    HStack {
                        Group {
                            if showPassword {
                                TextField("Password", text: $password)
                            } else {
                                SecureField("Password", text: $password)
                            }
                        }
                        .font(CipherFont.body)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        Button {
                            showPassword.toggle()
                        } label: {
                            CipherIcon.eye.image.frame(width: 44, height: 44)
                        }
                        .accessibilityLabel(showPassword ? "Hide password" : "Show password")
                    }
                    .padding(.horizontal, CipherSpace.s12)
                    .frame(minHeight: 52)
                    .background(CipherColor.bg, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(wrong ? CipherColor.danger : CipherColor.line, lineWidth: wrong ? 1.5 : 1)
                    )
                    Text(BackupRules.pinTitle)
                        .font(CipherFont.caption)
                        .foregroundStyle(CipherColor.sub)
                    SecureField("At least 6 digits", text: $pin)
                        .font(CipherFont.body)
                        .keyboardType(.numberPad)
                        .padding(.horizontal, CipherSpace.s12)
                        .frame(minHeight: CipherA11y.minimumTarget)
                        .background(CipherColor.bg, in: RoundedRectangle(cornerRadius: 12))
                    Text(BackupRules.pinHint)
                        .font(CipherFont.caption)
                        .foregroundStyle(CipherColor.sub)
                }
                if let message {
                    Text(message)
                        .font(CipherFont.caption)
                        .foregroundStyle(CipherColor.danger)
                }
                infoCard(BackupRules.restoreNote)
                Spacer(minLength: CipherSpace.s16)
                Button(working ? "Working…" : "Restore", action: restore)
                    .buttonStyle(CipherGoldButtonStyle())
                    .disabled(working || file == nil || password.count < BackupRules.minimumPassword || pin.count < 6)
                    .opacity(file != nil && password.count >= BackupRules.minimumPassword && pin.count >= 6 ? 1 : 0.45)
            }
            .padding(CipherSpace.s20)
        }
    }

    private func done(_ restored: RestoredVault) -> some View {
        VStack(alignment: .leading, spacing: CipherSpace.s16) {
            Spacer()
            mark
            Text("\(ItemCountCopy.label(restored.itemCount)) restored.")
                .font(CipherFont.title)
                .foregroundStyle(CipherColor.ink)
                .frame(maxWidth: .infinity)
            Text("Added as \"\(restored.name)\".")
                .font(CipherFont.body)
                .foregroundStyle(CipherColor.sub)
                .frame(maxWidth: .infinity)
            infoCard(BackupRules.restoredNote)
            Spacer()
            Button("Open vault", action: onOpen)
                .buttonStyle(CipherGoldButtonStyle())
        }
        .padding(CipherSpace.s20)
    }

    private func restore() {
        guard let file else { return }
        working = true
        message = nil
        wrong = false
        analytics.track(BackupRules.restoreStarted, properties: BackupRules.properties(count: 0))
        do {
            let result = try library.restoreBackup(from: file, password: password, pin: pin)
            password = ""
            pin = ""
            restored = result
            analytics.track(BackupRules.restoreCompleted, properties: BackupRules.properties(count: result.itemCount))
        } catch {
            message = BackupRules.message(for: error)
            wrong = (error as? BackupFile.Failure) == .wrongPassword
            analytics.track(
                BackupRules.restoreFailed,
                properties: BackupRules.properties(count: 0, reason: BackupRules.reason(for: error))
            )
        }
        working = false
    }

    private func header(_ title: String) -> some View {
        HStack {
            CipherBackButton(action: onBack)
            Text(title).font(CipherFont.h2).foregroundStyle(CipherColor.ink)
            Spacer()
        }
    }

    private var mark: some View {
        ZStack {
            Circle().fill(CipherColor.tint).frame(width: 96, height: 96)
            Circle().fill(CipherColor.gold).frame(width: 72, height: 72)
            Image(systemName: "checkmark")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(CipherColor.onGold)
        }
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }

    private func infoCard(_ text: String) -> some View {
        HStack(alignment: .top, spacing: CipherSpace.s12) {
            Image(systemName: "info.circle")
                .foregroundStyle(CipherColor.tintInk)
                .accessibilityHidden(true)
            Text(text).font(CipherFont.body).foregroundStyle(CipherColor.ink)
        }
        .padding(CipherSpace.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CipherColor.card, in: RoundedRectangle(cornerRadius: CipherRadius.card))
    }

    private func step<Content: View>(_ number: Int, _ title: String, _ detail: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: CipherSpace.s12) {
            HStack(alignment: .top, spacing: CipherSpace.s12) {
                Text("\(number)")
                    .font(CipherFont.button)
                    .foregroundStyle(CipherColor.onGold)
                    .frame(width: 28, height: 28)
                    .background(CipherColor.gold, in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: CipherSpace.s4) {
                    Text(title).font(CipherFont.button).foregroundStyle(CipherColor.ink)
                    Text(detail).font(CipherFont.caption).foregroundStyle(CipherColor.sub)
                }
            }
            content()
        }
        .padding(CipherSpace.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CipherColor.card, in: RoundedRectangle(cornerRadius: CipherRadius.card))
    }
}

private struct BackupExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.data] }
    var url: URL

    init(url: URL) { self.url = url }

    init(configuration: ReadConfiguration) throws {
        throw BackupFile.Failure.badFile
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        try FileWrapper(url: url, options: .immediate)
    }
}

private extension UIWindowScene {
    var keyWindow: UIWindow? { windows.first { $0.isKeyWindow } }
}
