import AppKit
import FinderWorkbenchCore
import SwiftUI
import XCTest
@testable import FinderInOne

final class TransferModeDragOperationTests: XCTestCase {
    func testCopyModeAdvertisesCopyDragOperation() {
        XCTAssertEqual(TransferMode.copy.dragOperation, .copy)
    }

    func testMoveOnceModeAdvertisesMoveDragOperation() {
        XCTAssertEqual(TransferMode.moveOnce.dragOperation, .move)
    }

    func testCopyModeAdvertisesCopyDropProposalOperation() {
        XCTAssertEqual(TransferMode.copy.dropProposalOperation, .copy)
    }

    func testMoveOnceModeAdvertisesMoveDropProposalOperation() {
        XCTAssertEqual(TransferMode.moveOnce.dropProposalOperation, .move)
    }
}
