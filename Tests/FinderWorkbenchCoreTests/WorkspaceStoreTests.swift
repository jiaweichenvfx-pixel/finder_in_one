import XCTest
@testable import FinderWorkbenchCore

final class WorkspaceStoreTests: XCTestCase {
    func testSaveAndLoadWorkspaceRoundTripsCards() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = WorkspaceStore(fileURL: directory.appendingPathComponent("workspace.json"))
        let workspace = Workspace(cards: [
            FolderCard(
                id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
                displayName: "Client A",
                folderPath: "/Users/test/Client A",
                frame: CardFrame(x: 12, y: 24, width: 360, height: 260),
                isLocked: true
            )
        ])

        try store.save(workspace)
        let loaded = try store.load()

        XCTAssertEqual(loaded, workspace)
    }

    func testLoadMissingWorkspaceReturnsEmptyWorkspace() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = WorkspaceStore(fileURL: directory.appendingPathComponent("missing.json"))

        XCTAssertEqual(try store.load(), Workspace())
    }
}
