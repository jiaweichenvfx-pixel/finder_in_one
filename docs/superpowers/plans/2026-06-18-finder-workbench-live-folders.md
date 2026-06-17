# Finder Workbench Live Folders Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace sample-only folder cards with real project-local folders that list live directory contents, persist across launches, and can open in Finder.

**Architecture:** Keep filesystem behavior in `FinderWorkbenchCore` and keep macOS UI integration in `FinderInOne`. Add a small directory-listing service, extend folder cards with optional bookmark data for later sandbox work, and introduce an observable workspace view model that coordinates persistence, project-local demo folder adding, listing, locking, closing, and Finder handoff.

**Tech Stack:** Swift 6.1, Swift Package Manager, SwiftUI, AppKit (`NSOpenPanel`, `NSWorkspace`), XCTest, Foundation file APIs.

---

## Scope

Important safety constraint from the user: this stage must operate only inside this repository/worktree. Do not add arbitrary system folder picking yet, and do not perform file operations outside the project-local demo folders.

This stage implements:

- Real directory listing in each folder card.
- `+` button adds a project-local demo folder under `.finder-workbench-demo-folders/`.
- Project-local demo folders become cards.
- Workspace is saved and loaded from app support JSON.
- Folder cards store optional security-scoped bookmark data for future sandbox compatibility.
- `Open in Finder` opens the card folder with `NSWorkspace`.
- Unavailable folders render a lightweight error state.

This stage does not implement:

- Drag-and-drop file transfer UI.
- Card drag-to-move or resize handles.
- Directory watching/live refresh notifications.
- Search across cards.
- Full AppKit `NSTableView`; SwiftUI list rows are acceptable for this stage.

## File Structure

- Modify: `Sources/FinderWorkbenchCore/Models/FolderCard.swift`
  - Add optional `bookmarkData` and helper `folderURL`.
- Create: `Sources/FinderWorkbenchCore/Models/FileItem.swift`
  - Represents one listed file or subfolder.
- Create: `Sources/FinderWorkbenchCore/FileSystem/DirectoryListingService.swift`
  - Reads one directory and returns sorted `FileItem` values.
- Create: `Tests/FinderWorkbenchCoreTests/DirectoryListingServiceTests.swift`
  - Covers listing files/folders, hidden-file skipping, and sort order.
- Modify: `Tests/FinderWorkbenchCoreTests/FolderCardTests.swift`
  - Covers default bookmark compatibility and `folderURL`.
- Create: `Sources/FinderInOne/AppSupport.swift`
  - Resolves app support workspace store URL.
- Create: `Sources/FinderInOne/DemoFolderProvider.swift`
  - Creates project-local demo folders under `.finder-workbench-demo-folders/`.
- Create: `Sources/FinderInOne/FinderOpening.swift`
  - Wraps `NSWorkspace` opening.
- Create: `Sources/FinderInOne/WorkspaceViewModel.swift`
  - Observable app state for workspace, persistence, folder adding, listing cache, lock/close, and Finder opening.
- Modify: `Sources/FinderInOne/WorkspaceView.swift`
  - Use `WorkspaceViewModel` instead of hardcoded sample cards.
- Modify: `Sources/FinderInOne/FolderCardView.swift`
  - Render real file rows, unavailable state, and enabled Finder action.

## Task 1: Extend FolderCard for Bookmarks

**Files:**
- Modify: `Sources/FinderWorkbenchCore/Models/FolderCard.swift`
- Modify: `Tests/FinderWorkbenchCoreTests/FolderCardTests.swift`

- [ ] **Step 1: Add failing tests**

Append to `FolderCardTests`:

```swift
extension FolderCardTests {
    func testFolderCardDefaultsBookmarkDataToNil() {
        let card = FolderCard(
            displayName: "Projects",
            folderPath: "/tmp/Projects",
            frame: CardFrame(x: 0, y: 0, width: 240, height: 180)
        )

        XCTAssertNil(card.bookmarkData)
    }

    func testFolderCardExposesFolderURL() {
        let card = FolderCard(
            displayName: "Projects",
            folderPath: "/tmp/Projects",
            frame: CardFrame(x: 0, y: 0, width: 240, height: 180)
        )

        XCTAssertEqual(card.folderURL, URL(fileURLWithPath: "/tmp/Projects", isDirectory: true))
    }
}
```

- [ ] **Step 2: Run red test**

Run:

```bash
swift test --filter FolderCardTests
```

Expected: FAIL because `bookmarkData` and `folderURL` do not exist.

- [ ] **Step 3: Implement model extension**

