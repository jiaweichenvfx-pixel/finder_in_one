import Foundation

public struct FileItem: Identifiable, Equatable, Sendable {
    public let id: URL
    public let url: URL
    public let name: String
    public let modifiedAt: Date?
    public let byteSize: Int64?
    public let isDirectory: Bool

    public init(url: URL, name: String, modifiedAt: Date?, byteSize: Int64?, isDirectory: Bool) {
        self.id = url
        self.url = url
        self.name = name
        self.modifiedAt = modifiedAt
        self.byteSize = byteSize
        self.isDirectory = isDirectory
    }

    public var kind: String {
        isDirectory ? "Folder" : "File"
    }
}
