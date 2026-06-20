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

    func testMoveUnlockedCardToPositionPersistsFrame() throws {
        let fixture = try WorkspaceViewModelLayoutFixture(isLocked: false)
        defer { fixture.cleanUp() }
        try fixture.saveWorkspace()
        let viewModel = WorkspaceViewModel(store: fixture.store)

        let moved = viewModel.moveCard(id: fixture.card.id, x: 120, y: 80)

        XCTAssertTrue(moved)
        XCTAssertEqual(viewModel.workspace.cards.first?.frame.x, 120)
        XCTAssertEqual(viewModel.workspace.cards.first?.frame.y, 80)
        XCTAssertEqual(try fixture.store.load().cards.first?.frame.x, 120)
        XCTAssertEqual(try fixture.store.load().cards.first?.frame.y, 80)
    }

    func testLiveMoveUpdatesWorkspaceWithoutPersistingUntilCommit() throws {
        let fixture = try WorkspaceViewModelLayoutFixture(isLocked: false)
        defer { fixture.cleanUp() }
        try fixture.saveWorkspace()
        let viewModel = WorkspaceViewModel(store: fixture.store)

        let liveMoved = viewModel.moveCard(id: fixture.card.id, x: 120, y: 80, persist: false)

        XCTAssertTrue(liveMoved)
        XCTAssertEqual(viewModel.workspace.cards.first?.frame.x, 120)
        XCTAssertEqual(viewModel.workspace.cards.first?.frame.y, 80)
        XCTAssertEqual(try fixture.store.load().cards.first?.frame, fixture.card.frame)

        let committed = viewModel.moveCard(id: fixture.card.id, x: 160, y: 100, persist: true)

        XCTAssertTrue(committed)
        XCTAssertEqual(try fixture.store.load().cards.first?.frame.x, 160)
        XCTAssertEqual(try fixture.store.load().cards.first?.frame.y, 100)
    }

    func testMoveLockedCardToPositionReturnsFalseAndKeepsFrame() throws {
        let fixture = try WorkspaceViewModelLayoutFixture(isLocked: true)
        defer { fixture.cleanUp() }
        try fixture.saveWorkspace()
        let viewModel = WorkspaceViewModel(store: fixture.store)

        let moved = viewModel.moveCard(id: fixture.card.id, x: 120, y: 80)

        XCTAssertFalse(moved)
        XCTAssertEqual(viewModel.workspace.cards.first?.frame, fixture.card.frame)
        XCTAssertEqual(try fixture.store.load().cards.first?.frame, fixture.card.frame)
    }

    func testLiveResizeUpdatesWorkspaceWithoutPersistingUntilCommit() throws {
        let fixture = try WorkspaceViewModelLayoutFixture(isLocked: false)
        defer { fixture.cleanUp() }
        try fixture.saveWorkspace()
        let viewModel = WorkspaceViewModel(store: fixture.store)

        let liveResized = viewModel.resizeCard(id: fixture.card.id, width: 420, height: 360, persist: false)

        XCTAssertTrue(liveResized)
        XCTAssertEqual(viewModel.workspace.cards.first?.frame.width, 420)
        XCTAssertEqual(viewModel.workspace.cards.first?.frame.height, 360)
        XCTAssertEqual(try fixture.store.load().cards.first?.frame, fixture.card.frame)

        let committed = viewModel.resizeCard(id: fixture.card.id, width: 440, height: 380, persist: true)

        XCTAssertTrue(committed)
        XCTAssertEqual(try fixture.store.load().cards.first?.frame.width, 440)
        XCTAssertEqual(try fixture.store.load().cards.first?.frame.height, 380)
    }

    func testSelectionStateSupportsMultipleItemsPerCard() throws {
        let fixture = try WorkspaceViewModelLayoutFixture(isLocked: false)
        defer { fixture.cleanUp() }
        try fixture.saveWorkspace()
        let viewModel = WorkspaceViewModel(store: fixture.store)
        let firstURL = fixture.folderURL.appendingPathComponent("first.txt")
        let secondURL = fixture.folderURL.appendingPathComponent("second.txt")

        viewModel.setSelectedItemURLs([firstURL, secondURL], for: fixture.card.id)

        XCTAssertEqual(viewModel.selectedItemURLsByCardID[fixture.card.id], [firstURL, secondURL])
    }

    func testSuffixFilterShowsOnlyMatchingFilesAndKeepsFoldersVisible() throws {
        let fixture = try WorkspaceViewModelLayoutFixture(isLocked: false)
        defer { fixture.cleanUp() }
        try fixture.createFile(in: fixture.folderURL, named: "plate.mov", contents: "mov")
        try fixture.createFile(in: fixture.folderURL, named: "notes.txt", contents: "txt")
        try fixture.createFile(in: fixture.folderURL, named: "look.JPG", contents: "jpg")
        try fixture.createFolder(in: fixture.folderURL, named: "Shots")
        try fixture.saveWorkspace()
        let viewModel = WorkspaceViewModel(store: fixture.store)

        viewModel.setSuffixFilter(".mov, jpg", for: fixture.card.id)

        XCTAssertEqual(viewModel.suffixFilterTextByCardID[fixture.card.id], ".mov, jpg")
        XCTAssertEqual(viewModel.displayedItems(for: fixture.card).map(\.name), ["Shots", "look.JPG", "plate.mov"])
    }

    func testEmptySuffixFilterShowsAllItems() throws {
        let fixture = try WorkspaceViewModelLayoutFixture(isLocked: false)
        defer { fixture.cleanUp() }
        try fixture.createFile(in: fixture.folderURL, named: "plate.mov", contents: "mov")
        try fixture.createFile(in: fixture.folderURL, named: "notes.txt", contents: "txt")
        try fixture.saveWorkspace()
        let viewModel = WorkspaceViewModel(store: fixture.store)

        viewModel.setSuffixFilter("mov", for: fixture.card.id)
        viewModel.setSuffixFilter("", for: fixture.card.id)

        XCTAssertNil(viewModel.suffixFilterTextByCardID[fixture.card.id])
        XCTAssertEqual(viewModel.displayedItems(for: fixture.card).map(\.name), ["notes.txt", "plate.mov"])
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

    func testAddFolderURLFocusesExistingCardWhenFolderAlreadyExists() throws {
        let fixture = try WorkspaceViewModelLayoutFixture(isLocked: false)
        defer { fixture.cleanUp() }
        try fixture.saveWorkspace()
        let viewModel = WorkspaceViewModel(store: fixture.store, templateStore: fixture.templateStore)

        let added = viewModel.addFolder(url: fixture.folderURL)

        XCTAssertEqual(added?.id, fixture.card.id)
        XCTAssertEqual(viewModel.workspace.cards, [fixture.card])
        XCTAssertEqual(viewModel.focusedCardID, fixture.card.id)
        XCTAssertEqual(try fixture.store.load().cards, [fixture.card])
    }

    func testAddDroppedFolderURLsAddsOnlyDirectoriesAtDropPoint() throws {
        let fixture = try WorkspaceViewModelLayoutFixture(isLocked: false)
        defer { fixture.cleanUp() }
        let folder = try fixture.createFolder(named: "FinderWindow")
        let file = try fixture.createFile(named: "loose-file.txt", contents: "ignore")
        let viewModel = WorkspaceViewModel(store: fixture.store, templateStore: fixture.templateStore)

        let added = viewModel.addDroppedFolderURLs([file, folder], at: CGPoint(x: 180, y: 120))

        XCTAssertTrue(added)
        XCTAssertEqual(viewModel.workspace.cards.count, 1)
        let card = try XCTUnwrap(viewModel.workspace.cards.first)
        XCTAssertEqual(card.displayName, "FinderWindow")
        XCTAssertEqual(card.folderPath, folder.path)
        XCTAssertEqual(card.frame.x, 180)
        XCTAssertEqual(card.frame.y, 120)
        XCTAssertEqual(try fixture.store.load().cards.map(\.folderPath), [folder.path])
    }

    func testAddDroppedFileURLsIgnoresNonDirectories() throws {
        let fixture = try WorkspaceViewModelLayoutFixture(isLocked: false)
        defer { fixture.cleanUp() }
        let file = try fixture.createFile(named: "loose-file.txt", contents: "ignore")
        let viewModel = WorkspaceViewModel(store: fixture.store, templateStore: fixture.templateStore)

        let added = viewModel.addDroppedFolderURLs([file], at: CGPoint(x: 180, y: 120))

        XCTAssertFalse(added)
        XCTAssertTrue(viewModel.workspace.cards.isEmpty)
        XCTAssertTrue(try fixture.store.load().cards.isEmpty)
    }

    func testAddDroppedChildFolderFromExistingCardCreatesNewFolderCard() throws {
        let fixture = try WorkspaceViewModelLayoutFixture(isLocked: false)
        defer { fixture.cleanUp() }
        let childFolder = fixture.folderURL.appendingPathComponent("Shots", isDirectory: true)
        try FileManager.default.createDirectory(at: childFolder, withIntermediateDirectories: true)
        try fixture.saveWorkspace()
        let viewModel = WorkspaceViewModel(store: fixture.store, templateStore: fixture.templateStore)

        let added = viewModel.addDroppedFolderURLs([childFolder], at: CGPoint(x: 420, y: 260))

        XCTAssertTrue(added)
        XCTAssertEqual(viewModel.workspace.cards.map(\.folderPath), [fixture.folderURL.path, childFolder.path])
        let childCard = try XCTUnwrap(viewModel.workspace.cards.last)
        XCTAssertEqual(childCard.displayName, "Shots")
        XCTAssertEqual(childCard.frame.x, 420)
        XCTAssertEqual(childCard.frame.y, 260)
        XCTAssertTrue(FileManager.default.fileExists(atPath: childFolder.path))
    }

    func testTemplateOpenReplacesCurrentCanvasAndRefreshesCards() throws {
        let fixture = try WorkspaceViewModelLayoutFixture(isLocked: false)
        defer { fixture.cleanUp() }
        let savedFolder = try fixture.createFolder(named: "Saved")
        try "saved".write(to: savedFolder.appendingPathComponent("saved.txt"), atomically: true, encoding: .utf8)
        let currentFolder = try fixture.createFolder(named: "Current")
        try "current".write(to: currentFolder.appendingPathComponent("current.txt"), atomically: true, encoding: .utf8)
        let savedCard = FolderCard(
            displayName: "Saved",
            folderPath: savedFolder.path,
            frame: CardFrame(x: 10, y: 20, width: 360, height: 240)
        )
        let currentCard = FolderCard(
            displayName: "Current",
            folderPath: currentFolder.path,
            frame: CardFrame(x: 300, y: 40, width: 360, height: 240)
        )
        try fixture.store.save(Workspace(cards: [savedCard]))
        var templateLibrary = WorkspaceTemplateLibrary()
        templateLibrary.saveTemplate(Workspace(cards: [savedCard]), at: 0, name: "Saved Set")
        try fixture.templateStore.save(templateLibrary)
        let viewModel = WorkspaceViewModel(store: fixture.store, templateStore: fixture.templateStore)
        viewModel.workspace = Workspace(cards: [currentCard])

        XCTAssertTrue(viewModel.openTemplate(at: 0))

        XCTAssertEqual(viewModel.workspace.cards, [savedCard])
        XCTAssertEqual(viewModel.activeTemplateIndex, 0)
        XCTAssertEqual(viewModel.itemsByCardID[savedCard.id]?.map(\.name), ["saved.txt"])
        XCTAssertEqual(try fixture.store.load().cards, [savedCard])
    }

    func testTemplateRenameDeleteAndOverwriteUpdateTemplateSlots() throws {
        let fixture = try WorkspaceViewModelLayoutFixture(isLocked: false)
        defer { fixture.cleanUp() }
        let firstCard = fixture.card
        let secondCard = fixture.makeCard(displayName: "Second", isLocked: false)
        try fixture.store.save(Workspace(cards: [firstCard]))
        let viewModel = WorkspaceViewModel(store: fixture.store, templateStore: fixture.templateStore)

        XCTAssertTrue(viewModel.saveTemplate(at: 1, name: "Daily"))
        XCTAssertTrue(viewModel.renameTemplate(at: 1, name: "Client Daily"))
        viewModel.workspace = Workspace(cards: [secondCard])
        XCTAssertTrue(viewModel.overwriteTemplate(at: 1))

        XCTAssertEqual(viewModel.templateSlots[1].template?.name, "Client Daily")
        XCTAssertEqual(viewModel.templateSlots[1].template?.workspace.cards, [secondCard])

        XCTAssertTrue(viewModel.deleteTemplate(at: 1))
        XCTAssertNil(viewModel.templateSlots[1].template)
    }

    func testSaveTemplateNormalizesExtremeCardPositionsBeforePersisting() throws {
        let fixture = try WorkspaceViewModelLayoutFixture(isLocked: false)
        defer { fixture.cleanUp() }
        let offscreenCard = FolderCard(
            displayName: "Lost",
            folderPath: fixture.folderURL.path,
            frame: CardFrame(x: -731_420_695, y: -285_007_347, width: 360, height: 240)
        )
        try fixture.store.save(Workspace(cards: [offscreenCard]))
        let viewModel = WorkspaceViewModel(store: fixture.store, templateStore: fixture.templateStore)

        XCTAssertTrue(viewModel.saveTemplate(at: 0, name: "Recovered"))

        let savedCard = try XCTUnwrap(viewModel.templateSlots[0].template?.workspace.cards.first)
        XCTAssertGreaterThanOrEqual(savedCard.frame.x, 20)
        XCTAssertGreaterThanOrEqual(savedCard.frame.y, 20)
        XCTAssertLessThan(savedCard.frame.x, 2_000)
        XCTAssertLessThan(savedCard.frame.y, 2_000)
    }

    func testOpenTemplateNormalizesExtremeCardPositionsBeforeReplacingCanvas() throws {
        let fixture = try WorkspaceViewModelLayoutFixture(isLocked: false)
        defer { fixture.cleanUp() }
        let offscreenCard = FolderCard(
            displayName: "Lost",
            folderPath: fixture.folderURL.path,
            frame: CardFrame(x: -731_420_695, y: -285_007_347, width: 360, height: 240)
        )
        var templateLibrary = WorkspaceTemplateLibrary()
        templateLibrary.saveTemplate(Workspace(cards: [offscreenCard]), at: 0, name: "Recovered")
        try fixture.templateStore.save(templateLibrary)
        let viewModel = WorkspaceViewModel(store: fixture.store, templateStore: fixture.templateStore)

        XCTAssertTrue(viewModel.openTemplate(at: 0))

        let openedCard = try XCTUnwrap(viewModel.workspace.cards.first)
        XCTAssertGreaterThanOrEqual(openedCard.frame.x, 20)
        XCTAssertGreaterThanOrEqual(openedCard.frame.y, 20)
        XCTAssertLessThan(openedCard.frame.x, 2_000)
        XCTAssertLessThan(openedCard.frame.y, 2_000)
    }

    func testSetCardColorUpdatesWorkspaceAndPersists() throws {
        let fixture = try WorkspaceViewModelLayoutFixture(isLocked: false)
        defer { fixture.cleanUp() }
        try fixture.saveWorkspace()
        let viewModel = WorkspaceViewModel(store: fixture.store, templateStore: fixture.templateStore)

        XCTAssertTrue(viewModel.setCardColor(.blue, for: fixture.card.id))

        XCTAssertEqual(viewModel.workspace.cards.first?.color, .blue)
        XCTAssertEqual(try fixture.store.load().cards.first?.color, .blue)
    }
}

private struct WorkspaceViewModelLayoutFixture {
    let root: URL
    let folderURL: URL
    let store: WorkspaceStore
    let templateStore: WorkspaceTemplateStore
    let card: FolderCard

    init(isLocked: Bool, filePath: String = #filePath) throws {
        root = try Self.packageRoot(filePath: filePath)
            .appendingPathComponent(".finder-workbench-demo-folders-test", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        folderURL = root.appendingPathComponent("Card", isDirectory: true)
        store = WorkspaceStore(fileURL: root.appendingPathComponent("workspace.json"))
        templateStore = WorkspaceTemplateStore(fileURL: root.appendingPathComponent("templates.json"))
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

    @discardableResult
    func createFolder(in directory: URL, named name: String) throws -> URL {
        let url = directory.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func createFile(named name: String, contents: String) throws -> URL {
        let url = root.appendingPathComponent(name)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    @discardableResult
    func createFile(in directory: URL, named name: String, contents: String) throws -> URL {
        let url = directory.appendingPathComponent(name)
        try contents.write(to: url, atomically: true, encoding: .utf8)
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
