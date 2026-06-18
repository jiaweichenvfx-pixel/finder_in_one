import XCTest
@testable import FinderWorkbenchCore

final class WorkspaceTemplateStoreTests: XCTestCase {
    func testLoadMissingTemplateFileReturnsFiveEmptySlots() throws {
        let fixture = try WorkspaceTemplateStoreFixture()
        defer { fixture.cleanUp() }
        let store = WorkspaceTemplateStore(fileURL: fixture.root.appendingPathComponent("missing.json"))

        let library = try store.load()

        XCTAssertEqual(library.slots.count, 5)
        XCTAssertEqual(library.slots.map(\.index), [0, 1, 2, 3, 4])
        XCTAssertTrue(library.slots.allSatisfy { $0.template == nil })
    }

    func testSaveAndLoadTemplateLibraryRoundTripsSlots() throws {
        let fixture = try WorkspaceTemplateStoreFixture()
        defer { fixture.cleanUp() }
        let store = WorkspaceTemplateStore(fileURL: fixture.root.appendingPathComponent("templates.json"))
        let workspace = Workspace(cards: [
            FolderCard(
                id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
                displayName: "Client",
                folderPath: "/tmp/client",
                frame: CardFrame(x: 12, y: 24, width: 360, height: 240),
                isLocked: true
            )
        ])
        var library = WorkspaceTemplateLibrary()
        library.saveTemplate(workspace, at: 2, name: "Client Work")

        try store.save(library)
        let loaded = try store.load()

        XCTAssertEqual(loaded.slots[2].template?.name, "Client Work")
        XCTAssertEqual(loaded.slots[2].template?.workspace, workspace)
    }
}

private struct WorkspaceTemplateStoreFixture {
    let root: URL

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func cleanUp() {
        try? FileManager.default.removeItem(at: root)
    }
}
