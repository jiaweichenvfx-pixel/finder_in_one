import XCTest
@testable import FinderWorkbenchCore

final class ScopedFileTransferServiceTests: XCTestCase {
    func testCopyWithinAllowedRootKeepsSourceAndCreatesDestination() throws {
        let fixture = try ScopedFileTransferFixture()
        defer { fixture.cleanUp() }
        let source = try fixture.createAllowedSourceFile(named: "Plate.mov", contents: "source")
        let service = ScopedFileTransferService(allowedRoot: fixture.allowedRoot)

        let result = try service.transfer(
            sourceURL: source,
            targetDirectory: fixture.allowedTargetDirectory,
            operation: .copy,
            conflictPolicy: .replace
        )

        let destination = try XCTUnwrap(result.destinationURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
        XCTAssertEqual(try String(contentsOf: destination, encoding: .utf8), "source")
    }

    func testMoveWithinAllowedRootRemovesSourceAndCreatesDestination() throws {
        let fixture = try ScopedFileTransferFixture()
        defer { fixture.cleanUp() }
        let source = try fixture.createAllowedSourceFile(named: "Comp.nk", contents: "move")
        let service = ScopedFileTransferService(allowedRoot: fixture.allowedRoot)

        let result = try service.transfer(
            sourceURL: source,
            targetDirectory: fixture.allowedTargetDirectory,
            operation: .move,
            conflictPolicy: .replace
        )

        let destination = try XCTUnwrap(result.destinationURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
        XCTAssertEqual(try String(contentsOf: destination, encoding: .utf8), "move")
    }

    func testRejectsSourceOutsideAllowedRootWithoutCreatingDestination() throws {
        let fixture = try ScopedFileTransferFixture()
        defer { fixture.cleanUp() }
        let source = try fixture.createOutsideFile(named: "Outside.txt", contents: "outside")
        let service = ScopedFileTransferService(allowedRoot: fixture.allowedRoot)

        XCTAssertThrowsError(
            try service.transfer(
                sourceURL: source,
                targetDirectory: fixture.allowedTargetDirectory,
                operation: .copy,
                conflictPolicy: .replace
            )
        ) { error in
            XCTAssertEqual(error as? ScopedFileTransferError, .sourceOutsideAllowedRoot)
        }

        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.allowedTargetDirectory.appendingPathComponent("Outside.txt").path))
    }

    func testRejectsTargetOutsideAllowedRootWithoutMovingSource() throws {
        let fixture = try ScopedFileTransferFixture()
        defer { fixture.cleanUp() }
        let source = try fixture.createAllowedSourceFile(named: "Keep.txt", contents: "keep")
        let service = ScopedFileTransferService(allowedRoot: fixture.allowedRoot)

        XCTAssertThrowsError(
            try service.transfer(
                sourceURL: source,
                targetDirectory: fixture.outsideDirectory,
                operation: .move,
                conflictPolicy: .replace
            )
        ) { error in
            XCTAssertEqual(error as? ScopedFileTransferError, .targetOutsideAllowedRoot)
        }

        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.outsideDirectory.appendingPathComponent("Keep.txt").path))
    }
}

private struct ScopedFileTransferFixture {
    let root: URL
    let allowedRoot: URL
    let allowedSourceDirectory: URL
    let allowedTargetDirectory: URL
    let outsideDirectory: URL

    init(filePath: String = #filePath) throws {
        root = try Self.packageRoot(filePath: filePath)
            .appendingPathComponent(".finder-workbench-demo-folders-test", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        allowedRoot = root.appendingPathComponent("Allowed", isDirectory: true)
        allowedSourceDirectory = allowedRoot.appendingPathComponent("Source", isDirectory: true)
        allowedTargetDirectory = allowedRoot.appendingPathComponent("Target", isDirectory: true)
        outsideDirectory = root.appendingPathComponent("Outside", isDirectory: true)

        try FileManager.default.createDirectory(at: allowedSourceDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: allowedTargetDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outsideDirectory, withIntermediateDirectories: true)
    }

    func createAllowedSourceFile(named name: String, contents: String) throws -> URL {
        let url = allowedSourceDirectory.appendingPathComponent(name)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func createOutsideFile(named name: String, contents: String) throws -> URL {
        let url = outsideDirectory.appendingPathComponent(name)
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
