import AVFoundation
import Foundation
import UIKit

struct BreakInPhoto: Identifiable, Equatable {
    var id: String
    var url: URL
    var date: Date
}

enum BreakInStore {
    static func folder() -> URL? {
        guard let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first else { return nil }
        return library.appendingPathComponent("CipherRoll/BreakIn", isDirectory: true)
    }

    static func photos() -> [BreakInPhoto] {
        guard let folder = folder(),
              let urls = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.creationDateKey]) else {
            return []
        }
        return urls.filter { $0.pathExtension == "jpg" }.compactMap { url in
            let date = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date()
            return BreakInPhoto(id: url.lastPathComponent, url: url, date: date)
        }
        .sorted { $0.date > $1.date }
    }

    static func delete(_ photo: BreakInPhoto) {
        try? FileManager.default.removeItem(at: photo.url)
    }

    static func capture() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let folder = folder() else { return }
        let session = AVCaptureSession()
        session.sessionPreset = .photo
        guard let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else { return }
        session.addInput(input)
        let output = AVCapturePhotoOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        let delegate = BreakInCapture(folder: folder, session: session)
        BreakInCapture.keep = delegate
        session.startRunning()
        let settings = AVCapturePhotoSettings()
        output.capturePhoto(with: settings, delegate: delegate)
    }
}

private final class BreakInCapture: NSObject, AVCapturePhotoCaptureDelegate {
    static var keep: BreakInCapture?
    let folder: URL
    let session: AVCaptureSession

    init(folder: URL, session: AVCaptureSession) {
        self.folder = folder
        self.session = session
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        defer {
            session.stopRunning()
            BreakInCapture.keep = nil
        }
        guard let data = photo.fileDataRepresentation() else { return }
        let url = folder.appendingPathComponent("\(UUID().uuidString).jpg")
        try? ProtectedFile.write(data, to: url)
    }
}
