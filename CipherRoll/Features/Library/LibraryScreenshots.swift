import SwiftUI
import UIKit

/// Sample library used only by `-screen` launches. It has no vault and no keys.
@MainActor
enum LibraryPreview {
    static func model(named name: String) -> LibraryModel {
        let model = LibraryModel()
        apply(name, to: model)
        return model
    }

    static func apply(_ name: String, to model: LibraryModel) {
        guard name != "homeEmpty" else { return }
        let now = Date()
        var items: [LibraryItem] = []
        var thumbs: [UUID: UIImage] = [:]
        for index in 0..<43 {
            let id = UUID()
            let album = index < 6 ? "Trip" : (index < 10 ? "Home" : nil)
            let title = index < 4 ? "Trip beach \(index + 1).jpg" : "Photo \(index + 1).jpg"
            items.append(LibraryItem(
                id: id, kind: .photo, displayName: title, byteCount: 180_000,
                album: album, deletedAt: nil, createdAt: now.addingTimeInterval(TimeInterval(-index * 60))
            ))
            if index < 8 {
                thumbs[id] = swatch(index: index)
            }
        }
        for index in 0..<8 {
            items.append(LibraryItem(
                id: UUID(), kind: .video, displayName: "Clip \(index + 1).mov", byteCount: 4_000_000,
                album: nil, deletedAt: nil, createdAt: now.addingTimeInterval(TimeInterval(-3_600 - index))
            ))
        }
        let fileID = UUID()
        items.append(LibraryItem(
            id: fileID, kind: .file, displayName: "passport.pdf", byteCount: 220_000,
            album: nil, deletedAt: nil, createdAt: now.addingTimeInterval(-7_200)
        ))
        items.append(LibraryItem(
            id: UUID(), kind: .file, displayName: "lease.pdf", byteCount: 90_000,
            album: "Home", deletedAt: nil, createdAt: now.addingTimeInterval(-8_000)
        ))
        items.append(LibraryItem(
            id: UUID(), kind: .file, displayName: "tax.pdf", byteCount: 140_000,
            album: nil, deletedAt: nil, createdAt: now.addingTimeInterval(-9_000)
        ))
        let noteID = UUID()
        items.append(LibraryItem(
            id: noteID, kind: .note, displayName: "Trip notes", byteCount: 80,
            album: nil, deletedAt: nil, createdAt: now.addingTimeInterval(-10_000)
        ))
        items.append(LibraryItem(
            id: UUID(), kind: .note, displayName: "Door code", byteCount: 20,
            album: nil, deletedAt: nil, createdAt: now.addingTimeInterval(-11_000)
        ))
        let trashed = UUID()
        items.append(LibraryItem(
            id: trashed, kind: .photo, displayName: "Old.jpg", byteCount: 100_000,
            album: nil, deletedAt: now.addingTimeInterval(-2 * 86_400), createdAt: now.addingTimeInterval(-90_000)
        ))
        thumbs[trashed] = swatch(index: 5)
        model.items = items
        model.thumbs = thumbs
        switch name {
        case "importOver":
            model.importScreen = .overLimit(kind: .photo, selected: 18, allowed: 15)
        case "importProgress":
            model.importScreen = .progress
            model.importedCount = 4
            model.importTotal = 12
            model.rows = [
                ImportRow(name: "Trip beach 1.jpg", state: .locked),
                ImportRow(name: "Trip beach 2.jpg", state: .working(0.4)),
                ImportRow(name: "Clip 1.mov", state: .waiting)
            ]
        case "importPaused":
            model.importScreen = .paused(imported: 4, waiting: 8)
        case "importDone":
            model.importScreen = .done(count: 12, photoOriginals: 12)
        case "importAdd":
            model.importScreen = .add
        case "search":
            model.searchText = "trip"
        case "select":
            model.selecting = true
            model.selected = Set(items.filter { $0.kind == .photo }.prefix(2).map(\.id))
        default:
            break
        }
    }

