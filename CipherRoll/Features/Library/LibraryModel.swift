import Foundation
import Photos
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ImportRow: Identifiable {
    var id = UUID()
    var name: String
    var state: State
    var thumb: UIImage? = nil

    enum State: Equatable {
        case waiting
        case working(Double)
        case locked
        case skipped
    }
}

enum ImportScreen: Equatable {
    case add
    case overLimit(kind: ItemKind, selected: Int, allowed: Int)
    case progress
    case paused(imported: Int, waiting: Int)
    case done(count: Int, photoOriginals: Int)
}

@MainActor
final class LibraryModel: ObservableObject {
    @Published var items: [LibraryItem] = []
    @Published var thumbs: [UUID: UIImage] = [:]
    @Published var message: String?
    @Published var importScreen: ImportScreen?
    @Published var rows: [ImportRow] = []
    @Published var importedCount = 0
    @Published var importTotal = 0
    @Published var searchText = ""
    @Published var searchKind: ItemKind?
    @Published var noteMatches: Set<UUID> = []
    @Published var selected: Set<UUID> = []
    @Published var selecting = false
    @Published var requestedPage: LibraryPage?
    @Published var limitHit: ItemKind?
    @Published var showPhotoDenied = false
    @Published var toast: CipherToast?
    var limitsApply = true
    @Published var editingAllowed = true

    private var session: UnlockedSession?
    private var analytics: any AnalyticsClient = NoOpAnalyticsClient()
    private var cancelImport = false
    private var pending: [PendingImport] = []
    private var deletableAssetIDs: [String] = []
    private var lastTrashed: [UUID] = []

    var activeItems: [LibraryItem] { items.filter { $0.deletedAt == nil } }
    var trashedItems: [LibraryItem] { items.filter { $0.deletedAt != nil } }
    var counts: UsageCounts { UsageCounts.tally(items) }

    func attach(_ session: UnlockedSession?, analytics: any AnalyticsClient) {
        self.session = session
        self.analytics = analytics
        thumbs = [:]
        guard session != nil else {
            items = []
            editingAllowed = true
            return
        }
        editingAllowed = session?.isPrimaryRealVault() ?? true
        reload()
    }

    func applyPlan(removesLimits: Bool) {
        limitsApply = !removesLimits
        if removesLimits {
            editingAllowed = true
            return
        }
        editingAllowed = session?.isPrimaryRealVault() ?? true
    }

    private func refuseReadOnly() -> Bool {
        guard editingAllowed else {
            toast = CipherToast(kind: .info, title: "This vault is read-only. One vault stays editable.", action: nil)
            return true
        }
        return false
    }

    func reload() {
        guard let session else { return }
        _ = try? session.purgeExpired()
        items = (try? session.libraryItems()) ?? []
        message = nil
    }

    func items(kind: ItemKind, album: String?) -> [LibraryItem] {
        activeItems.filter { item in
            item.kind == kind && (album == nil || item.album == album)
        }
        .sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
    }

    func albums(kind: ItemKind) -> [String] {
        Array(Set(items(kind: kind, album: nil).compactMap(\.album))).sorted()
    }

    func searchResults() -> [LibraryItem] {
        activeItems.filter {
            LibrarySearch.matches(item: $0, noteText: noteMatches.contains($0.id) ? searchText : nil, query: searchText, kind: searchKind)
        }
    }

    func refreshNoteSearch() {
        noteMatches = []
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, let session else { return }
        for item in activeItems where item.kind == .note {
            if let text = try? String(data: session.readItem(item.id), encoding: .utf8),
               text.localizedCaseInsensitiveContains(query) || item.displayName.localizedCaseInsensitiveContains(query) {
                noteMatches.insert(item.id)
            }
        }
    }

    func thumbnail(for item: LibraryItem) {
        guard thumbs[item.id] == nil, item.kind == .photo || item.kind == .video, let session else { return }
        let id = item.id
        DispatchQueue.global(qos: .userInitiated).async {
            let data = try? session.readItem(id)
            let image = data.flatMap { UIImage(data: $0) }
            DispatchQueue.main.async { [weak self] in
                if let image { self?.thumbs[id] = image }
            }
        }
    }

    func read(_ id: UUID) -> Data? {
        guard let session else { return nil }
        return try? session.readItem(id)
    }

