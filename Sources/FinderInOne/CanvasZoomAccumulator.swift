import CoreGraphics

struct CanvasZoomAccumulator {
    static let maximumAccumulatedDelta: CGFloat = 32

    private var accumulatedDelta: CGFloat = 0

    mutating func add(delta: CGFloat) {
        guard delta.isFinite, delta != 0 else {
            return
        }

        accumulatedDelta = min(
            max(accumulatedDelta + delta, -Self.maximumAccumulatedDelta),
            Self.maximumAccumulatedDelta
        )
    }

    mutating func makeZoomFactorAndReset() -> CGFloat? {
        guard accumulatedDelta != 0 else {
            return nil
        }

        let delta = accumulatedDelta
        accumulatedDelta = 0
        return exp(delta * 0.01)
    }
}
