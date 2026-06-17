import XCTest
@testable import FinderWorkbenchCore

final class FileTransferServiceTests: XCTestCase {
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

        XCTAssertEqual(planned?.lastPathComponent, "Brief 3.pdf")
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

        XCTAssertEqual(planned?.lastPathComponent, "Brief.pdf")
    }
}