    func videoURL(_ id: UUID) -> URL? {
        try? session?.prepareVideoPlayback(id)
    }

    func endVideo(_ url: URL) {
        try? session?.endVideoPlayback(url)
    }

    func addNote(title: String, body: String) throws {
        guard !refuseReadOnly() else { return }
        guard let session else { return }
        guard !limitsApply || ImportAllowance.remaining(used: counts.notes, limit: ItemKindLimit.cap(.note)) > 0 else {
            noteLimit(.note)
            return
        }
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        _ = try session.addItem(kind: .note, displayName: name.isEmpty ? "Note" : name, bytes: Data(body.utf8))
        reload()
    }

    func saveNote(id: UUID, title: String, body: String) throws {
        guard !refuseReadOnly() else { return }
        guard let session else { return }
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        try session.replaceItem(id, displayName: name.isEmpty ? "Note" : name, bytes: Data(body.utf8))
        reload()
    }

    func softDelete(_ ids: [UUID]) {
        guard !refuseReadOnly() else { return }
        guard let session else { return }
        let now = Date()
        for id in ids { try? session.softDelete(id, at: now) }
        lastTrashed = ids
        selected = []
        selecting = false
        reload()
        toast = CipherToast(kind: .undo, title: "Moved to Recently Deleted", action: "Undo")
    }

    func undoLastTrash() {
        restore(lastTrashed)
        lastTrashed = []
        toast = nil
    }

    func restore(_ ids: [UUID]) {
        guard !refuseReadOnly() else { return }
        guard let session else { return }
        for id in ids { try? session.restoreItem(id) }
        selected = []
        reload()
    }

    func deleteNow(_ ids: [UUID]) {
        guard !refuseReadOnly() else { return }
        guard let session else { return }
        for id in ids { try? session.deleteItem(id) }
        selected = []
        reload()
    }

    func move(_ ids: [UUID], album: String?) {
        guard !refuseReadOnly() else { return }
        guard let session else { return }
        let name = album?.trimmingCharacters(in: .whitespacesAndNewlines)
        let stored = (name?.isEmpty == false) ? name : nil
        for id in ids { try? session.moveItem(id, album: stored) }
        selected = []
        selecting = false
        reload()
    }

    func beginAdd() {
        guard !refuseReadOnly() else { return }
        importScreen = .add
    }

    func trackChip() {
        let nearest = FreePlanChip.nearest(counts)
        analytics.track("home_chip_tapped", properties: ["nearest_limit_type": nearest.kind.rawValue])
    }

    func prepare(files: [PendingImport], kind: ItemKind) {
        guard !refuseReadOnly() else { return }
        guard limitsApply else {
            pending = files
            startImport(source: "files")
            return
        }
        let used = counts[kind]
        let limit = ItemKindLimit.cap(kind)
        let allowed = ImportAllowance.importable(selected: files.count, used: used, limit: limit)
        if allowed == 0 {
            importScreen = nil
            noteLimit(kind)
            return
        }
        pending = Array(files.prefix(allowed))
        if ImportAllowance.isOverLimit(selected: files.count, used: used, limit: limit) {
            importScreen = .overLimit(kind: kind, selected: files.count, allowed: allowed)
        } else {
            startImport(source: "files")
        }
    }

    func noteLimit(_ kind: ItemKind) {
        analytics.track("limit_reached", properties: ["type": kind.rawValue])
        limitHit = kind
    }

