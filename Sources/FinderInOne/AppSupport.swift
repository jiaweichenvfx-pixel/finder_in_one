import Foundation

enum AppSupport {
    static var workspaceStoreURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base
            .appendingPathComponent("FinderInOne", isDirectory: true)
            .appendingPathComponent("workspace.json")
    }

    static var templateStoreURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base
            .appendingPathComponent("FinderInOne", isDirectory: true)
            .appendingPathComponent("templates.json")
    }
}
