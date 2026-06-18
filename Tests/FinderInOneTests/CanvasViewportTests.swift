import CoreGraphics
import XCTest
@testable import FinderInOne

final class CanvasViewportTests: XCTestCase {
    func testZoomAroundScreenPointKeepsWorldPointUnderCursor() {
        var viewport = CanvasViewport(scale: 1, offset: CGSize(width: 30, height: 40))
        let cursor = CGPoint(x: 260, y: 180)
        let worldBefore = viewport.worldPoint(forScreenPoint: cursor)

        viewport.zoom(by: 1.25, around: cursor)

        XCTAssertEqual(viewport.scale, 1.25, accuracy: 0.0001)
        XCTAssertEqual(viewport.worldPoint(forScreenPoint: cursor).x, worldBefore.x, accuracy: 0.0001)
        XCTAssertEqual(viewport.worldPoint(forScreenPoint: cursor).y, worldBefore.y, accuracy: 0.0001)
    }

    func testPanMovesViewportOffsetWithoutChangingScale() {
        var viewport = CanvasViewport(scale: 0.8, offset: CGSize(width: 10, height: 20))

        viewport.pan(by: CGSize(width: -40, height: 55))

        XCTAssertEqual(viewport.scale, 0.8)
        XCTAssertEqual(viewport.offset.width, -30)
        XCTAssertEqual(viewport.offset.height, 75)
    }

    func testZoomIsClampedToRecoverableRange() {
        var viewport = CanvasViewport(scale: 1, offset: .zero)

        viewport.zoom(by: 0.01, around: CGPoint(x: 100, y: 100))
        XCTAssertEqual(viewport.scale, CanvasViewport.minimumScale)

        viewport.zoom(by: 100, around: CGPoint(x: 100, y: 100))
        XCTAssertEqual(viewport.scale, CanvasViewport.maximumScale)
    }

    func testResetRestoresDefaultView() {
        var viewport = CanvasViewport(scale: 0.5, offset: CGSize(width: -400, height: 300))

        viewport.reset()

        XCTAssertEqual(viewport.scale, 1)
        XCTAssertEqual(viewport.offset.width, CanvasViewport.defaultOffset.width)
        XCTAssertEqual(viewport.offset.height, CanvasViewport.defaultOffset.height)
    }

    func testResetToWorldRectFitsOffscreenContentInsideViewport() {
        var viewport = CanvasViewport(scale: 1, offset: .zero)
        let worldRect = CGRect(x: -200, y: -120, width: 1200, height: 820)

        viewport.reset(toWorldRect: worldRect, viewportSize: CGSize(width: 900, height: 600))

        let topLeft = viewport.screenPoint(forWorldPoint: worldRect.origin)
        let bottomRight = viewport.screenPoint(
            forWorldPoint: CGPoint(x: worldRect.maxX, y: worldRect.maxY)
        )
        XCTAssertGreaterThanOrEqual(topLeft.x, 20)
        XCTAssertGreaterThanOrEqual(topLeft.y, 20)
        XCTAssertLessThanOrEqual(bottomRight.x, 880)
        XCTAssertLessThanOrEqual(bottomRight.y, 580)
    }
}
