import XCTest
@testable import FinderWorkbenchCore

final class TransferModeTests: XCTestCase {
    func testDefaultModeIsCopy() {
        let controller = TransferModeController()
        XCTAssertEqual(controller.mode, .copy)
        XCTAssertEqual(controller.currentOperation, .copy)
    }

    func testMoveOnceReturnsToCopyAfterOperationCompletes() {
        let controller = TransferModeController()
        controller.enableMoveOnce()

        XCTAssertEqual(controller.mode, .moveOnce)
        XCTAssertEqual(controller.currentOperation, .move)

        controller.operationDidFinish()

        XCTAssertEqual(controller.mode, .copy)
        XCTAssertEqual(controller.currentOperation, .copy)
    }

    func testMoveOnceReturnsToCopyAfterOperationFails() {
        let controller = TransferModeController()
        controller.enableMoveOnce()

        controller.operationDidFail()

        XCTAssertEqual(controller.mode, .copy)
        XCTAssertEqual(controller.currentOperation, .copy)
    }

    func testDeleteModeKeepsCopyAsCurrentTransferOperation() {
        let controller = TransferModeController()
        controller.enableDelete()

        XCTAssertEqual(controller.mode, .delete)
        XCTAssertEqual(controller.currentOperation, .copy)
    }
}
