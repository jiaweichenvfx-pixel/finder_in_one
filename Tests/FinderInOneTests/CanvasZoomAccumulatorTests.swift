import CoreGraphics
import XCTest
@testable import FinderInOne

final class CanvasZoomAccumulatorTests: XCTestCase {
    func testCombinesManyWheelDeltasIntoOneBoundedZoomFactor() throws {
        var accumulator = CanvasZoomAccumulator()

        for _ in 0..<100 {
            accumulator.add(delta: 12)
        }

        let factor = try XCTUnwrap(accumulator.makeZoomFactorAndReset())
        XCTAssertLessThanOrEqual(factor, exp(CanvasZoomAccumulator.maximumAccumulatedDelta * 0.01))
        XCTAssertNil(accumulator.makeZoomFactorAndReset())
    }

    func testIgnoresZeroAndNonFiniteWheelDeltas() {
        var accumulator = CanvasZoomAccumulator()

        accumulator.add(delta: 0)
        accumulator.add(delta: .nan)
        accumulator.add(delta: .infinity)

        XCTAssertNil(accumulator.makeZoomFactorAndReset())
    }
}
