import AppKit
import Foundation

@MainActor
struct FileOpening {
    var open: @MainActor (URL) -> Void

    init(open: @escaping @MainActor (URL) -> Void = { url in
        NSWorkspace.shared.open(url)
    }) {
        self.open = open
    }
}
