import XCTest
@testable import FinderWorkbenchCore

final class DirectoryListingServiceTests: XCTestCase {
    func testListsVisibleFilesAndFoldersSortedByFolderThenName() throws {
        let fixture = try DirectoryListingFixture()
        defer { fixture.cleanUp() }
        try fixture.createFile("zeta.txt", contents: "z")
        try fixture.createFolder("Assets")
        try fixture.createFile("alpha.txt", contents: "a")

        let service = DirectoryListingService()
        let items = try service.items(in: fixture.root)

        XCTAssertEqual(items.map(\.name), ["Assets", "alpha.txt", "zeta.txt"])
        XCTAssertEqual(items.map(\.isDirectory), [true, false, false])
    }

    func testSkipsHiddenFiles() throws {
        let fixture = try DirectoryListingFixture()
        defer { fixture.cleanUp() }
        try fixture.createFile(".secret", contents: "hidden")
        try fixture.createFile("visible.txt", contents: "visible")

        let items = try DirectoryListingService().items(in: fixture.root)

        XCTAssertEqual(items.map(\.name), ["visible.txt"])
    }

    func testReportsFileSizeAndKind() throws {
        let fixture = try DirectoryListingFixture()
        defer { fixture.cleanUp() }
        try fixture.createFile("note.txt", contents: "hello")

        let item = try XCTUnwrap(try DirectoryListingService().items(in: fixture.root).first)

        XCTAssertEqual(item.name, "note.txt")
        XCTAssertEqual(item.byteSize, 5)
        XCTAssertEqual(item.kind, "File")
    }
}

private struct DirectoryListingFixture {
    let root: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func createFile(_ name: String, contents: String) throws {
        try contents.write(to: root.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }

    func createFolder(_ name: String) throws {
        try FileManager.default.createDirectory(at: root.appendingPathComponent(name, isDirectory: true), withIntermediateDirectories: true)
    }

    func cleanUp() {
        try? FileManager.default.removeItem(at: root)
    }
}