Update `FolderCard`:

```swift
public var bookmarkData: Data?

public init(id: UUID = UUID(), displayName: String, folderPath: String, frame: CardFrame, isLocked: Bool = false, bookmarkData: Data? = nil) {
    self.id = id
    self.displayName = displayName
    self.folderPath = folderPath
    self.frame = frame
    self.isLocked = isLocked
    self.bookmarkData = bookmarkData
}

public var folderURL: URL {
    URL(fileURLWithPath: folderPath, isDirectory: true)
}
```

Keep existing stored properties and Codable compatibility.

- [ ] **Step 4: Run green tests**

Run:

```bash
swift test --filter FolderCardTests
swift test
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/FinderWorkbenchCore/Models/FolderCard.swift Tests/FinderWorkbenchCoreTests/FolderCardTests.swift
git commit -m "feat: store folder bookmark metadata"
```

## Task 2: Add Directory Listing Service

**Files:**
- Create: `Sources/FinderWorkbenchCore/Models/FileItem.swift`
- Create: `Sources/FinderWorkbenchCore/FileSystem/DirectoryListingService.swift`
- Create: `Tests/FinderWorkbenchCoreTests/DirectoryListingServiceTests.swift`

- [ ] **Step 1: Write failing tests**

Create `DirectoryListingServiceTests.swift`:

```swift
import XCTest
@testable import FinderWorkbenchCore

final class DirectoryListingServiceTests: XCTestCase {
    func testListsVisibleFilesAndFoldersSortedByFolderThenName() throws {
        let fixture = try DirectoryListingFixture()
        defer { fixture.cleanUp() }
        try fixture.createFile("zeta.txt", contents: "z")
        try fixture.createFolder("Assets")
        try fixture.createFile("alpha.txt", contents: "a")

        let service = DirectoryListingService()
        let items = try service.items(in: fixture.root)

        XCTAssertEqual(items.map(\.name), ["Assets", "alpha.txt", "zeta.txt"])
        XCTAssertEqual(items.map(\.isDirectory), [true, false, false])
    }

    func testSkipsHiddenFiles() throws {
        let fixture = try DirectoryListingFixture()
        defer { fixture.cleanUp() }
        try fixture.createFile(".secret", contents: "hidden")
        try fixture.createFile("visible.txt", contents: "visible")

        let items = try DirectoryListingService().items(in: fixture.root)

        XCTAssertEqual(items.map(\.name), ["visible.txt"])
    }

    func testReportsFileSizeAndKind() throws {
        let fixture = try DirectoryListingFixture()
        defer { fixture.cleanUp() }
        try fixture.createFile("note.txt", contents: "hello")

        let item = try XCTUnwrap(try DirectoryListingService().items(in: fixture.root).first)

        XCTAssertEqual(item.name, "note.txt")
        XCTAssertEqual(item.byteSize, 5)
        XCTAssertEqual(item.kind, "File")
    }
}

private struct DirectoryListingFixture {
    let root: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func createFile(_ name: String, contents: String) throws {
        try contents.write(to: root.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }

    func createFolder(_ name: String) throws {
        try FileManager.default.createDirectory(at: root.appendingPathComponent(name, isDirectory: true), withIntermediateDirectories: true)
    }

    func cleanUp() {
        try? FileManager.default.removeItem(at: root)
    }
}
```

- [ ] **Step 2: Run red test**

```bash
swift test --filter DirectoryListingServiceTests
```

Expected: FAIL because `DirectoryListingService` and `FileItem` do not exist.

- [ ] **Step 3: Implement `FileItem`**

Create `FileItem.swift`:

```swift
import Foundation

public struct FileItem: Identifiable, Equatable, Sendable {
    public let id: URL
    public let url: URL
    public let name: String
    public let modifiedAt: Date?
    public let byteSize: Int64?
    public let isDirectory: Bool

    public init(url: URL, name: String, modifiedAt: Date?, byteSize: Int64?, isDirectory: Bool) {
        self.id = url
        self.url = url
        self.name = name
        self.modifiedAt = modifiedAt
        self.byteSize = byteSize
        self.isDirectory = isDirectory
    }

    public var kind: String {
        isDirectory ? "Folder" : "File"
    }
}
```

- [ ] **Step 4: Implement `DirectoryListingService`**

Create `DirectoryListingService.swift`:

