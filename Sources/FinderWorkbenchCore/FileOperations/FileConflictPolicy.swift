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
        let normalizedExistingNames = Set(existingNames.map { normalizedName($0) })

        guard normalizedExistingNames.contains(normalizedName(originalName)) else {
            return originalDestination
        }

        switch policy {
        case .skip:
            return nil
        case .replace:
            return originalDestination
        case .keepBoth:
            return targetDirectory.appendingPathComponent(
                nonConflictingName(for: sourceURL, normalizedExistingNames: normalizedExistingNames)
            )
        }
    }

    private func nonConflictingName(for sourceURL: URL, normalizedExistingNames: Set<String>) -> String {
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

            if !normalizedExistingNames.contains(normalizedName(candidate)) {
                return candidate
            }
            counter += 1
        }
    }

    private func normalizedName(_ name: String) -> String {
        name.lowercased()
    }
}
