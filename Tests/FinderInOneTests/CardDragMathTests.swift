import CoreGraphics
import XCTest
@testable import FinderInOne

final class CardDragMathTests: XCTestCase {
    func testWorldTranslationDividesScreenTranslationByViewportScale() {
        let translation = CardDragMath.worldTranslation(
            fromScreenTranslation: CGSize(width: 80, height: -40),
            viewportScale: 2
        )

        XCTAssertEqual(translation.width, 40)
        XCTAssertEqual(translation.height, -20)
    }

    func testWorldTranslationFallsBackToOneForInvalidScale() {
        let translation = CardDragMath.worldTranslation(
            fromScreenTranslation: CGSize(width: 80, height: -40),
            viewportScale: 0
        )

        XCTAssertEqual(translation.width, 80)
        XCTAssertEqual(translation.height, -40)
    }
}
