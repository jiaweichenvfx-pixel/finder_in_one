import XCTest
@testable import FinderInOne

final class FolderCardDragPresentationTests: XCTestCase {
    func testMovingCardKeepsFileContentVisibleButSuspendsInteraction() {
        let presentation = FolderCardDragPresentation(isMoving: true)

        XCTAssertTrue(presentation.showsFileContent)
        XCTAssertFalse(presentation.allowsFileInteraction)
    }

    func testIdleCardShowsInteractiveFileContent() {
        let presentation = FolderCardDragPresentation(isMoving: false)

        XCTAssertTrue(presentation.showsFileContent)
        XCTAssertTrue(presentation.allowsFileInteraction)
    }
}
