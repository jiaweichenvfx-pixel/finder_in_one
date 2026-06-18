import UniformTypeIdentifiers
import XCTest
@testable import FinderInOne

final class DropURLParsingTests: XCTestCase {
    func testAcceptsFileURLAndURLPasteboardTypes() {
        XCTAssertTrue(DropURLParsing.acceptedFileURLTypeIdentifiers.contains(UTType.fileURL.identifier))
        XCTAssertTrue(DropURLParsing.acceptedFileURLTypeIdentifiers.contains(UTType.url.identifier))
    }

    func testParsesFinderProxyFileURLString() {
        let url = DropURLParsing.fileURL(from: NSString(string: "file:///tmp/Finder%20Proxy"))

        XCTAssertEqual(url?.path, "/tmp/Finder Proxy")
    }

    func testIgnoresNonFileURLs() {
        let url = DropURLParsing.fileURL(from: NSString(string: "https://example.com/folder"))

        XCTAssertNil(url)
    }
}
