import Foundation

public struct DirectoryListingService: @unchecked Sendable {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func items(in directoryURL: URL) throws -> [FileItem] {
        let urls = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        )

        return FileItemSorter.sorted(try urls.map(makeItem(url:)))
    }

    private func makeItem(url: URL) throws -> FileItem {
        let values = try url.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey, .fileSizeKey])
        let isDirectory = values.isDirectory ?? false
        return FileItem(
            url: url,
            name: url.lastPathComponent,
            modifiedAt: values.contentModificationDate,
            byteSize: isDirectory ? nil : values.fileSize.map(Int64.init),
            isDirectory: isDirectory
        )
    }
}
