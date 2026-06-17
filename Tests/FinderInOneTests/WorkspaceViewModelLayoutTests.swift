import FinderWorkbenchCore
import XCTest
@testable import FinderInOne

@MainActor
final class WorkspaceViewModelLayoutTests: XCTestCase {
    func testResizeUnlockedCardUpdatesWorkspaceAndPersists() throws {
        let fixture = try WorkspaceViewModelLayoutFixture(isLocked: false)
        defer { fixture.cleanUp() }
        try fixture.saveWorkspace()
        let viewModel = WorkspaceViewModel(store: fixture.store)

        let resized = viewModel.resizeCard(id: fixture.card.id, width: 420, height: 360)

        XCTAssertTrue(resized)
        XCTAssertEqual(viewModel.workspace.cards.first?.frame.width, 420)
        XCTAssertEqual(viewModel.workspace.cards.first?.frame.height, 360)
        XCTAssertEqual(try fixture.store.load().cards.first?.frame.width, 420)
        XCTAssertEqual(try fixture.store.load().cards.first?.frame.height, 360)
    }

    func testResizeLockedCardReturnsFalseAndKeepsFrame() throws {
        let fixture = try WorkspaceViewModelLayoutFixture(isLocked: true)
        defer { fixture.cleanUp() }
        try fixture.saveWorkspace()
        let viewModel = WorkspaceViewModel(store: fixture.store)

        let resized = viewModel.resizeCard(id: fixture.card.id, width: 420, height: 360)

        XCTAssertFalse(resized)
        XCTAssertEqual(viewModel.workspace.cards.first?.frame, fixture.card.frame)
        XCTAssertEqual(try fixture.store.load().cards.first?.frame, fixture.card.frame)
    }

    func testMoveUnlockedCardLaterPersistsOrder() throws {
        let fixture = try WorkspaceViewModelLayoutFixture(isLocked: false)
        defer { fixture.cleanUp() }
        let secondCard = fixture.makeCard(displayName: "Second", isLocked: false)
        try fixture.store.save(Workspace(cards: [fixture.card, secondCard]))
        let viewModel = WorkspaceViewModel(store: fixture.store)

        let moved = viewModel.moveCard(id: fixture.card.id, offset: 1)

        XCTAssertTrue(moved)
        XCTAssertEqual(viewModel.workspace.cards.map(\.id), [secondCard.id, fixture.card.id])
        XCTAssertEqual(try fixture.store.load().cards.map(\.id), [secondCard.id, fixture.card.id])
    }

    func testMoveLockedCardReturnsFalseAndKeepsOrder() throws {
        let fixture = try WorkspaceViewModelLayoutFixture(isLocked: true)
        defer { fixture.cleanUp() }
        let secondCard = fixture.makeCard(displayName: "Second", isLocked: false)
        try fixture.store.save(Workspace(cards: [fixture.card, secondCard]))
        let viewModel = WorkspaceViewModel(store: fixture.store)

        let moved = viewModel.moveCard(id: fixture.card.id, offset: 1)

        XCTAssertFalse(moved)
        XCTAssertEqual(viewModel.workspace.cards.map(\.id), [fixture.card.id, secondCard.id])
        XCTAssertEqual(try fixture.store.load().cards.map(\.id), [fixture.card.id, secondCard.id])
    }

    func testAddFolderURLCreatesCardRefreshesAndPersists() throws {
        let fixture = try WorkspaceViewModelLayoutFixture(isLocked: false)
        defer { fixture.cleanUp() }
        let externalFolder = try fixture.createFolder(named: "External")
        try "hello".write(to: externalFolder.appendingPathComponent("note.txt"), atomically: true, encoding: .utf8)
        let viewModel = WorkspaceViewModel(store: fixture.store)

        let added = viewModel.addFolder(url: externalFolder)

        let card = try XCTUnwrap(added)
        XCTAssertEqual(card.displayName, "External")
        XCTAssertEqual(card.folderPath, externalFolder.path)
        XCTAssertEqual(viewModel.itemsByCardID[card.id]?.map(\.name), ["note.txt"])
        XCTAssertEqual(try fixture.store.load().cards.map(\.folderPath), [externalFolder.path])
    }
}

private struct WorkspaceViewModelLayoutFixture {
    let root: URL
    let folderURL: URL
    let store: WorkspaceStore
    let card: FolderCard

    init(isLocked: Bool, filePath: String = #filePath) throws {
        root = try Self.packageRoot(filePath: filePath)
            .appendingPathComponent(".finder-workbench-demo-folders-test", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        folderURL = root.appendingPathComponent("Card", isDirectory: true)
        store = WorkspaceStore(fileURL: root.appendingPathComponent("workspace.json"))
        card = FolderCard(
            displayName: "Card",
            folderPath: folderURL.path,
            frame: CardFrame(x: 0, y: 0, width: 360, height: 240),
            isLocked: isLocked
        )

        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
    }

    func saveWorkspace() throws {
        try store.save(Workspace(cards: [card]))
    }

    func makeCard(displayName: String, isLocked: Bool) -> FolderCard {
        FolderCard(
            displayName: displayName,
            folderPath: root.appendingPathComponent(displayName, isDirectory: true).path,
            frame: CardFrame(x: 0, y: 0, width: 360, height: 240),
            isLocked: isLocked
        )
    }

    func createFolder(named name: String) throws -> URL {
        let url = root.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func cleanUp() {
        try? FileManager.default.removeItem(at: root)
    }

    private static func packageRoot(filePath: String) throws -> URL {
        var directory = URL(fileURLWithPath: filePath)
            .deletingLastPathComponent()
            .standardizedFileURL

        while directory.path != "/" {
            let packageFile = directory.appendingPathComponent("Package.swift")
            if FileManager.default.fileExists(atPath: packageFile.path) {
                return directory
            }
            directory.deleteLastPathComponent()
        }

        throw XCTSkip("Package root could not be resolved from test file path.")
    }
}
