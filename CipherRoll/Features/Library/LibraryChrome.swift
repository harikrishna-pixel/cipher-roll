import SwiftUI

func kindIcon(_ kind: ItemKind) -> Image {
    switch kind {
    case .photo: CipherIcon.image.image
    case .video: CipherIcon.video.image
    case .file: CipherIcon.file.image
    case .note: CipherIcon.note.image
    }
}

func kindTitle(_ kind: ItemKind) -> String {
    switch kind {
    case .photo: "Photos"
    case .video: "Videos"
    case .file: "Files"
    case .note: "Notes"
    }
}
