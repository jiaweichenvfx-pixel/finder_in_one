import FinderWorkbenchCore
import XCTest
@testable import FinderInOne

@MainActor
final class WorkspaceViewModelOpenItemTests: XCTestCase {
    func testOpenDirectoryItemNavigatesCardIntoFolderAndPersists() throws {
        let fixture = try WorkspaceViewModelOpenItemFixture()
        defer { fixture.cleanUp() }
        let childFolder = try fixture.createFolder(named: "Shots")
        try "plate".write(to: childFolder.appendingPathComponent("plate.mov"), atomically: true, encoding: .utf8)
        try fixture.saveWorkspace()
        let viewModel = WorkspaceViewModel(store: fixture.store)
        let item = try XCTUnwrap(viewModel.itemsByCardID[fixture.card.id]?.first(where: { $0.name == "Shots" }))

        let result = viewModel.open(item: item, in: fixture.card)

        XCTAssertEqual(result, .navigated)
        XCTAssertEqual(viewModel.workspace.cards.first?.folderPath, childFolder.path)
        XCTAssertEqual(viewModel.workspace.cards.first?.displayName, "Shots")
        XCTAssertEqual(viewModel.itemsByCardID[fixture.card.id]?.map(\.name), ["plate.mov"])
        XCTAssertEqual(try fixture.store.load().cards.first?.folderPath, childFolder.path)
    }

    func testOpenFileItemUsesExternalOpener() throws {
        let fixture = try WorkspaceViewModelOpenItemFixture()
        defer { fixture.cleanUp() }
        let fileURL = try fixture.createFile(named: "preview.jpg", contents: "image")
        try fixture.saveWorkspace()
        var openedURLs: [URL] = []
        let viewModel = WorkspaceViewModel(
            store: fixture.store,
            fileOpening: FileOpening { openedURLs.append($0) }
        )
        let item = try XCTUnwrap(viewModel.itemsByCardID[fixture.card.id]?.first(where: { $0.name == "preview.jpg" }))

        let result = viewModel.open(item: item, in: fixture.card)

        XCTAssertEqual(result, .openedExternally)
        XCTAssertEqual(openedURLs, [fileURL])
        XCTAssertEqual(viewModel.workspace.cards.first?.folderPath, fixture.folderURL.path)
    }

    func testNavigateToParentFolderUpdatesCardRefreshesAndPersists() throws {
        let fixture = try WorkspaceViewModelOpenItemFixture()
        defer { fixture.cleanUp() }
        let childFolder = try fixture.createFolder(named: "Shots")
        try "plate".write(to: fixture.folderURL.appendingPathComponent("root.txt"), atomically: true, encoding: .utf8)
        try "plate".write(to: childFolder.appendingPathComponent("plate.mov"), atomically: true, encoding: .utf8)
        var childCard = fixture.card
        childCard.displayName = "Shots"
        childCard.folderPath = childFolder.path
        try fixture.store.save(Workspace(cards: [childCard]))
        let viewModel = WorkspaceViewModel(store: fixture.store)

        let navigated = viewModel.navigateToParent(of: childCard)

        XCTAssertTrue(navigated)
        XCTAssertEqual(viewModel.workspace.cards.first?.folderPath, fixture.folderURL.path)
        XCTAssertEqual(viewModel.workspace.cards.first?.displayName, "Card")
        XCTAssertEqual(viewModel.itemsByCardID[fixture.card.id]?.map(\.name), ["Shots", "root.txt"])
        XCTAssertEqual(try fixture.store.load().cards.first?.folderPath, fixture.folderURL.path)
    }

    func testPreviewItemsSendsURLsToPreviewer() throws {
        let fixture = try WorkspaceViewModelOpenItemFixture()
        defer { fixture.cleanUp() }
        let firstURL = try fixture.createFile(named: "first.jpg", contents: "image")
        let secondURL = try fixture.createFile(named: "second.jpg", contents: "image")
        try fixture.saveWorkspace()
        var previewedURLs: [URL] = []
        let viewModel = WorkspaceViewModel(
            store: fixture.store,
            filePreviewing: FilePreviewing { previewedURLs = $0 }
        )
        let items = try XCTUnwrap(viewModel.itemsByCardID[fixture.card.id])

        viewModel.preview(items: items)

        XCTAssertEqual(previewedURLs, [firstURL, secondURL])
    }