    static func swatch(index: Int) -> UIImage {
        let colors: [UIColor] = [
            UIColor(red: 0.20, green: 0.35, blue: 0.55, alpha: 1),
            UIColor(red: 0.75, green: 0.55, blue: 0.28, alpha: 1),
            UIColor(red: 0.35, green: 0.48, blue: 0.38, alpha: 1),
            UIColor(red: 0.55, green: 0.32, blue: 0.32, alpha: 1),
            UIColor(red: 0.28, green: 0.42, blue: 0.62, alpha: 1),
            UIColor(red: 0.45, green: 0.40, blue: 0.28, alpha: 1)
        ]
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 240, height: 240))
        return renderer.image { context in
            colors[index % colors.count].setFill()
            context.fill(CGRect(x: 0, y: 0, width: 240, height: 240))
        }
    }
}

@MainActor
struct LibraryScreenshot: View {
    var name: String
    @StateObject private var library: LibraryModel
    @State private var path: [LibraryPage] = []

    init(name: String) {
        self.name = name
        _library = StateObject(wrappedValue: LibraryPreview.model(named: name))
    }

    var body: some View {
        StagePreview(itemCount: library.counts.total) {
            screen
        }
    }

    @ViewBuilder
    private var screen: some View {
        switch name {
        case "usage":
            sheet { UsageSheet(counts: library.counts, onManage: {}, onUpgrade: {}) }
        case "vaults":
            sheet { VaultSwitcherSheet(onClose: {}) }
        case "homeTrial":
            homeTrial
        case "importAdd", "importOver", "importProgress", "importPaused", "importDone":
            sheet { ImportContainer(library: library) }
        case "photoGrid":
            ItemGridView(library: library, kind: .photo, album: nil, path: $path, onMove: {})
        case "select":
            ItemGridView(library: library, kind: .photo, album: nil, path: $path, onMove: {}, startsSelecting: true)
        case "albums":
            AlbumGridView(library: library, kind: .photo, path: $path)
        case "search":
            SearchView(library: library, path: $path)
        case "trash":
            TrashView(library: library)
        case "settings":
            SettingsStub(onLock: {}, onTrash: {})
        case "photoViewer":
            if let id = library.items.first(where: { $0.kind == .photo && library.thumbs[$0.id] != nil })?.id {
                ItemViewer(library: library, id: id)
            }
        case "fileViewer":
            if let id = library.items.first(where: { $0.displayName == "passport.pdf" })?.id {
                ItemViewer(library: library, id: id)
            }
        case "note":
            if let id = library.items.first(where: { $0.kind == .note })?.id {
                NoteEditor(
                    library: library,
                    id: id,
                    previewBody: "Ferry at 9. Gate code stays on this iPhone."
                )
            }
        default:
            home
        }
    }

    private var homeTrial: some View {
        dashboard(chip: "Trial", button: "Manage")
    }

    private var home: some View {
        let nearest = FreePlanChip.nearest(library.counts)
        return dashboard(
            chip: FreePlanChip.title(kind: nearest.kind, used: nearest.used, limit: nearest.limit),
            button: "Upgrade"
        )
    }

    private func dashboard(chip: String, button: String) -> some View {
        HomeDashboard(
            shortcut: BiometryLabel.current(),
            itemCount: library.counts.total,
            chip: chip,
            chipButton: button,
            counts: library.counts,
            recent: Array(library.activeItems.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }.prefix(8)),
            thumbs: library.thumbs,
            onSearch: {}, onLock: {}, onChip: {}, onChipAction: {}, onVaults: {}, onKind: { _ in }, onOpen: { _ in }, onAdd: {}, onSettings: {}
        )
    }

    private func sheet<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack(alignment: .bottom) {
            home.allowsHitTesting(false)
            content()
                .frame(maxWidth: .infinity, maxHeight: 560, alignment: .top)
                .background(CipherColor.bg)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
    }
}

struct StagePreview<Content: View>: View {
    var itemCount: Int
    @ViewBuilder var content: () -> Content
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        if CipherLayout.usesSidebar(sizeClass) {
            NavigationSplitView {
                LibrarySidebar(
                    itemCount: itemCount,
                    onHome: {},
                    onKind: { _ in },
                    onSettings: {},
                    onHelp: {}
                )
            } detail: {
                content()
            }
            .navigationSplitViewStyle(.balanced)
        } else {
            content()
        }
    }
}
