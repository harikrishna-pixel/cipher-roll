import PhosphorSwift
import SwiftUI

/// Bold Phosphor icons from the handoff. Names follow doc 11 section 2.
enum CipherIcon: String, CaseIterable, Identifiable {
    case lock
    case image
    case video
    case file
    case note
    case key
    case eye
    case face
    case shield
    case search
    case share

    var id: String { rawValue }

    var accessibilityLabel: String {
        switch self {
        case .lock: "Lock"
        case .image: "Photo"
        case .video: "Video"
        case .file: "File"
        case .note: "Note"
        case .key: "Key"
        case .eye: "Hidden"
        case .face: "Biometrics"
        case .shield: "Shield"
        case .search: "Search"
        case .share: "Share"
        }
    }

    var image: Image {
        switch self {
        case .lock: Ph.lockSimple.bold
        case .image: Ph.imageSquare.bold
        case .video: Ph.videoCamera.bold
        case .file: Ph.fileText.bold
        case .note: Ph.notePencil.bold
        case .key: Ph.key.bold
        case .eye: Ph.eyeSlash.bold
        case .face: Ph.scanSmiley.bold
        case .shield: Ph.shieldCheck.bold
        case .search: Ph.magnifyingGlass.bold
        case .share: Ph.export.bold
        }
    }
}
