import Foundation

public struct WorkspaceStore: Sendable {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func load() throws -> Workspace {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return Workspace()
        }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(Workspace.self, from: data)
    }

    public func save(_ workspace: Workspace) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(workspace)
        try data.write(to: fileURL, options: [.atomic])
    }
}
