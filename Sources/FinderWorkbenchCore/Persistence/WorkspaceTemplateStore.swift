import Foundation

public struct WorkspaceTemplateStore: Sendable {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func load() throws -> WorkspaceTemplateLibrary {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return WorkspaceTemplateLibrary()
        }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(WorkspaceTemplateLibrary.self, from: data)
    }

    public func save(_ library: WorkspaceTemplateLibrary) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(library)
        try data.write(to: fileURL, options: [.atomic])
    }
}
