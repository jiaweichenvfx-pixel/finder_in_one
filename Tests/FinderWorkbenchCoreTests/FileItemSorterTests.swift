import XCTest
@testable import FinderWorkbenchCore

final class FileItemSorterTests: XCTestCase {
    func testSortsFilesBySizeDescendingWhileKeepingFoldersFirst() {
        let items = [
            item("small.mov", byteSize: 20, isDirectory: false),
            item("Reference", byteSize: nil, isDirectory: true),
            item("large.mov", byteSize: 200, isDirectory: false)
        ]

        let sorted = FileItemSorter.sorted(
            items,
            by: FileItemSortOrder(column: .size, ascending: false)
        )

        XCTAssertEqual(sorted.map(\.name), ["Reference", "large.mov", "small.mov"])
    }

    func testSortsFilesByModifiedDateAscendingWithMissingDatesLast() {
        let older = Date(timeIntervalSince1970: 100)
        let newer = Date(timeIntervalSince1970: 200)
        let items = [
            item("missing.txt", modifiedAt: nil, isDirectory: false),
            item("newer.txt", modifiedAt: newer, isDirectory: false),
            item("older.txt", modifiedAt: older, isDirectory: false)
        ]

        let sorted = FileItemSorter.sorted(
            items,
            by: FileItemSortOrder(column: .modified, ascending: true)
        )

        XCTAssertEqual(sorted.map(\.name), ["older.txt", "newer.txt", "missing.txt"])
    }

    private func item(
        _ name: String,
        modifiedAt: Date? = Date(timeIntervalSince1970: 100),
        byteSize: Int64? = nil,
        isDirectory: Bool
    ) -> FileItem {
        FileItem(
            url: URL(fileURLWithPath: "/tmp/\(name)"),
            name: name,
            modifiedAt: modifiedAt,
            byteSize: byteSize,
            isDirectory: isDirectory
        )
    }
}
