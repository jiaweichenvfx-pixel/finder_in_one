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
