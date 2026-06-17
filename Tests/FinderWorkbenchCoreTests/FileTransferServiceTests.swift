import XCTest
@testable import FinderWorkbenchCore

final class FileTransferServiceTests: XCTestCase {
    func testKeepBothUsesOriginalNameWhenNoConflictExists() {
        let planner = FileConflictPlanner()
        let source = URL(fileURLWithPath: "/tmp/Brief.pdf")
        let targetDirectory = URL(fileURLWithPath: "/tmp/Target", isDirectory: true)

        let planned = planner.destinationURL(
            for: source,
            in: targetDirectory,
            existingNames: ["Notes.pdf"],
            policy: .keepBoth
        )

        XCTAssertEqual(planned, targetDirectory.appendingPathComponent("Brief.pdf"))
    }

    func testKeepBothAddsNumericSuffixBeforeExtension() {
        let planner = FileConflictPlanner()
        let source = URL(fileURLWithPath: "/tmp/Brief.pdf")
        let targetDirectory = URL(fileURLWithPath: "/tmp/Target", isDirectory: true)
        let existingNames: Set<String> = ["Brief.pdf", "Brief 2.pdf"]

        let planned = planner.destinationURL(
            for: source,
            in: targetDirectory,
            existingNames: existingNames,
            policy: .keepBoth
        )

        XCTAssertEqual(planned, targetDirectory.appendingPathComponent("Brief 3.pdf"))
    }

    func testKeepBothTreatsExistingNamesCaseInsensitively() {
        let planner = FileConflictPlanner()
        let source = URL(fileURLWithPath: "/tmp/Brief.pdf")
        let targetDirectory = URL(fileURLWithPath: "/tmp/Target", isDirectory: true)

        let planned = planner.destinationURL(
            for: source,
            in: targetDirectory,
            existingNames: ["brief.pdf"],
            policy: .keepBoth
        )

        XCTAssertEqual(planned, targetDirectory.appendingPathComponent("Brief 2.pdf"))
    }

    func testSkipReturnsNilWhenConflictExists() {
        let planner = FileConflictPlanner()
        let source = URL(fileURLWithPath: "/tmp/Brief.pdf")
        let targetDirectory = URL(fileURLWithPath: "/tmp/Target", isDirectory: true)

        let planned = planner.destinationURL(
            for: source,
            in: targetDirectory,
            existingNames: ["Brief.pdf"],
            policy: .skip
        )

        XCTAssertNil(planned)
    }

    func testReplaceUsesOriginalName() {
        let planner = FileConflictPlanner()
        let source = URL(fileURLWithPath: "/tmp/Brief.pdf")
        let targetDirectory = URL(fileURLWithPath: "/tmp/Target", isDirectory: true)

        let planned = planner.destinationURL(
            for: source,
            in: targetDirectory,
            existingNames: ["Brief.pdf"],
            policy: .replace
        )

        XCTAssertEqual(planned, targetDirectory.appendingPathComponent("Brief.pdf"))
    }
}

extension FileTransferServiceTests {
    func testCopyFileKeepsOriginalAndCreatesTarget() throws {
        let fixture = try FileTransferFixture()
        defer { fixture.cleanUp() }
        let sourceFile = try fixture.createSourceFile(named: "Brief.txt", contents: "hello")
        let service = FileTransferService()

        let result = try service.transfer(
            sourceURL: sourceFile,
            targetDirectory: fixture.targetDirectory,
            operation: .copy,
            conflictPolicy: .replace
        )

        let destinationURL = try XCTUnwrap(result.destinationURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceFile.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: destinationURL.path))
        XCTAssertEqual(try String(contentsOf: destinationURL, encoding: .utf8), "hello")
    }

    func testMoveFileRemovesOriginalAndCreatesTarget() throws {
        let fixture = try FileTransferFixture()
        defer { fixture.cleanUp() }
        let sourceFile = try fixture.createSourceFile(named: "MoveMe.txt", contents: "move")
        let service = FileTransferService()

        let result = try service.transfer(
            sourceURL: sourceFile,
            targetDirectory: fixture.targetDirectory,
            operation: .move,
            conflictPolicy: .replace
        )

        let destinationURL = try XCTUnwrap(result.destinationURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: sourceFile.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: destinationURL.path))
        XCTAssertEqual(try String(contentsOf: destinationURL, encoding: .utf8), "move")
    }

    func testSkipConflictDoesNotCreateNewFile() throws {
        let fixture = try FileTransferFixture()
        defer { fixture.cleanUp() }
        let sourceFile = try fixture.createSourceFile(named: "Same.txt", contents: "source")
        _ = try fixture.createTargetFile(named: "Same.txt", contents: "target")
        let service = FileTransferService()

        let result = try service.transfer(
            sourceURL: sourceFile,
            targetDirectory: fixture.targetDirectory,
            operation: .copy,
            conflictPolicy: .skip
        )

        XCTAssertEqual(result, .skipped)
        XCTAssertEqual(try String(contentsOf: fixture.targetDirectory.appendingPathComponent("Same.txt"), encoding: .utf8), "target")
    }
}

private struct FileTransferFixture {
    let root: URL
    let sourceDirectory: URL
    let targetDirectory: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        sourceDirectory = root.appendingPathComponent("Source", isDirectory: true)
        targetDirectory = root.appendingPathComponent("Target", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: targetDirectory, withIntermediateDirectories: true)
    }

    func createSourceFile(named name: String, contents: String) throws -> URL {
        let url = sourceDirectory.appendingPathComponent(name)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func createTargetFile(named name: String, contents: String) throws -> URL {
        let url = targetDirectory.appendingPathComponent(name)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func cleanUp() {
        try? FileManager.default.removeItem(at: root)
    }
}
