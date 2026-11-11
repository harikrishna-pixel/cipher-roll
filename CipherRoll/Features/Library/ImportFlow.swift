import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ImportContainer: View {
    @ObservedObject var library: LibraryModel
    var isOnboarding = false
    var onOnboardingFinished: (() -> Void)? = nil
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showPicker = false
    @State private var showFiles = false
    @State private var showCamera = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        CipherScreen {
            Group {
                switch library.importScreen {
                case .add, .none:
                    addSheet
                case .overLimit(let kind, let selected, let allowed):
                    overLimit(kind: kind, selected: selected, allowed: allowed)
                case .progress:
                    progress
                case .paused(let imported, let waiting):
                    paused(imported: imported, waiting: waiting)
                case .done(let count, let originals):
                    done(count: count, originals: originals)
                }
            }
        }
        .photosPicker(isPresented: $showPicker, selection: $pickerItems, matching: .any(of: [.images, .videos]))
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result {
                let files = urls.compactMap(PendingImportLoader.file)
                let kind: ItemKind = files.contains { $0.kind == .video } && files.allSatisfy { $0.kind == .video } ? .video : .file
                library.prepare(files: files, kind: kind)
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraCapture { image in
                if let pending = PendingImportLoader.photo(image, name: "Photo.jpg") {
                    library.prepare(files: [pending], kind: .photo)
                }
            }
        }
        .onChange(of: pickerItems) { items in
            guard !items.isEmpty else { return }
            Task { await loadPicker(items) }
        }
        .onAppear {
            if isOnboarding, library.importScreen == .add || library.importScreen == nil {
                // Brief delay so the step change finishes before the sheet presents.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    showPicker = true
                }
            }
        }
    }

    private var addSheet: some View {
        VStack(alignment: .leading, spacing: CipherSpace.s16) {
            HStack {
                Button {
                    finishOnboardingIfNeeded()
                    library.importScreen = nil
                } label: {
                    Image(systemName: "xmark").frame(width: 44, height: 44).background(CipherColor.card, in: Circle())
                }
                .accessibilityLabel(isOnboarding ? "Skip" : "Close")
                Spacer()
                Text(isOnboarding ? "Choose photos to lock" : "Add to Personal")
                    .font(CipherFont.h2)
                    .foregroundStyle(CipherColor.ink)
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            HStack(spacing: CipherSpace.s8) {
                sourceButton("Photos", "photo") { showPicker = true }
                sourceButton("Camera", "camera") {
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        showCamera = true
                    } else {
                        library.message = "Camera is not available on this device."
                    }
                }
                sourceButton("Files", "folder") { showFiles = true }
            }
            HStack(spacing: CipherSpace.s8) {
                limitChip("Photos", library.counts.photos, 100)
                limitChip("Videos", library.counts.videos, 10)
            }
            Text("Afterwards you can choose to remove the originals from Photos.")
                .font(CipherFont.caption)
                .foregroundStyle(CipherColor.sub)
            Button("Add a note") {
                library.importScreen = nil
                library.requestedPage = .note(nil)
            }
                .font(CipherFont.button)
                .foregroundStyle(CipherColor.link)
                .frame(minHeight: 44)
            Spacer()
        }
        .padding(CipherSpace.s20)
    }

    private func overLimit(kind: ItemKind, selected: Int, allowed: Int) -> some View {
        VStack(alignment: .leading, spacing: CipherSpace.s16) {
            Text("\(selected) \(FreePlanChip.label(kind)) selected, Free allows \(allowed) more")
                .font(CipherFont.h2)
                .foregroundStyle(CipherColor.ink)
            Text("Reduce your selection, or a plan removes CipherRoll limits. This import will add \(allowed).")
                .font(CipherFont.body)
                .foregroundStyle(CipherColor.sub)
            Button(allowed == 0 ? "Close" : "Import \(ItemCountCopy.label(allowed))") {
                if allowed == 0 { library.importScreen = nil } else { library.startImport(source: "photos") }
            }
            .buttonStyle(CipherGoldButtonStyle())
            .disabled(allowed == 0)
            Button("See plans") { library.noteLimit(kind) }
                .font(CipherFont.button)
                .foregroundStyle(CipherColor.link)
                .frame(minHeight: 44)
            Text("Nothing is removed from Photos until you choose that after a finished import.")
                .font(CipherFont.caption)
                .foregroundStyle(CipherColor.sub)
        }
        .padding(CipherSpace.s24)
    }

    private var progress: some View {
        let total = max(library.importTotal, 1)
        let fraction = CGFloat(library.importedCount) / CGFloat(total)
        return VStack(spacing: CipherSpace.s16) {
            Text("Importing to Personal").font(CipherFont.h2).foregroundStyle(CipherColor.ink)
            ZStack {
                Circle()
                    .stroke(CipherColor.line, lineWidth: 10)
                Circle()
                    .trim(from: 0, to: max(fraction, 0.02))
                    .stroke(CipherColor.ink, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 4) {
                    Text("\(library.importedCount) of \(library.importTotal)")
                        .font(CipherFont.title)
                        .foregroundStyle(CipherColor.ink)
                    Text("items locked")
                        .font(CipherFont.caption)
                        .foregroundStyle(CipherColor.sub)
                }
            }
            .frame(width: 168, height: 168)
            .accessibilityLabel("\(library.importedCount) of \(library.importTotal) items locked")
            Text("Keep CipherRoll open. Your originals stay in Photos until you choose.")
                .font(CipherFont.body)
                .foregroundStyle(CipherColor.sub)
                .multilineTextAlignment(.center)
            VStack(spacing: 0) {
                ForEach(Array(library.rows.prefix(6).enumerated()), id: \.element.id) { index, row in
                    if index > 0 { Divider() }
                    progressRow(row)
                }
            }
            .padding(.horizontal, CipherSpace.s16)
            .background(CipherColor.card, in: RoundedRectangle(cornerRadius: CipherRadius.card))
            .overlay(RoundedRectangle(cornerRadius: CipherRadius.card).stroke(CipherColor.line, lineWidth: 1))
            Spacer()
            Button("Cancel import") { library.cancelImportNow() }
                .font(CipherFont.button)
                .foregroundStyle(CipherColor.sub)
                .frame(minHeight: 44)
        }
        .padding(CipherSpace.s24)
    }

    private func progressRow(_ row: ImportRow) -> some View {
        HStack(spacing: CipherSpace.s12) {
            thumb(row.thumb)
            VStack(alignment: .leading, spacing: 6) {
                Text(row.name)
                    .font(CipherFont.button)
                    .foregroundStyle(CipherColor.ink)
                    .lineLimit(1)
                if case .working(let value) = row.state {
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(CipherColor.line)
                            Capsule().fill(CipherColor.ink).frame(width: proxy.size.width * CGFloat(value))
                        }
                    }
                    .frame(height: 4)
                }
            }
            Spacer(minLength: 8)
            Text(label(row.state))
                .font(CipherFont.caption)
                .foregroundStyle(row.state == .locked ? CipherColor.ink : CipherColor.sub)
        }
        .padding(.vertical, CipherSpace.s12)
        .accessibilityElement(children: .combine)
    }

    private func thumb(_ image: UIImage?) -> some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                CipherIcon.image.image
                    .foregroundStyle(CipherColor.tintInk)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(CipherColor.tint)
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityHidden(true)
    }

    private func paused(imported: Int, waiting: Int) -> some View {
        VStack(alignment: .leading, spacing: CipherSpace.s16) {
            Text("Import paused").font(CipherFont.h2).foregroundStyle(CipherColor.ink).frame(maxWidth: .infinity)
            Text("Not enough iPhone storage")
                .font(CipherFont.title)
                .foregroundStyle(CipherColor.ink)
            Text("\(imported) items were imported safely. \(waiting) were not moved. Your originals are untouched in Photos.")
                .font(CipherFont.body)
                .foregroundStyle(CipherColor.sub)
            Text("\(imported) imported and locked").font(CipherFont.button).foregroundStyle(CipherColor.ink)
            Text("\(waiting) waiting to import").font(CipherFont.button).foregroundStyle(CipherColor.ink)
            Text("Free up space in iPhone Settings, then try again. Nothing was deleted.")
                .font(CipherFont.caption)
                .foregroundStyle(CipherColor.sub)
            Spacer()
            Button("Close") { library.importScreen = nil }.buttonStyle(CipherGoldButtonStyle())
        }
        .padding(CipherSpace.s24)
    }

    private func done(count: Int, originals: Int) -> some View {
        VStack(spacing: CipherSpace.s16) {
            ZStack {
                Circle().fill(CipherColor.card).frame(width: 96, height: 96)
                Circle().fill(CipherColor.tint).frame(width: 64, height: 64)
                Image(systemName: "checkmark")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(CipherColor.tintInk)
            }
            .accessibilityHidden(true)
            Text("\(count) items imported.")
                .font(CipherFont.title)
                .foregroundStyle(CipherColor.ink)
            Text("Locked in CipherRoll.")
                .font(CipherFont.body)
                .foregroundStyle(CipherColor.sub)
            HStack(spacing: CipherSpace.s8) {
                ForEach(Array(library.rows.prefix(4))) { row in
                    thumb(row.thumb)
                        .frame(width: 64, height: 64)
                }
            }
            if originals > 0 {
                VStack(alignment: .leading, spacing: CipherSpace.s12) {
                    HStack(alignment: .top, spacing: CipherSpace.s12) {
                        CipherIcon.image.image
                            .foregroundStyle(CipherColor.tintInk)
                            .frame(width: 40, height: 40)
                            .background(CipherColor.tint, in: RoundedRectangle(cornerRadius: 10))
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: CipherSpace.s8) {
                            Text("Delete \(originals) originals from Photos?")
                                .font(CipherFont.button)
                                .foregroundStyle(CipherColor.ink)
                            Text("They are still in your camera roll. If you delete them, iOS keeps them in Recently Deleted for about 30 days. With iCloud Photos on, they are removed on your other devices too.")
                                .font(CipherFont.caption)
                                .foregroundStyle(CipherColor.sub)
                        }
                    }
                    HStack(spacing: CipherSpace.s12) {
                        Button("Review and delete") {
                            library.deleteImportedOriginals()
                            finishOnboardingIfNeeded()
                        }
                        .buttonStyle(CipherOutlineButtonStyle())
                        Button("Keep originals") {
                            library.keepOriginals()
                            finishOnboardingIfNeeded()
                        }
                        .font(CipherFont.button)
                        .foregroundStyle(CipherColor.link)
                        .frame(minHeight: 44)
                    }
                }
                .padding(CipherSpace.s16)
                .background(CipherColor.card, in: RoundedRectangle(cornerRadius: CipherRadius.card))
                .overlay(RoundedRectangle(cornerRadius: CipherRadius.card).stroke(CipherColor.line, lineWidth: 1))
            }
            Spacer()
            Button("Continue") {
                library.keepOriginals()
                finishOnboardingIfNeeded()
            }
            .buttonStyle(CipherGoldButtonStyle())
        }
        .padding(CipherSpace.s24)
    }

    private func finishOnboardingIfNeeded() {
        guard isOnboarding else { return }
        onOnboardingFinished?()
    }

    private func sourceButton(_ title: String, _ symbol: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(CipherFont.button)
                .foregroundStyle(CipherColor.ink)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(CipherColor.tint, in: Capsule())
        }
    }

    private func limitChip(_ title: String, _ used: Int, _ limit: Int) -> some View {
        Text("\(title): \(max(0, limit - used)) left")
            .font(CipherFont.caption)
            .foregroundStyle(CipherColor.ink)
            .padding(.horizontal, 12)
            .frame(minHeight: 32)
            .background(CipherColor.card, in: Capsule())
            .overlay(Capsule().stroke(CipherColor.line, lineWidth: 1))
    }

    private func label(_ state: ImportRow.State) -> String {
        switch state {
        case .waiting: "Waiting"
        case .working(let value): "\(Int((value * 100).rounded()))%"
        case .locked: "Locked"
        case .skipped: "Skipped"
        }
    }

    private func loadPicker(_ items: [PhotosPickerItem]) async {
        var pending: [PendingImport] = []
        for item in items {
            if let movie = try? await item.loadTransferable(type: VideoFile.self),
               let data = try? Data(contentsOf: movie.url), !data.isEmpty {
                pending.append(PendingImport(name: "Video.mov", kind: .video, data: data, assetID: item.itemIdentifier))
                try? FileManager.default.removeItem(at: movie.url)
            } else if let photo = try? await item.loadTransferable(type: ImportPhoto.self), !photo.data.isEmpty {
                pending.append(PendingImport(name: "Photo.jpg", kind: .photo, data: photo.data, assetID: item.itemIdentifier))
            } else if let data = try? await item.loadTransferable(type: Data.self), !data.isEmpty {
                pending.append(PendingImport(name: "Photo.jpg", kind: .photo, data: data, assetID: item.itemIdentifier))
            }
        }
        pickerItems = []
        guard !pending.isEmpty else {
            library.message = "Those photos could not be imported. Try again."
            return
        }
        let kind: ItemKind = pending.allSatisfy { $0.kind == .video } ? .video : .photo
        library.prepare(files: pending, kind: kind)
    }
}

struct ImportPhoto: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { data in
            ImportPhoto(data: data)
        }
        DataRepresentation(importedContentType: .jpeg) { data in
            ImportPhoto(data: data)
        }
        DataRepresentation(importedContentType: .png) { data in
            ImportPhoto(data: data)
        }
        DataRepresentation(importedContentType: .heic) { data in
            ImportPhoto(data: data)
        }
    }
}

struct VideoFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { file in
            SentTransferredFile(file.url)
        } importing: { received in
            let copy = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
            try FileManager.default.copyItem(at: received.file, to: copy)
            return VideoFile(url: copy)
        }
    }
}

struct CameraCapture: UIViewControllerRepresentable {
    var onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraCapture
        init(_ parent: CameraCapture) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { parent.onImage(image) }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
