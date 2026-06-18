import AppKit
import SwiftUI

struct CanvasInputView: NSViewRepresentable {
    var onZoom: (CGFloat, CGPoint) -> Void
    var onPan: (CGSize) -> Void

    func makeNSView(context: Context) -> CanvasInputNSView {
        let view = CanvasInputNSView()
        view.onZoom = onZoom
        view.onPan = onPan
        return view
    }

    func updateNSView(_ nsView: CanvasInputNSView, context: Context) {
        nsView.onZoom = onZoom
        nsView.onPan = onPan
    }
}

final class CanvasInputNSView: NSView {
    var onZoom: ((CGFloat, CGPoint) -> Void)?
    var onPan: ((CGSize) -> Void)?
    private var middleMouseMonitor: Any?

    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func scrollWheel(with event: NSEvent) {
        let zoomDelta = event.scrollingDeltaY == 0 ? -event.scrollingDeltaX : event.scrollingDeltaY
        guard zoomDelta != 0 else {
            super.scrollWheel(with: event)
            return
        }

        let factor = exp(zoomDelta * 0.01)
        onZoom?(factor, convert(event.locationInWindow, from: nil))
    }

    override func otherMouseDragged(with event: NSEvent) {
        guard event.buttonNumber == 2 else {
            super.otherMouseDragged(with: event)
            return
        }
        onPan?(CGSize(width: event.deltaX, height: event.deltaY))
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            stopMiddleMouseMonitor()
        } else {
            startMiddleMouseMonitor()
        }
    }

    private func startMiddleMouseMonitor() {
        guard middleMouseMonitor == nil else {
            return
        }

        middleMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.otherMouseDragged]) { [weak self] event in
            guard let self,
                  event.window === self.window,
                  event.buttonNumber == 2 else {
                return event
            }

            self.onPan?(CGSize(width: event.deltaX, height: event.deltaY))
            return nil
        }
    }

    private func stopMiddleMouseMonitor() {
        guard let middleMouseMonitor else {
            return
        }
        NSEvent.removeMonitor(middleMouseMonitor)
        self.middleMouseMonitor = nil
    }
}
