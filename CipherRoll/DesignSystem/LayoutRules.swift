import SwiftUI

enum CipherWidth {
    /// Forms stay near 560 points, including on iPad.
    case form
    /// Library screens use the full detail width when the size class is regular.
    case stage
}

enum CipherLayout {
    static let formMaxWidth: CGFloat = 560

    static func usesSidebar(_ width: UserInterfaceSizeClass?) -> Bool {
        width == .regular
    }
}

enum DeviceCopy {
    static func storageTitle(regularWidth: Bool) -> String {
        regularWidth ? "Your vault lives only on this device" : "Your vault lives only on this iPhone"
    }

    static func storageWarning(regularWidth: Bool) -> String {
        regularWidth
            ? "If this device is reset or replaced, vault items cannot be recovered unless you export a copy first."
            : "If this iPhone is reset or replaced, vault items cannot be recovered unless you export a copy first."
    }

    static func storageRow(regularWidth: Bool) -> String {
        regularWidth ? "Device storage" : "iPhone storage"
    }
}

enum ByteCountCopy {
    static func label(_ bytes: Int) -> String {
        if bytes >= 1_000_000 {
            return String(format: "%.1f MB", Double(bytes) / 1_000_000)
        }
        if bytes >= 1_000 {
            return String(format: "%.0f KB", Double(bytes) / 1_000)
        }
        return "\(bytes) bytes"
    }
}

extension View {
    @ViewBuilder
    func cipherCenteredSheet() -> some View {
        if #available(iOS 18.0, *) {
            self.presentationSizing(.page)
        } else {
            self
        }
    }
}

enum VerticalBar {
    /// True only when UIKit exposes a vertical bar edge. This SDK does not, so iPhone Duo's outer display cannot be detected here.
    static var isActive: Bool {
        UIView.instancesRespond(to: NSSelectorFromString("verticalBarEdge"))
            || UIViewController.instancesRespond(to: NSSelectorFromString("verticalBarEdge"))
    }
}
