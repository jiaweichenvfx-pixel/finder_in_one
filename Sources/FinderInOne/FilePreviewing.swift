import Foundation
import Quartz

@MainActor
struct FilePreviewing {
    var preview: @MainActor ([URL]) -> Void

    init(preview: @escaping @MainActor ([URL]) -> Void = { urls in
        QuickLookPreviewController.shared.preview(urls: urls)
    }) {
        self.preview = preview
    }
}

@MainActor
private final class QuickLookPreviewController: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    static let shared = QuickLookPreviewController()

    private var urls: [URL] = []

    func preview(urls: [URL]) {
        guard !urls.isEmpty, let panel = QLPreviewPanel.shared() else {
            return
        }

        self.urls = urls
        panel.dataSource = self
        panel.delegate = self
        panel.reloadData()
        panel.makeKeyAndOrderFront(nil)
    }

    nonisolated func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        MainActor.assumeIsolated {
            urls.count
        }
    }

    nonisolated func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        MainActor.assumeIsolated {
            urls[index] as NSURL
        }
    }
}