    func startImport(source: String) {
        let batch = pending
        guard !batch.isEmpty, session != nil else {
            importScreen = nil
            return
        }
        cancelImport = false
        importedCount = 0
        importTotal = batch.count
        rows = batch.map { file in
            ImportRow(name: file.name, state: .waiting, thumb: Self.makeThumb(from: file.data, kind: file.kind))
        }
        deletableAssetIDs = []
        importScreen = .progress
        analytics.track("import_started", properties: [
            "source": source,
            "item_count_bucket": CountBucket.label(batch.count)
        ])
        let session = session
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.runImport(batch, session: session)
        }
    }

    func cancelImportNow() {
        cancelImport = true
    }

    func keepOriginals() {
        deletableAssetIDs = []
        importScreen = nil
        reload()
    }

    func deleteImportedOriginals() {
        let ids = deletableAssetIDs
        guard !ids.isEmpty else {
            message = "The originals are still in Photos."
            importScreen = nil
            return
        }
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [analytics] status in
            let result = status == .authorized || status == .limited ? "authorized" : "denied"
            analytics.track("permission_result", properties: ["type": "photos_delete_originals", "result": result])
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async { [weak self] in
                    self?.showPhotoDenied = true
                    self?.importScreen = nil
                }
                return
            }
            let assets = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.deleteAssets(assets)
            }) { success, _ in
                DispatchQueue.main.async { [weak self] in
                    self?.message = success ? nil : "The originals stayed in Photos."
                    self?.deletableAssetIDs = []
                    self?.importScreen = nil
                    self?.reload()
                }
            }
        }
    }

    private func runImport(_ batch: [PendingImport], session: UnlockedSession?) {
        guard let session else { return }
        var imported = 0
        var waiting = 0
        var assetIDs: [String] = []
        for (index, file) in batch.enumerated() {
            if cancelImport {
                waiting += batch.count - index
                break
            }
            DispatchQueue.main.async { [weak self] in
                self?.rows[index].state = .working(0.6)
            }
            let available = try? FileManager.default.url(
                for: .libraryDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            ).resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage
            if !StorageRoom.canFit(bytes: file.data.count, available: available) {
                waiting += batch.count - index
                DispatchQueue.main.async { [weak self] in
                    self?.importScreen = .paused(imported: imported, waiting: waiting)
                    self?.analytics.track("import_failed", properties: ["source": "files", "error_code": "storage", "item_count_bucket": CountBucket.label(imported)])
                }
                return
            }
            do {
                let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try ProtectedFile.write(file.data, to: temp)
                let staged = try session.stageImport(from: temp)
                _ = try session.commitImport(staged, kind: file.kind, displayName: file.name, deleteOriginal: false)
                try? FileManager.default.removeItem(at: temp)
                imported += 1
                if file.kind == .photo, let asset = file.assetID { assetIDs.append(asset) }
                DispatchQueue.main.async { [weak self] in
                    self?.importedCount = imported
                    self?.rows[index].state = .locked
                }
            } catch {
                waiting += 1
                DispatchQueue.main.async { [weak self] in
                    self?.rows[index].state = .skipped
                }
            }
        }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.deletableAssetIDs = assetIDs
            self.reload()
            if case .paused = self.importScreen { return }
            self.importScreen = .done(count: imported, photoOriginals: assetIDs.count)
            self.analytics.track("import_completed", properties: [
                "source": "files",
                "item_count_bucket": CountBucket.label(imported)
            ])
        }
    }

    func exportBackup(password: String) throws -> (url: URL, count: Int, bytes: Int) {
        guard let session else { throw BackupFile.Failure.unavailable }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(BackupRules.fileName())
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        let count = try session.exportBackup(password: password, to: url)
        let bytes = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue ?? 0
        return (url, count, bytes)
    }

    func restoreBackup(from url: URL, password: String, pin: String) throws -> RestoredVault {
        guard let session else { throw BackupFile.Failure.unavailable }
        return try session.restoreBackup(from: url, password: password, secret: .pin(pin))
    }
}

struct PendingImport: Identifiable {
    var id = UUID()
    var name: String
    var kind: ItemKind
    var data: Data
    var assetID: String?
}

private extension LibraryModel {
    static func makeThumb(from data: Data, kind: ItemKind) -> UIImage? {
        guard kind == .photo || kind == .video else { return nil }
        guard let image = UIImage(data: data) else { return nil }
        let size = CGSize(width: 88, height: 88)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

enum PendingImportLoader {
    static func photo(_ image: UIImage, name: String) -> PendingImport? {
        guard let data = image.jpegData(compressionQuality: 0.9) else { return nil }
        return PendingImport(name: name, kind: .photo, data: data, assetID: nil)
    }

    static func file(url: URL) -> PendingImport? {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return nil }
        let kind = UTType(filenameExtension: url.pathExtension)?.conforms(to: .movie) == true ? ItemKind.video : .file
        return PendingImport(name: url.lastPathComponent, kind: kind, data: data, assetID: nil)
    }
}
