import XCTest
@testable import FinderInOne

final class DemoFolderProviderTests: XCTestCase {
    func testCreateDemoFolderUsesProjectLocalRootWhenCurrentDirectoryChanges() throws {
        let originalWorkingDirectory = FileManager.default.currentDirectoryPath
        let temporaryWorkingDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryWorkingDirectory, withIntermediateDirectories: true)
        defer {
            FileManager.default.changeCurrentDirectoryPath(originalWorkingDirectory)
            try? FileManager.default.removeItem(at: temporaryWorkingDirectory)
        }
        XCTAssertTrue(FileManager.default.changeCurrentDirectoryPath(temporaryWorkingDirectory.path))

        let demoFolder = try DemoFolderProvider().createDemoFolder()
        defer { try? FileManager.default.removeItem(at: demoFolder.url) }

        let expectedRoot = try packageRoot()
            .appendingPathComponent(".finder-workbench-demo-folders", isDirectory: true)
            .standardizedFileURL
        let actualRoot = demoFolder.url
            .deletingLastPathComponent()
            .standardizedFileURL

        XCTAssertEqual(actualRoot, expectedRoot)
    }

    private func packageRoot(filePath: String = #filePath) throws -> URL {
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
