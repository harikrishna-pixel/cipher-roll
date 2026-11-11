import AVKit
import SwiftUI
import UIKit

struct ItemGridView: View {
    @ObservedObject var library: LibraryModel
    var kind: ItemKind
    var album: String?
    @Binding var path: [LibraryPage]
    var onMove: () -> Void
    var startsSelecting = false
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var shown: [LibraryItem] { library.items(kind: kind, album: album) }

    var body: some View {
        CipherScreen(width: .stage) {
            VStack(spacing: 0) {
                header
                if kind == .photo && album == nil {
                    Button("Albums") { path.append(.albums(kind)) }
                        .font(CipherFont.button)
                        .foregroundStyle(CipherColor.link)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, CipherSpace.s20)
                }
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: sizeClass == .regular ? 96 : 104), spacing: 4)], spacing: 4) {
                        ForEach(shown) { item in
                            Button {
                                if library.selecting {
                                    toggle(item.id)
                                } else if item.kind == .note {
                                    path.append(.note(item.id))
                                } else {
                                    path.append(.viewer(item.id))
                                }
                            } label: {
                                cell(item)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(item.displayName)
                            .onAppear { library.thumbnail(for: item) }
                        }
                    }
                    .padding(4)
                }
                if library.selecting { selectBar }
            }
        }
        .onAppear {
            if !startsSelecting { library.selecting = false }
        }
    }

    private var header: some View {
        HStack {
            if library.selecting {
                Button("Cancel") { library.selecting = false; library.selected = [] }
                    .frame(minHeight: 44)
                Spacer()
                Text("\(library.selected.count) selected").font(CipherFont.button)
                Spacer()
                Button("Select all") { library.selected = Set(shown.map(\.id)) }
                    .frame(minHeight: 44)
            } else {
                CipherBackButton { path.removeLast() }
                VStack(alignment: .leading, spacing: 0) {
                    Text(album ?? kindTitle(kind)).font(CipherFont.h2).foregroundStyle(CipherColor.ink)
                    Text("Personal · \(ItemCountCopy.label(shown.count))").font(CipherFont.caption).foregroundStyle(CipherColor.sub)
                }
                Spacer()
                if !shown.isEmpty {
                    Button("Select") { library.selecting = true }
                        .font(CipherFont.button)
                        .frame(minHeight: 44)
                }
                Menu {
                    Button("Export all") { exportAll() }
                    Button("Albums") { path.append(.albums(kind)) }
                    Button("Recently Deleted") { path.append(.trash) }
                } label: {
                    Image(systemName: "ellipsis").frame(width: 44, height: 44)
                }
                .accessibilityLabel("More")
            }
        }
        .padding(.horizontal, CipherSpace.s12)
        .foregroundStyle(CipherColor.ink)
    }

    private func cell(_ item: LibraryItem) -> some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let image = library.thumbs[item.id] {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    CipherColor.tint.overlay { kindIcon(item.kind).foregroundStyle(CipherColor.tintInk) }
                }
            }
            .frame(minHeight: 110)
            .clipped()
            if library.selecting {
                Image(systemName: library.selected.contains(item.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(library.selected.contains(item.id) ? CipherColor.gold : .white)
                    .padding(6)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var selectBar: some View {
        HStack {
            Button("Export") { exportSelected() }.frame(maxWidth: .infinity, minHeight: 44)
            Button("Move", action: onMove).frame(maxWidth: .infinity, minHeight: 44)
            Button("Delete") { library.softDelete(Array(library.selected)) }
                .foregroundStyle(CipherColor.danger)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .font(CipherFont.button)
        .foregroundStyle(CipherColor.ink)
    }

    private func toggle(_ id: UUID) {
        if library.selected.contains(id) { library.selected.remove(id) } else { library.selected.insert(id) }
    }

    private func exportSelected() {
        SharePresenter.share(items: exportItems(Array(library.selected)))
    }

    private func exportAll() {
        SharePresenter.share(items: exportItems(shown.map(\.id)))
    }

    private func exportItems(_ ids: [UUID]) -> [SharePayload] {
        ids.compactMap { id in
            guard let item = library.items.first(where: { $0.id == id }), let data = library.read(id) else { return nil }
            return SharePayload(data: data, name: item.displayName)
        }
    }
}

struct AlbumGridView: View {
    @ObservedObject var library: LibraryModel
    var kind: ItemKind
    @Binding var path: [LibraryPage]
    @State private var newName = ""
    @State private var showNew = false

    var body: some View {
        CipherScreen(width: .stage) {
            ScrollView {
                VStack(alignment: .leading, spacing: CipherSpace.s12) {
                    HStack {
                        CipherBackButton { path.removeLast() }
                        Text(kindTitle(kind)).font(CipherFont.h2).foregroundStyle(CipherColor.ink)
                        Spacer()
                    }
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: CipherSpace.s16) {
                        albumCard("All \(FreePlanChip.label(kind))", library.items(kind: kind, album: nil).count) {
                            path.append(.kind(kind))
                        }
                        ForEach(library.albums(kind: kind), id: \.self) { name in
                            albumCard(name, library.items(kind: kind, album: name).count) {
                                path.append(.album(kind, name))
                            }
                        }
                        Button { showNew = true } label: {
                            VStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(CipherColor.tint)
                                    .frame(height: 120)
                                    .overlay { Image(systemName: "plus").font(.title2).foregroundStyle(CipherColor.ink) }
                                Text("New album").font(CipherFont.button).foregroundStyle(CipherColor.ink)
                                Text("Group your photos").font(CipherFont.caption).foregroundStyle(CipherColor.sub)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(CipherSpace.s16)
            }
        }
        .alert("New album", isPresented: $showNew) {
            TextField("Name", text: $newName)
            Button("Create") {
                let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty { path.append(.album(kind, name)) }
                newName = ""
            }
            Button("Cancel", role: .cancel) { newName = "" }
        } message: {
            Text("The album name stays inside this vault.")
        }
    }

    private func albumCard(_ title: String, _ count: Int, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 16).fill(CipherColor.tint).frame(height: 120)
                    .overlay { kindIcon(kind).foregroundStyle(CipherColor.tintInk) }
                Text(title).font(CipherFont.button).foregroundStyle(CipherColor.ink)
                Text(ItemCountCopy.label(count)).font(CipherFont.caption).foregroundStyle(CipherColor.sub)
            }
        }
        .buttonStyle(.plain)
    }
}

struct TrashView: View {
    @ObservedObject var library: LibraryModel

    var body: some View {
        CipherScreen {
            VStack(alignment: .leading, spacing: CipherSpace.s12) {
                Text("Recently Deleted").font(CipherFont.h2).foregroundStyle(CipherColor.ink)
                Text("Items are permanently deleted after 30 days.")
                    .font(CipherFont.caption).foregroundStyle(CipherColor.sub)
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], spacing: 8) {
                        ForEach(library.trashedItems) { item in
                            Button { toggle(item.id) } label: {
                                ZStack(alignment: .bottomLeading) {
                                    groupThumb(item).frame(height: 110).clipped()
                                    if let deleted = item.deletedAt {
                                        Text("\(TrashPolicy.daysRemaining(deletedAt: deleted, now: Date())) days")
                                            .font(CipherFont.caption)
                                            .foregroundStyle(.white)
                                            .padding(6)
                                            .background(.black.opacity(0.45), in: Capsule())
                                            .padding(6)
                                    }
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                            .onAppear { library.thumbnail(for: item) }
                        }
                    }
                }
                HStack {
                    Button("Restore") { library.restore(Array(library.selected)) }
                        .frame(maxWidth: .infinity, minHeight: 44)
                    Button("Delete now") { library.deleteNow(Array(library.selected)) }
                        .foregroundStyle(CipherColor.danger)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .font(CipherFont.button)
                .foregroundStyle(CipherColor.ink)
            }
            .padding(CipherSpace.s16)
        }
    }

    private func toggle(_ id: UUID) {
        if library.selected.contains(id) { library.selected.remove(id) } else { library.selected.insert(id) }
    }

    @ViewBuilder
    private func groupThumb(_ item: LibraryItem) -> some View {
        if let image = library.thumbs[item.id] {
            Image(uiImage: image).resizable().scaledToFill()
        } else {
            CipherColor.tint.overlay { kindIcon(item.kind).foregroundStyle(CipherColor.tintInk) }
        }
    }
}

struct SearchView: View {
    @ObservedObject var library: LibraryModel
    @Binding var path: [LibraryPage]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        CipherScreen {
            VStack(alignment: .leading, spacing: CipherSpace.s12) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(CipherColor.sub)
                    TextField("Search", text: $library.searchText)
                        .font(CipherFont.body)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit { library.refreshNoteSearch() }
                    Button("Cancel") {
                        library.searchText = ""
                        path.removeLast()
                    }
                    .frame(minHeight: 44)
                }
                .padding(.horizontal, CipherSpace.s12)
                .background(CipherColor.card, in: Capsule())
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        filter(nil, "All")
                        filter(.photo, "Photos")
                        filter(.video, "Videos")
                        filter(.file, "Files")
                        filter(.note, "Notes")
                    }
                }
                Text("\(library.searchResults().count) results")
                    .font(CipherFont.caption).foregroundStyle(CipherColor.sub)
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(library.searchResults()) { item in
                            Button {
                                path.append(item.kind == .note ? .note(item.id) : .viewer(item.id))
                            } label: {
                                HStack {
                                    kindIcon(item.kind).foregroundStyle(CipherColor.tintInk)
                                        .frame(width: 36, height: 36)
                                        .background(CipherColor.tint, in: RoundedRectangle(cornerRadius: 8))
                                    VStack(alignment: .leading) {
                                        Text(item.displayName).font(CipherFont.button).foregroundStyle(CipherColor.ink)
                                        Text(subtitle(item)).font(CipherFont.caption).foregroundStyle(CipherColor.sub)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, CipherSpace.s8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Text("Search runs on this iPhone.")
                    .font(CipherFont.caption)
                    .foregroundStyle(CipherColor.sub)
                    .frame(maxWidth: .infinity)
            }
            .padding(CipherSpace.s16)
        }
        .onChange(of: library.searchText) { _ in library.refreshNoteSearch() }
    }

    private func filter(_ kind: ItemKind?, _ title: String) -> some View {
        let on = library.searchKind == kind
        return Button(title) { library.searchKind = kind }
            .font(CipherFont.caption)
            .foregroundStyle(on ? CipherColor.card : CipherColor.ink)
            .padding(.horizontal, 12)
            .frame(minHeight: 32)
            .background(on ? CipherColor.hero : CipherColor.card, in: Capsule())
            .overlay(Capsule().stroke(CipherColor.line, lineWidth: on ? 0 : 1))
    }

    private func subtitle(_ item: LibraryItem) -> String {
        var parts = [kindTitle(item.kind), "Personal"]
        if let album = item.album { parts.append(album) }
        return parts.joined(separator: " · ")
    }
}

struct ItemViewer: View {
    @ObservedObject var library: LibraryModel
    var id: UUID
    @State private var videoURL: URL?
    @State private var player: AVPlayer?
    @State private var showInfo = false
    @State private var showMove = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var item: LibraryItem? { library.items.first { $0.id == id } }
    private var regular: Bool { CipherLayout.usesSidebar(sizeClass) }

    var body: some View {
        CipherScreen(width: .stage) {
            if regular {
                wideBody
            } else {
                phoneBody
            }
        }
        .onAppear {
            guard item?.kind == .video else { return }
            videoURL = library.videoURL(id)
            if let videoURL {
                let next = AVPlayer(url: videoURL)
                next.play()
                player = next
            }
        }
        .onDisappear {
            player?.pause()
            player = nil
            if let videoURL { library.endVideo(videoURL) }
        }
        .alert("Info", isPresented: $showInfo) {
            Button("OK", role: .cancel) {}
        } message: {
            if let item {
                Text("\(kindTitle(item.kind)) · \(item.displayName)\n\(ByteCountCopy.label(item.byteCount))\n\(item.album ?? "No album")")
            }
        }
        .sheet(isPresented: $showMove) {
            MoveSheet(albums: library.albums(kind: item?.kind ?? .photo), onPick: { name in
                library.move([id], album: name)
                showMove = false
            }, onClose: { showMove = false })
                .cipherCenteredSheet()
        }
    }

    private var phoneBody: some View {
        VStack {
                HStack {
                    CipherBackButton { close() }
                    Spacer()
                    if let item {
                        Text(item.displayName)
                            .font(CipherFont.button)
                            .lineLimit(2)
                            .accessibilityLabel(item.displayName)
                    }
                    Spacer()
                    Button { showInfo = true } label: {
                        Image(systemName: "info.circle").frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Info")
                }
                .padding(.horizontal, CipherSpace.s8)
                Spacer()
                content
                Spacer()
                if let item {
                    Text("Stored in Personal")
                        .font(CipherFont.caption)
                        .foregroundStyle(CipherColor.sub)
                        .accessibilityLabel("Status: stored in your Personal vault")
                    HStack {
                        Button("Export") { export(item) }.frame(maxWidth: .infinity, minHeight: 44)
                        Button("Delete") { library.softDelete([item.id]); close() }
                            .foregroundStyle(CipherColor.danger)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .font(CipherFont.button)
                    .foregroundStyle(CipherColor.ink)
                }
            }
            .padding(CipherSpace.s12)
    }

    private var wideBody: some View {
        VStack(spacing: CipherSpace.s16) {
            HStack {
                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(CipherColor.ink)
                        .frame(width: 44, height: 44)
                        .background(CipherColor.card, in: Circle())
                }
                .accessibilityLabel("Close")
                Spacer()
                Text(positionTitle)
                    .font(CipherFont.button)
                    .foregroundStyle(CipherColor.ink)
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            GeometryReader { proxy in
                let panel = proxy.size.width > 560 ? 280.0 : 220.0
                let photo = max(proxy.size.width - panel - CipherSpace.s24, 80)
                HStack(alignment: .top, spacing: CipherSpace.s24) {
                    content
                        .frame(width: photo, height: proxy.size.height)
                    detailPanel
                        .frame(width: panel, height: proxy.size.height)
                }
            }
        }
        .padding(CipherSpace.s20)
    }

    private var positionTitle: String {
        guard let item else { return "" }
        let peers = library.items(kind: item.kind, album: nil)
        guard let index = peers.firstIndex(where: { $0.id == item.id }) else { return item.displayName }
        return "\(index + 1) of \(peers.count)"
    }

    private var detailPanel: some View {
        VStack(spacing: CipherSpace.s12) {
            VStack(spacing: 0) {
                detailRow("Added", addedText)
                Divider()
                detailRow("Type", item.map { typeName($0.kind) } ?? "")
                Divider()
                detailRow("Size", item.map { ByteCountCopy.label($0.byteCount) } ?? "")
                Divider()
                detailRow("Vault", "Personal")
            }
            .padding(.horizontal, CipherSpace.s16)
            .background(CipherColor.card, in: RoundedRectangle(cornerRadius: CipherRadius.card))
            if let item {
                Button { export(item) } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(CipherOutlineButtonStyle())
                Button { showMove = true } label: {
                    Label("Move", systemImage: "folder")
                }
                .buttonStyle(CipherOutlineButtonStyle())
                Button { library.softDelete([item.id]); close() } label: {
                    Label("Delete", systemImage: "trash")
                        .foregroundStyle(CipherColor.danger)
                }
                .buttonStyle(CipherOutlineButtonStyle())
            }
            Spacer()
        }
    }

    private var addedText: String {
        guard let date = item?.createdAt else { return "—" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private func typeName(_ kind: ItemKind) -> String {
        switch kind {
        case .photo: "Photo"
        case .video: "Video"
        case .file: "File"
        case .note: "Note"
        }
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).font(CipherFont.caption).foregroundStyle(CipherColor.sub)
            Spacer()
            Text(value).font(CipherFont.button).foregroundStyle(CipherColor.ink)
        }
        .frame(minHeight: 44)
    }

    @ViewBuilder
    private var content: some View {
        if item?.kind == .video, let player {
            VideoPlayer(player: player).frame(maxHeight: 420)
        } else if let data = library.read(id), let image = UIImage(data: data) {
            Image(uiImage: image).resizable().scaledToFit().frame(maxWidth: .infinity, maxHeight: .infinity).clipShape(RoundedRectangle(cornerRadius: 20))
        } else if let image = library.thumbs[id] {
            Image(uiImage: image).resizable().scaledToFit().frame(maxWidth: .infinity, maxHeight: .infinity).clipShape(RoundedRectangle(cornerRadius: 20))
        } else if let item {
            VStack(spacing: CipherSpace.s12) {
                kindIcon(item.kind)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .foregroundStyle(CipherColor.tintInk)
                Text(item.displayName).font(CipherFont.h2).foregroundStyle(CipherColor.ink)
            }
        }
    }

    private func export(_ item: LibraryItem) {
        guard let data = library.read(id) else { return }
        SharePresenter.share(items: [SharePayload(data: data, name: item.displayName)])
    }

    private func close() {
        if let videoURL { library.endVideo(videoURL) }
        dismiss()
    }
}

struct NoteEditor: View {
    @ObservedObject var library: LibraryModel
    var id: UUID?
    var previewBody = ""
    @State private var title = ""
    @State private var bodyText = ""
    @State private var saved = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        CipherScreen {
            VStack(alignment: .leading, spacing: CipherSpace.s12) {
                HStack {
                    CipherBackButton { save(); dismiss() }
                    Spacer()
                    if saved {
                        Label("Saved", systemImage: "checkmark").font(CipherFont.caption).foregroundStyle(CipherColor.sub)
                    }
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                TextField("Title", text: $title).font(CipherFont.title).foregroundStyle(CipherColor.ink)
                Text("Stored in Personal").font(CipherFont.caption).foregroundStyle(CipherColor.sub)
                TextEditor(text: $bodyText)
                    .font(CipherFont.body)
                    .scrollContentBackground(.hidden)
                    .foregroundStyle(CipherColor.ink)
                HStack(spacing: CipherSpace.s20) {
                    Button("List") { bodyText += bodyText.hasSuffix("\n") || bodyText.isEmpty ? "- " : "\n- " }
                    Button("Line") { bodyText += "\n" }
                }
                .font(CipherFont.button)
                .foregroundStyle(CipherColor.ink)
                .frame(minHeight: 44)
            }
            .padding(CipherSpace.s16)
        }
        .onAppear(perform: load)
    }

    private func load() {
        if let id {
            title = library.items.first { $0.id == id }?.displayName ?? ""
        }
        if let id, let data = library.read(id), let text = String(data: data, encoding: .utf8) {
            bodyText = text
        } else if !previewBody.isEmpty {
            bodyText = previewBody
        }
    }

    private func save() {
        do {
            if let id {
                try library.saveNote(id: id, title: title, body: bodyText)
            } else if !title.isEmpty || !bodyText.isEmpty {
                try library.addNote(title: title, body: bodyText)
            }
            saved = true
        } catch {
            saved = false
        }
    }
}

struct MoveSheet: View {
    var albums: [String]
    var onPick: (String) -> Void
    var onClose: () -> Void
    @State private var name = ""

    var body: some View {
        VStack(alignment: .leading, spacing: CipherSpace.s12) {
            Text("Move to album").font(CipherFont.h2).foregroundStyle(CipherColor.ink)
            ForEach(Array(Set(albums)).sorted(), id: \.self) { album in
                Button(album) { onPick(album) }
                    .font(CipherFont.button)
                    .foregroundStyle(CipherColor.ink)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            TextField("New album", text: $name).textFieldStyle(.roundedBorder)
            Button("Create and move") { onPick(name) }
                .buttonStyle(CipherGoldButtonStyle())
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button("Close", action: onClose).frame(minHeight: 44)
            Spacer()
        }
        .padding(CipherSpace.s20)
    }
}

struct SharePayload: Identifiable {
    var id = UUID()
    var data: Data
    var name: String
}

enum SharePresenter {
    static func share(items: [SharePayload]) {
        guard !items.isEmpty else { return }
        present(UIActivityViewController(activityItems: items.map { ShareItem(payload: $0) }, applicationActivities: nil))
    }

    static func shareText(_ text: String) {
        guard !text.isEmpty else { return }
        present(UIActivityViewController(activityItems: [text], applicationActivities: nil))
    }

    private static func present(_ controller: UIActivityViewController) {
        guard let host = topPresenter() else { return }
        controller.popoverPresentationController?.sourceView = host.view
        controller.popoverPresentationController?.sourceRect = CGRect(x: host.view.bounds.midX, y: host.view.bounds.midY, width: 1, height: 1)
        host.present(controller, animated: true)
    }

    private static func topPresenter() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.keyWindow?.rootViewController else { return nil }
        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
}

private final class ShareItem: NSObject, UIActivityItemSource {
    let payload: SharePayload
    init(payload: SharePayload) { self.payload = payload }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any { payload.data }
    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? { payload.data }
    func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String { payload.name }
}

private extension UIWindowScene {
    var keyWindow: UIWindow? { windows.first { $0.isKeyWindow } }
}
