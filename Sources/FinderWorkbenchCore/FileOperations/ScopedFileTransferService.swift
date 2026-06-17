import Foundation

public enum ScopedFileTransferError: Error, Equatable, Sendable {
    case sourceOutsideAllowedRoot
    case targetOutsideAllowedRoot
}

public struct ScopedFileTransferService {
    private let allowedRoot: URL
    private let transferService: FileTransferService

    public init(allowedRoot: URL, transferService: FileTransferService = FileTransferService()) {
        self.allowedRoot = allowedRoot
        self.transferService = transferService
    }

    public func transfer(
        sourceURL: URL,
        targetDirectory: URL,
        operation: FileTransferOperation,
        conflictPolicy: FileConflictPolicy
    ) throws -> FileTransferResult {
        guard contains(sourceURL) else {
            throw ScopedFileTransferError.sourceOutsideAllowedRoot
        }
        guard contains(targetDirectory) else {
            throw ScopedFileTransferError.targetOutsideAllowedRoot
        }

        return try transferService.transfer(
            sourceURL: sourceURL,
            targetDirectory: targetDirectory,
            operation: operation,
            conflictPolicy: conflictPolicy
        )
    }

    private func contains(_ url: URL) -> Bool {
        let rootPath = canonicalPath(for: allowedRoot)
        let candidatePath = canonicalPath(for: url)
        return candidatePath == rootPath || candidatePath.hasPrefix(rootPath + "/")
    }

    private func canonicalPath(for url: URL) -> String {
        url.resolvingSymlinksInPath().standardizedFileURL.path
    }
}