```swift
import Foundation

public struct DirectoryListingService: Sendable {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func items(in directoryURL: URL) throws -> [FileItem] {
        let urls = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        )

        return try urls.map(makeItem(url:)).sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory {
                return lhs.isDirectory && !rhs.isDirectory
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    private func makeItem(url: URL) throws -> FileItem {
        let values = try url.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey, .fileSizeKey])
        let isDirectory = values.isDirectory ?? false
        return FileItem(
            url: url,
            name: url.lastPathComponent,
            modifiedAt: values.contentModificationDate,
            byteSize: isDirectory ? nil : values.fileSize.map(Int64.init),
            isDirectory: isDirectory
        )
    }
}
```

- [ ] **Step 5: Run green tests**

```bash
swift test --filter DirectoryListingServiceTests
swift test
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/FinderWorkbenchCore/Models/FileItem.swift Sources/FinderWorkbenchCore/FileSystem/DirectoryListingService.swift Tests/FinderWorkbenchCoreTests/DirectoryListingServiceTests.swift
git commit -m "feat: list directory contents"
```

## Task 3: Add Project-Local App Integration Services

**Files:**
- Create: `Sources/FinderInOne/AppSupport.swift`
- Create: `Sources/FinderInOne/DemoFolderProvider.swift`
- Create: `Sources/FinderInOne/FinderOpening.swift`

- [ ] **Step 1: Create app support path helper**

Create `AppSupport.swift`:

```swift
import Foundation

enum AppSupport {
    static var workspaceStoreURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base
            .appendingPathComponent("FinderInOne", isDirectory: true)
            .appendingPathComponent("workspace.json")
    }
}
```

- [ ] **Step 2: Create project-local demo folder provider**

Create `DemoFolderProvider.swift`:

```swift
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
```

- [ ] **Step 3: Create Finder opening service**

Create `FinderOpening.swift`:

```swift
import AppKit
import Foundation

@MainActor
struct FinderOpening {
    func openInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
```

- [ ] **Step 4: Build**

```bash
swift build
swift test
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/FinderInOne/AppSupport.swift Sources/FinderInOne/DemoFolderProvider.swift Sources/FinderInOne/FinderOpening.swift
git commit -m "feat: add project-local folder integration services"
```

## Task 4: Add Workspace View Model

**Files:**
- Create: `Sources/FinderInOne/WorkspaceViewModel.swift`

- [ ] **Step 1: Create view model**

Create `WorkspaceViewModel.swift`:

```swift
import FinderWorkbenchCore
import Foundation
import Observation

@MainActor
@Observable
final class WorkspaceViewModel {
    var workspace: Workspace
    var transferMode: TransferMode = .copy
    var itemsByCardID: [UUID: [FileItem]] = [:]
    var errorsByCardID: [UUID: String] = [:]

    private let store: WorkspaceStore
    private let listingService: DirectoryListingService
    private let demoFolderProvider: DemoFolderProvider
    private let finderOpening: FinderOpening

    init(
        store: WorkspaceStore = WorkspaceStore(fileURL: AppSupport.workspaceStoreURL),
        listingService: DirectoryListingService = DirectoryListingService(),
        demoFolderProvider: DemoFolderProvider = DemoFolderProvider(),
        finderOpening: FinderOpening = FinderOpening()
    ) {
        self.store = store
        self.listingService = listingService
        self.demoFolderProvider = demoFolderProvider
        self.finderOpening = finderOpening
        self.workspace = (try? store.load()) ?? Workspace()
        refreshAllCards()
    }

    func addDemoFolder() {
        guard let demoFolder = try? demoFolderProvider.createDemoFolder() else {
            return
        }

        let card = FolderCard(
            displayName: demoFolder.url.lastPathComponent,
            folderPath: demoFolder.url.path,
            frame: CardFrame(x: 0, y: 0, width: 360, height: 240),
            bookmarkData: demoFolder.bookmarkData
        )
        workspace.addCard(card)
        refresh(card: card)
        save()
    }

    func toggleLock(for id: UUID) {
        guard var card = workspace.cards.first(where: { $0.id == id }) else {
            return
        }
        card.isLocked.toggle()
        workspace.updateCard(card)
        save()
    }

    func closeCard(id: UUID) {
        guard workspace.closeCard(id: id) else {
            return
        }
        itemsByCardID[id] = nil
        errorsByCardID[id] = nil
        save()
    }

    func openInFinder(card: FolderCard) {
        finderOpening.openInFinder(card.folderURL)
    }

    func refresh(card: FolderCard) {
        do {
            itemsByCardID[card.id] = try listingService.items(in: card.folderURL)
            errorsByCardID[card.id] = nil
        } catch {
            itemsByCardID[card.id] = []
            errorsByCardID[card.id] = "Folder unavailable"
        }
    }

    func refreshAllCards() {
        for card in workspace.cards {
            refresh(card: card)
        }
    }

    private func save() {
        try? store.save(workspace)
    }
}
```

