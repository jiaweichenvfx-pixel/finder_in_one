import CoreGraphics

struct CanvasViewport: Equatable {
    static let minimumScale: CGFloat = 0.35
    static let maximumScale: CGFloat = 1.8
    static let defaultOffset = CGSize(width: 24, height: 24)

    var scale: CGFloat = 1
    var offset: CGSize = Self.defaultOffset

    mutating func zoom(by factor: CGFloat, around screenPoint: CGPoint) {
        guard factor.isFinite,
              factor > 0,
              scale.isFinite,
              scale > 0,
              offset.width.isFinite,
              offset.height.isFinite,
              screenPoint.x.isFinite,
              screenPoint.y.isFinite else {
            return
        }

        let oldScale = scale
        let proposedScale = oldScale * factor
        guard proposedScale.isFinite else {
            return
        }

        let newScale = min(max(proposedScale, Self.minimumScale), Self.maximumScale)
        guard newScale != oldScale else {
            return
        }

        let scaleRatio = newScale / oldScale
        let newOffset = CGSize(
            width: screenPoint.x - (screenPoint.x - offset.width) * scaleRatio,
            height: screenPoint.y - (screenPoint.y - offset.height) * scaleRatio
        )
        guard newOffset.width.isFinite, newOffset.height.isFinite else {
            return
        }

        offset = newOffset
        scale = newScale
    }

    mutating func pan(by delta: CGSize) {
        offset.width += delta.width
        offset.height += delta.height
    }

    mutating func reset() {
        scale = 1
        offset = Self.defaultOffset
    }

    mutating func reset(toWorldRect worldRect: CGRect?, viewportSize: CGSize) {
        guard let worldRect, !worldRect.isNull, worldRect.width > 0, worldRect.height > 0 else {
            reset()
            return
        }

        let padding: CGFloat = 40
        let availableWidth = max(1, viewportSize.width - padding)
        let availableHeight = max(1, viewportSize.height - padding)
        let fitScale = min(availableWidth / worldRect.width, availableHeight / worldRect.height)
        scale = min(max(fitScale, Self.minimumScale), min(Self.maximumScale, 1))

        let scaledWidth = worldRect.width * scale
        let scaledHeight = worldRect.height * scale
        offset = CGSize(
            width: (viewportSize.width - scaledWidth) / 2 - worldRect.minX * scale,
            height: (viewportSize.height - scaledHeight) / 2 - worldRect.minY * scale
        )
    }

    func screenPoint(forWorldPoint worldPoint: CGPoint) -> CGPoint {
        CGPoint(
            x: worldPoint.x * scale + offset.width,
            y: worldPoint.y * scale + offset.height
        )
    }

    func worldPoint(forScreenPoint screenPoint: CGPoint) -> CGPoint {
        CGPoint(
            x: (screenPoint.x - offset.width) / scale,
            y: (screenPoint.y - offset.height) / scale
        )
    }
}
