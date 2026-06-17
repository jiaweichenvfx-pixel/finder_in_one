import Foundation

public enum FileTransferResult: Equatable, Sendable {
    case transferred(destinationURL: URL)
    case skipped

    public var destinationURL: URL? {
        switch self {
        case .transferred(let url):
            return url
        case .skipped:
            return nil
        }
    }
}

public struct FileTransferService {
    private let fileManager: FileManager
    private let planner: FileConflictPlanner

    public init(fileManager: FileManager = .default, planner: FileConflictPlanner = FileConflictPlanner()) {
        self.fileManager = fileManager
        self.planner = planner
    }

    public func transfer(
        sourceURL: URL,
        targetDirectory: URL,
        operation: FileTransferOperation,
        conflictPolicy: FileConflictPolicy
    ) throws -> FileTransferResult {
        let names = try Set(fileManager.contentsOfDirectory(atPath: targetDirectory.path))
        guard let destinationURL = planner.destinationURL(
            for: sourceURL,
            in: targetDirectory,
            existingNames: names,
            policy: conflictPolicy
        ) else {
            return .skipped
        }

        if sourceURL.resolvingSymlinksInPath().standardizedFileURL.path == destinationURL.resolvingSymlinksInPath().standardizedFileURL.path {
            return .transferred(destinationURL: destinationURL)
        }

        if fileManager.fileExists(atPath: destinationURL.path), conflictPolicy == .replace {
            try fileManager.removeItem(at: destinationURL)
        }

        switch operation {
        case .copy:
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
        case .move:
            try fileManager.moveItem(at: sourceURL, to: destinationURL)
        }

        return .transferred(destinationURL: destinationURL)
    }
}
