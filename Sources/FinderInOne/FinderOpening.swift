import AppKit
import Foundation

@MainActor
struct FinderOpening {
    func openInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
