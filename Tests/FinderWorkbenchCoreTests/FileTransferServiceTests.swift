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
    func testCopyFileToSameDirectoryWithReplaceIsNoOp() throws {
        let fixture = try FileTransferFixture()
        defer { fixture.cleanUp() }
        let sourceFile = try fixture.createSourceFile(named: "SamePlace.txt", contents: "keep me")
        let service = FileTransferService()

        let result = try service.transfer(
            sourceURL: sourceFile,
            targetDirectory: fixture.sourceDirectory,
            operation: .copy,
            conflictPolicy: .replace
        )

        XCTAssertEqual(result.destinationURL?.standardizedFileURL, sourceFile.standardizedFileURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceFile.path))
        XCTAssertEqual(try String(contentsOf: sourceFile, encoding: .utf8), "keep me")
    }

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

    func testCopyFileWithReplaceOverwritesDifferentTargetAndKeepsSource() throws {
        let fixture = try FileTransferFixture()
        defer { fixture.cleanUp() }
        let sourceFile = try fixture.createSourceFile(named: "Same.txt", contents: "source")
        let targetFile = try fixture.createTargetFile(named: "Same.txt", contents: "target")
        let service = FileTransferService()

        let result = try service.transfer(
            sourceURL: sourceFile,
            targetDirectory: fixture.targetDirectory,
            operation: .copy,
            conflictPolicy: .replace
        )

        let destinationURL = try XCTUnwrap(result.destinationURL)
        XCTAssertEqual(destinationURL.standardizedFileURL, targetFile.standardizedFileURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceFile.path))
        XCTAssertEqual(try String(contentsOf: sourceFile, encoding: .utf8), "source")
        XCTAssertEqual(try String(contentsOf: destinationURL, encoding: .utf8), "source")
    }

    func testCopyFolderCreatesTargetFolderWithContents() throws {
        let fixture = try FileTransferFixture()
        defer { fixture.cleanUp() }
        let sourceFolder = try fixture.createSourceFolder(named: "Project", childName: "Notes.txt", contents: "folder")
        let service = FileTransferService()

        let result = try service.transfer(
            sourceURL: sourceFolder,
            targetDirectory: fixture.targetDirectory,
            operation: .copy,
            conflictPolicy: .replace
        )

        let destinationURL = try XCTUnwrap(result.destinationURL)
        let sourceChild = sourceFolder.appendingPathComponent("Notes.txt")
        let destinationChild = destinationURL.appendingPathComponent("Notes.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceChild.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: destinationChild.path))
        XCTAssertEqual(try String(contentsOf: destinationChild, encoding: .utf8), "folder")
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

    func createSourceFolder(named name: String, childName: String, contents: String) throws -> URL {
        let folderURL = sourceDirectory.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        try contents.write(to: folderURL.appendingPathComponent(childName), atomically: true, encoding: .utf8)
        return folderURL
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