- [ ] **Step 2: Build**

```bash
swift build
swift test
```

Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add Sources/FinderInOne/WorkspaceViewModel.swift
git commit -m "feat: coordinate live folder workspace state"
```

## Task 5: Wire Live Folders Into SwiftUI

**Files:**
- Modify: `Sources/FinderInOne/WorkspaceView.swift`
- Modify: `Sources/FinderInOne/FolderCardView.swift`

- [ ] **Step 1: Update `FolderCardView`**

Replace sample rows with real items and error rendering:

```swift
struct FolderCardView: View {
    let card: FolderCard
    let items: [FileItem]
    let errorMessage: String?
    let onToggleLock: () -> Void
    let onOpenInFinder: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            Divider()
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            } else if items.isEmpty {
                Text("No visible items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            } else {
                fileRows
            }
        }
        .padding(10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(card.isLocked ? Color.accentColor.opacity(0.55) : Color.secondary.opacity(0.25), lineWidth: 1)
        )
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(card.displayName)
                    .font(.headline)
                Text(card.folderPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            HStack(spacing: 4) {
                Button(card.isLocked ? "Unlock" : "Lock", action: onToggleLock)
                Button("Finder", action: onOpenInFinder)
                if card.canClose {
                    Button("Close", action: onClose)
                }
            }
            .font(.system(size: 11))
        }
    }

    private var fileRows: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
            GridRow {
                Text("Name").bold()
                Text("Modified").bold()
                Text("Size").bold()
                Text("Kind").bold()
            }
            ForEach(items.prefix(20)) { item in
                GridRow {
                    Text(item.name).lineLimit(1)
                    Text(Self.dateFormatter.string(from: item.modifiedAt ?? .distantPast))
                    Text(item.byteSize.map(Self.byteFormatter.string(fromByteCount:)) ?? "--")
                    Text(item.kind)
                }
            }
        }
        .font(.system(size: 12, design: .monospaced))
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()

    private static let byteFormatter = ByteCountFormatter()
}
```

- [ ] **Step 2: Update `WorkspaceView`**

Use the view model:

```swift
struct WorkspaceView: View {
    @State private var viewModel = WorkspaceViewModel()

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 10)], spacing: 10) {
                    ForEach(viewModel.workspace.cards) { card in
                        FolderCardView(
                            card: card,
                            items: viewModel.itemsByCardID[card.id] ?? [],
                            errorMessage: viewModel.errorsByCardID[card.id],
                            onToggleLock: { viewModel.toggleLock(for: card.id) },
                            onOpenInFinder: { viewModel.openInFinder(card: card) },
                            onClose: { viewModel.closeCard(id: card.id) }
                        )
                        .frame(height: card.frame.height)
                    }
                }
                .padding(10)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Button("+") {
                viewModel.addDemoFolder()
            }
            .help("Add folder")
            modeButton("Copy", isSelected: viewModel.transferMode == .copy) {
                viewModel.transferMode = .copy
            }
            modeButton("Move once", isSelected: viewModel.transferMode == .moveOnce) {
                viewModel.transferMode = .moveOnce
            }
            Text("\(viewModel.workspace.cards.count) folders")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .font(.system(size: 12))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }
}
```

Keep the existing `modeButton` helper.

- [ ] **Step 3: Build and test**

```bash
swift build
swift test
```

Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add Sources/FinderInOne/WorkspaceView.swift Sources/FinderInOne/FolderCardView.swift
git commit -m "feat: show live folder contents in cards"
```

## Task 6: Final Verification and Push

**Files:**
- No source changes unless verification exposes an issue.

- [ ] **Step 1: Run full verification**

```bash
swift build
swift test
git status --short
```

Expected: build passes, tests pass, worktree clean.

- [ ] **Step 2: Push branch**

```bash
git push -u origin codex/finder-workbench-live-folders
```

Expected: branch is pushed to GitHub.

## Self-Review Checklist

- `+` toolbar button creates project-local demo folders only.
- Folder cards show actual directory rows rather than sample rows.
- Workspace state is persisted through `WorkspaceStore`.
- Folder cards can open their represented folder in Finder.
- Locked cards still cannot close.
- Unavailable folders render a recoverable lightweight state.
- No whole-disk scanning, directory watching, drag/drop transfer UI, or unrelated Finder parity was added.
- No arbitrary user folder selection is added in this stage.
