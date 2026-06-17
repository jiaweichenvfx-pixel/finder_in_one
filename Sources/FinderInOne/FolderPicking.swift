import AppKit
import Foundation

@MainActor
struct FolderPicking {
    func pickFolder() async -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.message = "Choose a folder to add to Finder in One"

        let response = await panel.begin()
        guard response == .OK else {
            return nil
        }
        return panel.url
    }
}
