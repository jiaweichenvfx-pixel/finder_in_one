import AppKit
import Foundation

@MainActor
struct FolderPicking {
    func pickFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.message = "Choose a folder to add to Finder in One"

        NSApp.activate(ignoringOtherApps: true)
        let response = panel.runModal()
        guard response == .OK else {
            return nil
        }
        return panel.url
    }
}
