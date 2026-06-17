import XCTest
@testable import FinderWorkbenchCore

final class FolderCardTests: XCTestCase {
    func testLockedCardCannotMoveResizeOrClose() {
        var card = FolderCard(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            displayName: "Projects",
            folderPath: "/Users/test/Projects",
            frame: CardFrame(x: 10, y: 20, width: 300, height: 220),
            isLocked: true
        )

        XCTAssertFalse(card.canMove)
        XCTAssertFalse(card.canResize)
        XCTAssertFalse(card.canClose)

        let moved = card.move(toX: 50, y: 60)
        let resized = card.resize(width: 500, height: 400)

        XCTAssertFalse(moved)
        XCTAssertFalse(resized)
        XCTAssertEqual(card.frame, CardFrame(x: 10, y: 20, width: 300, height: 220))
    }

    func testUnlockedCardCanMoveResizeAndClose() {
        var card = FolderCard(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            displayName: "Client A",
            folderPath: "/Users/test/Client A",
            frame: CardFrame(x: 0, y: 0, width: 240, height: 180),
            isLocked: false
        )

        XCTAssertTrue(card.canMove)
        XCTAssertTrue(card.canResize)
        XCTAssertTrue(card.canClose)
        XCTAssertTrue(card.move(toX: 40, y: 80))
        XCTAssertTrue(card.resize(width: 420, height: 260))
        XCTAssertEqual(card.frame, CardFrame(x: 40, y: 80, width: 420, height: 260))
    }

    func testUnlockedCardResizeClampsToMinimumSize() {
        var card = FolderCard(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            displayName: "Archive",
            folderPath: "/Users/test/Archive",
            frame: CardFrame(x: 0, y: 0, width: 240, height: 180),
            isLocked: false
        )

        XCTAssertTrue(card.resize(width: 1, height: 1))
        XCTAssertEqual(card.frame.width, 180)
        XCTAssertEqual(card.frame.height, 120)
    }
}

extension FolderCardTests {
    func testWorkspaceClosesOnlyUnlockedCards() {
        let lockedID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        let unlockedID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
        var workspace = Workspace(cards: [
            FolderCard(id: lockedID, displayName: "Locked", folderPath: "/tmp/locked", frame: CardFrame(x: 0, y: 0, width: 200, height: 160), isLocked: true),
            FolderCard(id: unlockedID, displayName: "Unlocked", folderPath: "/tmp/unlocked", frame: CardFrame(x: 10, y: 10, width: 200, height: 160), isLocked: false)
        ])

        XCTAssertFalse(workspace.closeCard(id: lockedID))
        XCTAssertTrue(workspace.closeCard(id: unlockedID))
        XCTAssertEqual(workspace.cards.map(\.id), [lockedID])
    }

    func testWorkspaceAllowsMoreThanSixCards() {
        var workspace = Workspace()
        for index in 0..<8 {
            workspace.addCard(FolderCard(
                displayName: "Folder \(index)",
                folderPath: "/tmp/folder-\(index)",
                frame: CardFrame(x: Double(index * 20), y: 0, width: 220, height: 160)
            ))
        }

        XCTAssertEqual(workspace.cards.count, 8)
    }

    func testWorkspaceCloseCardReturnsFalseForUnknownIDAndLeavesCardsUnchanged() {
        let cardID = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
        let unknownID = UUID(uuidString: "66666666-6666-6666-6666-666666666666")!
        let card = FolderCard(
            id: cardID,
            displayName: "Projects",
            folderPath: "/tmp/projects",
            frame: CardFrame(x: 0, y: 0, width: 220, height: 160)
        )
        var workspace = Workspace(cards: [card])

        XCTAssertFalse(workspace.closeCard(id: unknownID))
        XCTAssertEqual(workspace.cards, [card])
    }

    func testWorkspaceUpdateReplacesMatchingCardWithoutAppending() {
        let cardID = UUID(uuidString: "77777777-7777-7777-7777-777777777777")!
        let otherID = UUID(uuidString: "88888888-8888-8888-8888-888888888888")!
        let original = FolderCard(
            id: cardID,
            displayName: "Before",
            folderPath: "/tmp/before",
            frame: CardFrame(x: 0, y: 0, width: 220, height: 160)
        )
        let other = FolderCard(
            id: otherID,
            displayName: "Other",
            folderPath: "/tmp/other",
            frame: CardFrame(x: 10, y: 10, width: 220, height: 160)
        )
        let updated = FolderCard(
            id: cardID,
            displayName: "After",
            folderPath: "/tmp/after",
            frame: CardFrame(x: 20, y: 20, width: 260, height: 180),
            isLocked: true
        )
        var workspace = Workspace(cards: [original, other])

        workspace.updateCard(updated)

        XCTAssertEqual(workspace.cards.count, 2)
        XCTAssertEqual(workspace.cards, [updated, other])
    }
}
