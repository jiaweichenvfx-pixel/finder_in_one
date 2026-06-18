import Foundation
import Quartz

@MainActor
struct FilePreviewing {
    var preview: @MainActor ([URL], Int) -> Void

    init(preview: @escaping @MainActor ([URL], Int) -> Void = { urls, selectedIndex in
        QuickLookPreviewController.shared.preview(urls: urls, selectedIndex: selectedIndex)
    }) {
        self.preview = preview
    }

    init(_ preview: @escaping @MainActor ([URL]) -> Void) {
        self.preview = { urls, _ in preview(urls) }
    }

    static var isPreviewVisible: Bool {
        QLPreviewPanel.shared()?.isVisible == true
    }
}

@MainActor
private final class QuickLookPreviewController: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    static let shared = QuickLookPreviewController()

    private var urls: [URL] = []
    private var selectedIndex: Int = 0
    private var keyMonitor: Any?

    func preview(urls: [URL], selectedIndex: Int) {
        guard !urls.isEmpty, let panel = QLPreviewPanel.shared() else {
            return
        }

        self.urls = urls
        self.selectedIndex = min(max(selectedIndex, 0), urls.count - 1)
        startKeyMonitor()
        panel.dataSource = self
        panel.delegate = self
        panel.reloadData()
        panel.currentPreviewItemIndex = self.selectedIndex
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

    private func startKeyMonitor() {
        guard keyMonitor == nil else {
            return
        }

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self else {
                return event
            }
            var handledEvent: NSEvent? = event
            MainActor.assumeIsolated {
                handledEvent = self.handlePreviewKey(event)
            }
            return handledEvent
        }
    }

    private func handlePreviewKey(_ event: NSEvent) -> NSEvent? {
        guard urls.count > 1,
              let panel = QLPreviewPanel.shared(),
              panel.isVisible else {
            return event
        }

        switch event.keyCode {
        case 126:
            panel.currentPreviewItemIndex = max(panel.currentPreviewItemIndex - 1, 0)
            return nil
        case 125:
            panel.currentPreviewItemIndex = min(panel.currentPreviewItemIndex + 1, urls.count - 1)
            return nil
        default:
            return event
        }
    }
}
