import Foundation

public enum FileConflictPolicy: Equatable, Sendable {
    case keepBoth
    case replace
    case skip
}

public struct FileConflictPlanner: Sendable {
    public init() {}

    public func destinationURL(
        for sourceURL: URL,
        in targetDirectory: URL,
        existingNames: Set<String>,
        policy: FileConflictPolicy
    ) -> URL? {
        let originalName = sourceURL.lastPathComponent
        let originalDestination = targetDirectory.appendingPathComponent(originalName)

        guard existingNames.contains(originalName) else {
            return originalDestination
        }

        switch policy {
        case .skip:
            return nil
        case .replace:
            return originalDestination
        case .keepBoth:
            return targetDirectory.appendingPathComponent(nonConflictingName(for: sourceURL, existingNames: existingNames))
        }
    }

    private func nonConflictingName(for sourceURL: URL, existingNames: Set<String>) -> String {
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let pathExtension = sourceURL.pathExtension
        var counter = 2

        while true {
            let candidate: String
            if pathExtension.isEmpty {
                candidate = "\(baseName) \(counter)"
            } else {
                candidate = "\(baseName) \(counter).\(pathExtension)"
            }

            if !existingNames.contains(candidate) {
                return candidate
            }
            counter += 1
        }
    }
}
