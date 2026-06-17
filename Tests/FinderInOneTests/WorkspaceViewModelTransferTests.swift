import FinderWorkbenchCore
import XCTest
@testable import FinderInOne

@MainActor
final class WorkspaceViewModelTransferTests: XCTestCase {
    func testTransferItemCopiesIntoTargetCardAndRefreshesLists() throws {
        let fixture = try WorkspaceViewModelTransferFixture()
        defer { fixture.cleanUp() }
        try fixture.createSourceFile(named: "Plate.mov", contents: "plate")
        try fixture.saveWorkspace()
        let viewModel = WorkspaceViewModel(
            store: fixture.store,
            allowedTransferRoot: fixture.allowedRoot
        )
        let item = try XCTUnwrap(viewModel.itemsByCardID[fixture.sourceCard.id]?.first)

        let transferred = viewModel.transfer(item: item, to: fixture.targetCard)

        XCTAssertTrue(transferred)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.sourceDirectory.appendingPathComponent("Plate.mov").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.targetDirectory.appendingPathComponent("Plate.mov").path))
        XCTAssertEqual(viewModel.itemsByCardID[fixture.sourceCard.id]?.map(\.name), ["Plate.mov"])
        XCTAssertEqual(viewModel.itemsByCardID[fixture.targetCard.id]?.map(\.name), ["Plate.mov"])
        XCTAssertEqual(viewModel.transferMode, .copy)
    }

    func testTransferItemMovesOnceThenReturnsToCopyMode() throws {
        let fixture = try WorkspaceViewModelTransferFixture()
        defer { fixture.cleanUp() }
        try fixture.createSourceFile(named: "Render.exr", contents: "render")
        try fixture.saveWorkspace()
        let viewModel = WorkspaceViewModel(
            store: fixture.store,
            allowedTransferRoot: fixture.allowedRoot
        )
        viewModel.transferMode = .moveOnce
        let item = try XCTUnwrap(viewModel.itemsByCardID[fixture.sourceCard.id]?.first)

        let transferred = viewModel.transfer(item: item, to: fixture.targetCard)

        XCTAssertTrue(transferred)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.sourceDirectory.appendingPathComponent("Render.exr").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.targetDirectory.appendingPathComponent("Render.exr").path))
        XCTAssertEqual(viewModel.itemsByCardID[fixture.sourceCard.id]?.map(\.name), [])
        XCTAssertEqual(viewModel.itemsByCardID[fixture.targetCard.id]?.map(\.name), ["Render.exr"])
        XCTAssertEqual(viewModel.transferMode, .copy)
    }

    func testTransferBetweenWorkspaceCardRootsWithoutInjectedAllowedRoot() throws {
        let fixture = try WorkspaceViewModelTransferFixture()
        defer { fixture.cleanUp() }
        try fixture.createSourceFile(named: "Texture.tx", contents: "texture")
        try fixture.saveWorkspace()
        let viewModel = WorkspaceViewModel(store: fixture.store)
        let item = try XCTUnwrap(viewModel.itemsByCardID[fixture.sourceCard.id]?.first)

        let transferred = viewModel.transfer(item: item, to: fixture.targetCard)

        XCTAssertTrue(transferred)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.sourceDirectory.appendingPathComponent("Texture.tx").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.targetDirectory.appendingPathComponent("Texture.tx").path))
        XCTAssertEqual(viewModel.itemsByCardID[fixture.targetCard.id]?.map(\.name), ["Texture.tx"])
    }
}

private struct WorkspaceViewModelTransferFixture {
    let root: URL
    let allowedRoot: URL
    let sourceDirectory: URL
    let targetDirectory: URL
    let store: WorkspaceStore
    let sourceCard: FolderCard
    let targetCard: FolderCard

    init(filePath: String = #filePath) throws {
        root = try Self.packageRoot(filePath: filePath)
            .appendingPathComponent(".finder-workbench-demo-folders-test", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        allowedRoot = root.appendingPathComponent("Allowed", isDirectory: true)
        sourceDirectory = allowedRoot.appendingPathComponent("Source", isDirectory: true)
        targetDirectory = allowedRoot.appendingPathComponent("Target", isDirectory: true)
        store = WorkspaceStore(fileURL: root.appendingPathComponent("workspace.json"))
        sourceCard = FolderCard(
            displayName: "Source",
            folderPath: sourceDirectory.path,
            frame: CardFrame(x: 0, y: 0, width: 360, height: 240)
        )
        targetCard = FolderCard(
            displayName: "Target",
            folderPath: targetDirectory.path,
            frame: CardFrame(x: 0, y: 0, width: 360, height: 240)
        )

        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: targetDirectory, withIntermediateDirectories: true)
    }

    @discardableResult
    func createSourceFile(named name: String, contents: String) throws -> URL {
        let url = sourceDirectory.appendingPathComponent(name)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func saveWorkspace() throws {
        try store.save(Workspace(cards: [sourceCard, targetCard]))
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
