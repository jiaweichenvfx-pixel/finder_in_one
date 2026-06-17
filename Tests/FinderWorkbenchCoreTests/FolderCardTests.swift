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
}
