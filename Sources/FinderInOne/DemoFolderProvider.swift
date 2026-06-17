import Foundation

struct DemoFolder {
    let url: URL
    let bookmarkData: Data?
}

struct DemoFolderProvider {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func createDemoFolder() throws -> DemoFolder {
        let root = try demoRoot()
        let index = try nextFolderIndex(in: root)
        let folderURL = root.appendingPathComponent("Demo Folder \(index)", isDirectory: true)
        try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
        try seedFolder(at: folderURL, index: index)
        return DemoFolder(url: folderURL, bookmarkData: nil)
    }

    private func demoRoot() throws -> URL {
        let current = URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
        let root = current.appendingPathComponent(".finder-workbench-demo-folders", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func nextFolderIndex(in root: URL) throws -> Int {
        let names = try fileManager.contentsOfDirectory(atPath: root.path)
        var index = 1
        while names.contains("Demo Folder \(index)") {
            index += 1
        }
        return index
    }

    private func seedFolder(at folderURL: URL, index: Int) throws {
        try "Demo note \(index)\n".write(to: folderURL.appendingPathComponent("Note \(index).txt"), atomically: true, encoding: .utf8)
        try fileManager.createDirectory(at: folderURL.appendingPathComponent("Assets", isDirectory: true), withIntermediateDirectories: true)
    }
}