    func testOpenInFinderSelectsCurrentCardSelection() throws {
        let fixture = try WorkspaceViewModelOpenItemFixture()
        defer { fixture.cleanUp() }
        let firstURL = try fixture.createFile(named: "first.jpg", contents: "image")
        let secondURL = try fixture.createFile(named: "second.jpg", contents: "image")
        try fixture.saveWorkspace()
        var openedFolderURL: URL?
        var selectedURLs: [URL] = []
        let viewModel = WorkspaceViewModel(
            store: fixture.store,
            finderOpening: FinderOpening { folderURL, urls in
                openedFolderURL = folderURL
                selectedURLs = urls
            }
        )
        viewModel.setSelectedItemURLs([secondURL, firstURL], for: fixture.card.id)

        viewModel.openInFinder(card: fixture.card)

        XCTAssertEqual(openedFolderURL, fixture.folderURL)
        XCTAssertEqual(Set(selectedURLs), [firstURL, secondURL])
    }

    func testOpenInFinderIgnoresStaleSelectionOutsideCurrentCardFolder() throws {
        let fixture = try WorkspaceViewModelOpenItemFixture()
        defer { fixture.cleanUp() }
        let staleURL = fixture.root.appendingPathComponent("old.txt")
        try "old".write(to: staleURL, atomically: true, encoding: .utf8)
        try fixture.saveWorkspace()
        var openedFolderURL: URL?
        var selectedURLs: [URL] = [staleURL]
        let viewModel = WorkspaceViewModel(
            store: fixture.store,
            finderOpening: FinderOpening { folderURL, urls in
                openedFolderURL = folderURL
                selectedURLs = urls
            }
        )
        viewModel.setSelectedItemURLs([staleURL], for: fixture.card.id)

        viewModel.openInFinder(card: fixture.card)

        XCTAssertEqual(openedFolderURL, fixture.folderURL)
        XCTAssertTrue(selectedURLs.isEmpty)
    }

    func testOpenInFinderOpensCardFolderWhenNothingIsSelected() throws {
        let fixture = try WorkspaceViewModelOpenItemFixture()
        defer { fixture.cleanUp() }
        try fixture.saveWorkspace()
        var openedFolderURL: URL?
        var selectedURLs: [URL] = [fixture.folderURL.appendingPathComponent("stale.txt")]
        let viewModel = WorkspaceViewModel(
            store: fixture.store,
            finderOpening: FinderOpening { folderURL, urls in
                openedFolderURL = folderURL
                selectedURLs = urls
            }
        )

        viewModel.openInFinder(card: fixture.card)

        XCTAssertEqual(openedFolderURL, fixture.folderURL)
        XCTAssertTrue(selectedURLs.isEmpty)
    }

    func testPreviewItemsCanStartAtSelectedItemIndex() throws {
        let fixture = try WorkspaceViewModelOpenItemFixture()
        defer { fixture.cleanUp() }
        let firstURL = try fixture.createFile(named: "first.jpg", contents: "image")
        let secondURL = try fixture.createFile(named: "second.jpg", contents: "image")
        try fixture.saveWorkspace()
        var previewedURLs: [URL] = []
        var previewedIndex: Int?
        let viewModel = WorkspaceViewModel(
            store: fixture.store,
            filePreviewing: FilePreviewing { urls, selectedIndex in
                previewedURLs = urls
                previewedIndex = selectedIndex
            }
        )
        let items = try XCTUnwrap(viewModel.itemsByCardID[fixture.card.id])

        viewModel.preview(items: items, startingAt: secondURL)

        XCTAssertEqual(previewedURLs, [firstURL, secondURL])
        XCTAssertEqual(previewedIndex, 1)
    }
}

private struct WorkspaceViewModelOpenItemFixture {
    let root: URL
    let folderURL: URL
    let store: WorkspaceStore
    let card: FolderCard

    init(filePath: String = #filePath) throws {
        root = try Self.packageRoot(filePath: filePath)
            .appendingPathComponent(".finder-workbench-demo-folders-test", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        folderURL = root.appendingPathComponent("Card", isDirectory: true)
        store = WorkspaceStore(fileURL: root.appendingPathComponent("workspace.json"))
        card = FolderCard(
            displayName: "Card",
            folderPath: folderURL.path,
            frame: CardFrame(x: 20, y: 20, width: 360, height: 240)
        )
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
    }

    func createFolder(named name: String) throws -> URL {
        let url = folderURL.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @discardableResult
    func createFile(named name: String, contents: String) throws -> URL {
        let url = folderURL.appendingPathComponent(name)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func saveWorkspace() throws {
        try store.save(Workspace(cards: [card]))
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
