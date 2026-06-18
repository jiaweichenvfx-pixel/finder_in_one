import AppKit
import Foundation

@MainActor
struct FinderOpening {
    var openInFinder: @MainActor ([URL], URL) -> Void

    init(openInFinder: @escaping @MainActor ([URL], URL) -> Void = { selectedURLs, folderURL in
        if selectedURLs.isEmpty {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: folderURL.path)
        } else {
            NSWorkspace.shared.activateFileViewerSelecting(selectedURLs)
        }
    }) {
        self.openInFinder = openInFinder
    }

    init(_ openInFinder: @escaping @MainActor (URL, [URL]) -> Void) {
        self.openInFinder = { selectedURLs, folderURL in
            openInFinder(folderURL, selectedURLs)
        }
    }

    func open(folderURL: URL, selectedURLs: [URL]) {
        openInFinder(selectedURLs, folderURL)
    }
}
