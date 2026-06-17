# Finder Workbench Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first runnable foundation of Finder Workbench: a lightweight macOS Swift app shell with tested workspace/card models, transfer-mode behavior, persistence, and safe copy/move file operations.

**Architecture:** Start with a Swift Package that contains a macOS SwiftUI executable target plus a testable core library target. Keep Finder-like UI state and file-operation behavior in `FinderWorkbenchCore`, while the app target owns SwiftUI/AppKit presentation. This first slice intentionally avoids full Finder parity and focuses on a stable base that can be tested with `swift test`.

**Tech Stack:** Swift 6.1, Swift Package Manager, SwiftUI, AppKit, XCTest, Foundation file APIs.

---

## Scope

This plan implements the foundation slice, not the whole MVP. At the end of this plan:

- The project builds with `swift build`.
- Core behavior is covered by `swift test`.
- A minimal macOS app window runs with a thin toolbar and sample folder-card layout.
- Workspace/card state, strong lock rules, and transfer mode are modeled and tested.
- JSON persistence works for card layout metadata.
- Copy/move planning and temp-directory file operations are tested.

The next plan should connect real folder selection, security-scoped bookmarks, live directory listing, `NSTableView`, and drag-and-drop UI.

## File Structure

- Create: `Package.swift`
  - Defines `FinderWorkbenchCore` and `FinderWorkbenchCoreTests` first; the app executable target is added in Task 7.
- Create: `Sources/FinderWorkbenchCore/Models/FolderCard.swift`
  - Folder-card state, lock behavior, and geometry model.
- Create: `Sources/FinderWorkbenchCore/Models/Workspace.swift`
  - Workspace state and card collection behavior.
- Create: `Sources/FinderWorkbenchCore/Models/TransferMode.swift`
  - Copy default and one-shot move behavior.
- Create: `Sources/FinderWorkbenchCore/Persistence/WorkspaceStore.swift`
  - JSON save/load for workspace metadata.
- Create: `Sources/FinderWorkbenchCore/FileOperations/FileConflictPolicy.swift`
  - Conflict policy and planned destination names.
- Create: `Sources/FinderWorkbenchCore/FileOperations/FileTransferService.swift`
  - Copy/move executor for files and folders.
- Create: `Sources/FinderInOne/FinderInOneApp.swift`
  - SwiftUI app entry point.
- Create: `Sources/FinderInOne/WorkspaceView.swift`
  - Minimal window UI with thin toolbar and card grid.
- Create: `Sources/FinderInOne/FolderCardView.swift`
  - Visual card shell with corner actions.
- Create: `Tests/FinderWorkbenchCoreTests/FolderCardTests.swift`
- Create: `Tests/FinderWorkbenchCoreTests/TransferModeTests.swift`
- Create: `Tests/FinderWorkbenchCoreTests/WorkspaceStoreTests.swift`
- Create: `Tests/FinderWorkbenchCoreTests/FileTransferServiceTests.swift`

## Task 1: Create Swift Package Skeleton

**Files:**
- Create: `Package.swift`
- Create: `Sources/FinderWorkbenchCore/Models/FolderCard.swift`
- Create: `Tests/FinderWorkbenchCoreTests/FolderCardTests.swift`

- [ ] **Step 1: Write the failing model test**

Create `Tests/FinderWorkbenchCoreTests/FolderCardTests.swift`:

```swift
import XCTest
@testable import FinderWorkbenchCore

final class FolderCardTests: XCTestCase {
    func testLockedCardCannotMoveResizeOrClose() {
        var card = FolderCard(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            displayName: "Projects",
            folderPath: "/Users/test/Projects",
            frame: CardFrame(x: 10, y: 20, width: 300, height: 220),
            isLocked: true
        )

        XCTAssertFalse(card.canMove)
        XCTAssertFalse(card.canResize)
        XCTAssertFalse(card.canClose)

        let moved = card.move(toX: 50, y: 60)
        let resized = card.resize(width: 500, height: 400)

        XCTAssertFalse(moved)
        XCTAssertFalse(resized)
        XCTAssertEqual(card.frame, CardFrame(x: 10, y: 20, width: 300, height: 220))
    }

    func testUnlockedCardCanMoveResizeAndClose() {
        var card = FolderCard(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            displayName: "Client A",
            folderPath: "/Users/test/Client A",
            frame: CardFrame(x: 0, y: 0, width: 240, height: 180),
            isLocked: false
        )

        XCTAssertTrue(card.canMove)
        XCTAssertTrue(card.canResize)
        XCTAssertTrue(card.canClose)
        XCTAssertTrue(card.move(toX: 40, y: 80))
        XCTAssertTrue(card.resize(width: 420, height: 260))
        XCTAssertEqual(card.frame, CardFrame(x: 40, y: 80, width: 420, height: 260))
    }
}
```

- [ ] **Step 2: Run the test and verify it fails because the package does not exist**

Run:

```bash
swift test --filter FolderCardTests
```

Expected: FAIL with a package or module-not-found error.

- [ ] **Step 3: Create the package and minimal model implementation**

Create `Package.swift`:

```swift
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "FinderInOne",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "FinderWorkbenchCore", targets: ["FinderWorkbenchCore"])
    ],
    targets: [
        .target(name: "FinderWorkbenchCore"),
        .testTarget(
            name: "FinderWorkbenchCoreTests",
            dependencies: ["FinderWorkbenchCore"]
        )
    ]
)
```

Create `Sources/FinderWorkbenchCore/Models/FolderCard.swift`:

```swift
import Foundation

public struct CardFrame: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct FolderCard: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var displayName: String
    public var folderPath: String
    public var frame: CardFrame
    public var isLocked: Bool

    public init(id: UUID = UUID(), displayName: String, folderPath: String, frame: CardFrame, isLocked: Bool = false) {
        self.id = id
        self.displayName = displayName
        self.folderPath = folderPath
        self.frame = frame
        self.isLocked = isLocked
    }

    public var canMove: Bool { !isLocked }
    public var canResize: Bool { !isLocked }
    public var canClose: Bool { !isLocked }

    @discardableResult
    public mutating func move(toX x: Double, y: Double) -> Bool {
        guard canMove else { return false }
        frame.x = x
        frame.y = y
        return true
    }

    @discardableResult
    public mutating func resize(width: Double, height: Double) -> Bool {
        guard canResize else { return false }
        frame.width = max(180, width)
        frame.height = max(120, height)
        return true
    }
}
```

- [ ] **Step 4: Run the test and verify it passes**

Run:

```bash
swift test --filter FolderCardTests
```

Expected: PASS with `FolderCardTests` passing.

- [ ] **Step 5: Commit**

Run:

```bash
git add Package.swift Sources/FinderWorkbenchCore/Models/FolderCard.swift Tests/FinderWorkbenchCoreTests/FolderCardTests.swift
git commit -m "feat: scaffold Swift package and folder card model"
```

## Task 2: Add Transfer Mode State Machine

**Files:**
- Create: `Sources/FinderWorkbenchCore/Models/TransferMode.swift`
- Create: `Tests/FinderWorkbenchCoreTests/TransferModeTests.swift`

- [ ] **Step 1: Write the failing transfer-mode tests**

Create `Tests/FinderWorkbenchCoreTests/TransferModeTests.swift`:

```swift
import XCTest
@testable import FinderWorkbenchCore

final class TransferModeTests: XCTestCase {
    func testDefaultModeIsCopy() {
        let controller = TransferModeController()
        XCTAssertEqual(controller.mode, .copy)
        XCTAssertEqual(controller.currentOperation, .copy)
    }

    func testMoveOnceReturnsToCopyAfterOperationCompletes() {
        let controller = TransferModeController()
        controller.enableMoveOnce()

        XCTAssertEqual(controller.mode, .moveOnce)
        XCTAssertEqual(controller.currentOperation, .move)

        controller.operationDidFinish()

        XCTAssertEqual(controller.mode, .copy)
        XCTAssertEqual(controller.currentOperation, .copy)
    }

    func testMoveOnceReturnsToCopyAfterOperationFails() {
        let controller = TransferModeController()
        controller.enableMoveOnce()

        controller.operationDidFail()

        XCTAssertEqual(controller.mode, .copy)
        XCTAssertEqual(controller.currentOperation, .copy)
    }
}
```

- [ ] **Step 2: Run the test and verify it fails because transfer types do not exist**

Run:

```bash
swift test --filter TransferModeTests
```

Expected: FAIL with missing `TransferModeController`.

- [ ] **Step 3: Implement transfer mode**

Create `Sources/FinderWorkbenchCore/Models/TransferMode.swift`:

```swift
import Foundation

public enum TransferMode: String, Codable, Equatable, Sendable {
    case copy
    case moveOnce
}

public enum FileTransferOperation: String, Codable, Equatable, Sendable {
    case copy
    case move
}

public final class TransferModeController {
    public private(set) var mode: TransferMode

    public init(mode: TransferMode = .copy) {
        self.mode = mode
    }

    public var currentOperation: FileTransferOperation {
        switch mode {
        case .copy:
            return .copy
        case .moveOnce:
            return .move
        }
    }

    public func enableCopy() {
        mode = .copy
    }

    public func enableMoveOnce() {
        mode = .moveOnce
    }

    public func operationDidFinish() {
        mode = .copy
    }

    public func operationDidFail() {
        mode = .copy
    }
}
```

- [ ] **Step 4: Run the test and verify it passes**

Run:

```bash
swift test --filter TransferModeTests
```

Expected: PASS with `TransferModeTests` passing.

- [ ] **Step 5: Commit**

Run:

```bash
git add Sources/FinderWorkbenchCore/Models/TransferMode.swift Tests/FinderWorkbenchCoreTests/TransferModeTests.swift
git commit -m "feat: add copy and move-once transfer mode"
```

## Task 3: Add Workspace Card Collection Rules

**Files:**
- Create: `Sources/FinderWorkbenchCore/Models/Workspace.swift`
- Modify: `Tests/FinderWorkbenchCoreTests/FolderCardTests.swift`

- [ ] **Step 1: Add failing workspace tests**

Append to `Tests/FinderWorkbenchCoreTests/FolderCardTests.swift`:

```swift
extension FolderCardTests {
    func testWorkspaceClosesOnlyUnlockedCards() {
        let lockedID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        let unlockedID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
        var workspace = Workspace(cards: [
            FolderCard(id: lockedID, displayName: "Locked", folderPath: "/tmp/locked", frame: CardFrame(x: 0, y: 0, width: 200, height: 160), isLocked: true),
            FolderCard(id: unlockedID, displayName: "Unlocked", folderPath: "/tmp/unlocked", frame: CardFrame(x: 10, y: 10, width: 200, height: 160), isLocked: false)
        ])

        XCTAssertFalse(workspace.closeCard(id: lockedID))
        XCTAssertTrue(workspace.closeCard(id: unlockedID))
        XCTAssertEqual(workspace.cards.map(\.id), [lockedID])
    }

    func testWorkspaceAllowsMoreThanSixCards() {
        var workspace = Workspace()
        for index in 0..<8 {
            workspace.addCard(FolderCard(
                displayName: "Folder \(index)",
                folderPath: "/tmp/folder-\(index)",
                frame: CardFrame(x: Double(index * 20), y: 0, width: 220, height: 160)
            ))
        }

        XCTAssertEqual(workspace.cards.count, 8)
    }
}
```

- [ ] **Step 2: Run the tests and verify they fail because `Workspace` does not exist**

Run:

```bash
swift test --filter FolderCardTests
```

Expected: FAIL with missing `Workspace`.

- [ ] **Step 3: Implement workspace collection**

Create `Sources/FinderWorkbenchCore/Models/Workspace.swift`:

```swift
import Foundation

public struct Workspace: Codable, Equatable, Sendable {
    public private(set) var cards: [FolderCard]

    public init(cards: [FolderCard] = []) {
        self.cards = cards
    }

    public mutating func addCard(_ card: FolderCard) {
        cards.append(card)
    }

    @discardableResult
    public mutating func closeCard(id: UUID) -> Bool {
        guard let index = cards.firstIndex(where: { $0.id == id }) else {
            return false
        }
        guard cards[index].canClose else {
            return false
        }
        cards.remove(at: index)
        return true
    }

    public mutating func updateCard(_ card: FolderCard) {
        guard let index = cards.firstIndex(where: { $0.id == card.id }) else {
            return
        }
        cards[index] = card
    }
}
```

- [ ] **Step 4: Run the tests and verify they pass**

Run:

```bash
swift test --filter FolderCardTests
```

Expected: PASS with all `FolderCardTests` passing.

- [ ] **Step 5: Commit**

Run:

```bash
git add Sources/FinderWorkbenchCore/Models/Workspace.swift Tests/FinderWorkbenchCoreTests/FolderCardTests.swift
git commit -m "feat: add workspace card rules"
```

## Task 4: Add JSON Workspace Persistence

**Files:**
- Create: `Sources/FinderWorkbenchCore/Persistence/WorkspaceStore.swift`
- Create: `Tests/FinderWorkbenchCoreTests/WorkspaceStoreTests.swift`

- [ ] **Step 1: Write failing persistence tests**

Create `Tests/FinderWorkbenchCoreTests/WorkspaceStoreTests.swift`:

```swift
import XCTest
@testable import FinderWorkbenchCore

final class WorkspaceStoreTests: XCTestCase {
    func testSaveAndLoadWorkspaceRoundTripsCards() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = WorkspaceStore(fileURL: directory.appendingPathComponent("workspace.json"))
        let workspace = Workspace(cards: [
            FolderCard(
                id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
                displayName: "Client A",
                folderPath: "/Users/test/Client A",
                frame: CardFrame(x: 12, y: 24, width: 360, height: 260),
                isLocked: true
            )
        ])

        try store.save(workspace)
        let loaded = try store.load()

        XCTAssertEqual(loaded, workspace)
    }

    func testLoadMissingWorkspaceReturnsEmptyWorkspace() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = WorkspaceStore(fileURL: directory.appendingPathComponent("missing.json"))

        XCTAssertEqual(try store.load(), Workspace())
    }
}
```

- [ ] **Step 2: Run the tests and verify they fail because `WorkspaceStore` does not exist**

Run:

```bash
swift test --filter WorkspaceStoreTests
```

Expected: FAIL with missing `WorkspaceStore`.

- [ ] **Step 3: Implement JSON workspace store**

Create `Sources/FinderWorkbenchCore/Persistence/WorkspaceStore.swift`:

```swift
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
```

- [ ] **Step 4: Run the tests and verify they pass**

Run:

```bash
swift test --filter WorkspaceStoreTests
```

Expected: PASS with `WorkspaceStoreTests` passing.

- [ ] **Step 5: Commit**

Run:

```bash
git add Sources/FinderWorkbenchCore/Persistence/WorkspaceStore.swift Tests/FinderWorkbenchCoreTests/WorkspaceStoreTests.swift
git commit -m "feat: persist workspace layout as JSON"
```

## Task 5: Add File Conflict Planning

**Files:**
- Create: `Sources/FinderWorkbenchCore/FileOperations/FileConflictPolicy.swift`
- Modify: `Tests/FinderWorkbenchCoreTests/FileTransferServiceTests.swift`

- [ ] **Step 1: Write failing conflict-policy tests**

Create `Tests/FinderWorkbenchCoreTests/FileTransferServiceTests.swift`:

```swift
import XCTest
@testable import FinderWorkbenchCore

final class FileTransferServiceTests: XCTestCase {
    func testKeepBothAddsNumericSuffixBeforeExtension() {
        let planner = FileConflictPlanner()
        let source = URL(fileURLWithPath: "/tmp/Brief.pdf")
        let targetDirectory = URL(fileURLWithPath: "/tmp/Target", isDirectory: true)
        let existingNames: Set<String> = ["Brief.pdf", "Brief 2.pdf"]

        let planned = planner.destinationURL(
            for: source,
            in: targetDirectory,
            existingNames: existingNames,
            policy: .keepBoth
        )

        XCTAssertEqual(planned.lastPathComponent, "Brief 3.pdf")
    }

    func testSkipReturnsNilWhenConflictExists() {
        let planner = FileConflictPlanner()
        let source = URL(fileURLWithPath: "/tmp/Brief.pdf")
        let targetDirectory = URL(fileURLWithPath: "/tmp/Target", isDirectory: true)

        let planned = planner.destinationURL(
            for: source,
            in: targetDirectory,
            existingNames: ["Brief.pdf"],
            policy: .skip
        )

        XCTAssertNil(planned)
    }

    func testReplaceUsesOriginalName() {
        let planner = FileConflictPlanner()
        let source = URL(fileURLWithPath: "/tmp/Brief.pdf")
        let targetDirectory = URL(fileURLWithPath: "/tmp/Target", isDirectory: true)

        let planned = planner.destinationURL(
            for: source,
            in: targetDirectory,
            existingNames: ["Brief.pdf"],
            policy: .replace
        )

        XCTAssertEqual(planned?.lastPathComponent, "Brief.pdf")
    }
}
```

- [ ] **Step 2: Run the tests and verify they fail because conflict types do not exist**

Run:

```bash
swift test --filter FileTransferServiceTests
```

Expected: FAIL with missing `FileConflictPlanner`.

- [ ] **Step 3: Implement conflict policy planner**

Create `Sources/FinderWorkbenchCore/FileOperations/FileConflictPolicy.swift`:

```swift
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
```

- [ ] **Step 4: Run the tests and verify they pass**

Run:

```bash
swift test --filter FileTransferServiceTests
```

Expected: PASS with conflict-policy tests passing.

- [ ] **Step 5: Commit**

Run:

```bash
git add Sources/FinderWorkbenchCore/FileOperations/FileConflictPolicy.swift Tests/FinderWorkbenchCoreTests/FileTransferServiceTests.swift
git commit -m "feat: plan same-name file conflicts"
```

## Task 6: Add Copy and Move File Operations

**Files:**
- Create: `Sources/FinderWorkbenchCore/FileOperations/FileTransferService.swift`
- Modify: `Tests/FinderWorkbenchCoreTests/FileTransferServiceTests.swift`

- [ ] **Step 1: Add failing copy/move tests**

Append to `Tests/FinderWorkbenchCoreTests/FileTransferServiceTests.swift`:

```swift
extension FileTransferServiceTests {
    func testCopyFileKeepsOriginalAndCreatesTarget() throws {
        let fixture = try FileTransferFixture()
        defer { fixture.cleanUp() }
        let sourceFile = try fixture.createSourceFile(named: "Brief.txt", contents: "hello")
        let service = FileTransferService()

        let result = try service.transfer(
            sourceURL: sourceFile,
            targetDirectory: fixture.targetDirectory,
            operation: .copy,
            conflictPolicy: .replace
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceFile.path))
        let destinationURL = try XCTUnwrap(result.destinationURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: destinationURL.path))
        XCTAssertEqual(try String(contentsOf: destinationURL, encoding: .utf8), "hello")
    }

    func testMoveFileRemovesOriginalAndCreatesTarget() throws {
        let fixture = try FileTransferFixture()
        defer { fixture.cleanUp() }
        let sourceFile = try fixture.createSourceFile(named: "MoveMe.txt", contents: "move")
        let service = FileTransferService()

        let result = try service.transfer(
            sourceURL: sourceFile,
            targetDirectory: fixture.targetDirectory,
            operation: .move,
            conflictPolicy: .replace
        )

        XCTAssertFalse(FileManager.default.fileExists(atPath: sourceFile.path))
        let destinationURL = try XCTUnwrap(result.destinationURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: destinationURL.path))
        XCTAssertEqual(try String(contentsOf: destinationURL, encoding: .utf8), "move")
    }

    func testSkipConflictDoesNotCreateNewFile() throws {
        let fixture = try FileTransferFixture()
        defer { fixture.cleanUp() }
        let sourceFile = try fixture.createSourceFile(named: "Same.txt", contents: "source")
        _ = try fixture.createTargetFile(named: "Same.txt", contents: "target")
        let service = FileTransferService()

        let result = try service.transfer(
            sourceURL: sourceFile,
            targetDirectory: fixture.targetDirectory,
            operation: .copy,
            conflictPolicy: .skip
        )

        XCTAssertEqual(result, .skipped)
        XCTAssertEqual(try String(contentsOf: fixture.targetDirectory.appendingPathComponent("Same.txt"), encoding: .utf8), "target")
    }
}

private struct FileTransferFixture {
    let root: URL
    let sourceDirectory: URL
    let targetDirectory: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        sourceDirectory = root.appendingPathComponent("Source", isDirectory: true)
        targetDirectory = root.appendingPathComponent("Target", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: targetDirectory, withIntermediateDirectories: true)
    }

    func createSourceFile(named name: String, contents: String) throws -> URL {
        let url = sourceDirectory.appendingPathComponent(name)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func createTargetFile(named name: String, contents: String) throws -> URL {
        let url = targetDirectory.appendingPathComponent(name)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func cleanUp() {
        try? FileManager.default.removeItem(at: root)
    }
}
```

- [ ] **Step 2: Run the tests and verify they fail because transfer service does not exist**

Run:

```bash
swift test --filter FileTransferServiceTests
```

Expected: FAIL with missing `FileTransferService`.

- [ ] **Step 3: Implement file transfer service**

Create `Sources/FinderWorkbenchCore/FileOperations/FileTransferService.swift`:

```swift
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
```

- [ ] **Step 4: Run the tests and verify they pass**

Run:

```bash
swift test --filter FileTransferServiceTests
```

Expected: PASS with all file-transfer tests passing.

- [ ] **Step 5: Commit**

Run:

```bash
git add Sources/FinderWorkbenchCore/FileOperations/FileTransferService.swift Tests/FinderWorkbenchCoreTests/FileTransferServiceTests.swift
git commit -m "feat: copy and move files safely"
```

## Task 7: Add Minimal SwiftUI App Shell

**Files:**
- Modify: `Package.swift`
- Create: `Sources/FinderInOne/FinderInOneApp.swift`
- Create: `Sources/FinderInOne/WorkspaceView.swift`
- Create: `Sources/FinderInOne/FolderCardView.swift`

- [ ] **Step 1: Add executable target declaration before app source exists**

Modify `Package.swift`:

```swift
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "FinderInOne",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "FinderWorkbenchCore", targets: ["FinderWorkbenchCore"]),
        .executable(name: "FinderInOne", targets: ["FinderInOne"])
    ],
    targets: [
        .target(name: "FinderWorkbenchCore"),
        .executableTarget(
            name: "FinderInOne",
            dependencies: ["FinderWorkbenchCore"]
        ),
        .testTarget(
            name: "FinderWorkbenchCoreTests",
            dependencies: ["FinderWorkbenchCore"]
        )
    ]
)
```

- [ ] **Step 2: Build and verify executable target fails before app files exist**

Run:

```bash
swift build
```

Expected: FAIL because the executable target has no source files.

- [ ] **Step 3: Create SwiftUI app entry point**

Create `Sources/FinderInOne/FinderInOneApp.swift`:

```swift
import SwiftUI
import FinderWorkbenchCore

@main
struct FinderInOneApp: App {
    var body: some Scene {
        WindowGroup {
            WorkspaceView()
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
    }
}
```

- [ ] **Step 4: Create minimal workspace view**

Create `Sources/FinderInOne/WorkspaceView.swift`:

```swift
import SwiftUI
import FinderWorkbenchCore

struct WorkspaceView: View {
    @State private var workspace = Workspace(cards: WorkspaceView.sampleCards)
    @State private var transferMode = TransferMode.copy

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 10)], spacing: 10) {
                    ForEach(workspace.cards) { card in
                        FolderCardView(card: card)
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
            Button("+") {}
                .help("Add folder")
            Button("Copy") {
                transferMode = .copy
            }
            .buttonStyle(.borderedProminent)
            Button("Move once") {
                transferMode = .moveOnce
            }
            Text("\(workspace.cards.count) folders")
                .foregroundStyle(.secondary)
            Spacer()
            TextField("Search", text: .constant(""))
                .textFieldStyle(.roundedBorder)
                .frame(width: 160)
        }
        .font(.system(size: 12))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private static let sampleCards: [FolderCard] = [
        FolderCard(displayName: "Client A", folderPath: "/Users/test/Client A", frame: CardFrame(x: 0, y: 0, width: 360, height: 260)),
        FolderCard(displayName: "Projects", folderPath: "/Users/test/Projects", frame: CardFrame(x: 0, y: 0, width: 360, height: 220), isLocked: true),
        FolderCard(displayName: "Downloads", folderPath: "/Users/test/Downloads", frame: CardFrame(x: 0, y: 0, width: 260, height: 180))
    ]
}
```

- [ ] **Step 5: Create minimal folder card view**

Create `Sources/FinderInOne/FolderCardView.swift`:

```swift
import SwiftUI
import FinderWorkbenchCore

struct FolderCardView: View {
    let card: FolderCard

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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
                    Button(card.isLocked ? "Unlock" : "Lock") {}
                    Button("Finder") {}
                    if card.canClose {
                        Button("Close") {}
                    }
                }
                .font(.system(size: 11))
            }

            Divider()

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                GridRow {
                    Text("Name").bold()
                    Text("Date").bold()
                    Text("Kind").bold()
                }
                GridRow {
                    Text("Brief.pdf")
                    Text("Today")
                    Text("PDF")
                }
                GridRow {
                    Text("Images")
                    Text("Jun 14")
                    Text("Folder")
                }
                GridRow {
                    Text("Notes.md")
                    Text("Jun 11")
                    Text("Markdown")
                }
            }
            .font(.system(size: 12, design: .monospaced))

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(card.isLocked ? Color.accentColor.opacity(0.55) : Color.secondary.opacity(0.25), lineWidth: 1)
        )
    }
}
```

- [ ] **Step 6: Build and test**

Run:

```bash
swift build
swift test
```

Expected: Both commands exit 0.

- [ ] **Step 7: Commit**

Run:

```bash
git add Package.swift Sources/FinderInOne/FinderInOneApp.swift Sources/FinderInOne/WorkspaceView.swift Sources/FinderInOne/FolderCardView.swift
git commit -m "feat: add minimal Finder Workbench app shell"
```

## Task 8: Final Verification for Foundation Slice

**Files:**
- No source changes unless verification exposes an issue.

- [ ] **Step 1: Run complete test suite**

Run:

```bash
swift test
```

Expected: exit 0 with all tests passing.

- [ ] **Step 2: Run complete build**

Run:

```bash
swift build
```

Expected: exit 0 with both `FinderWorkbenchCore` and `FinderInOne` building.

- [ ] **Step 3: Inspect git status**

Run:

```bash
git status --short
```

Expected: no unstaged source changes after all task commits.

- [ ] **Step 4: Push**

Run:

```bash
git push
```

Expected: remote `origin/main` receives all foundation commits.

## Self-Review Checklist

- Spec coverage:
  - Strong lock rules are covered by Task 1 and Task 3.
  - More-than-six dynamic cards are covered by Task 3.
  - Copy default and Move once behavior are covered by Task 2.
  - JSON persistence is covered by Task 4.
  - Same-name conflict planning is covered by Task 5.
  - Copy and move file operations are covered by Task 6.
  - Minimal UI and card corner actions are covered by Task 7.
  - Full security-scoped bookmarks, real folder picker, live file listing, and UI drag/drop are assigned to the next implementation plan.
- Placeholder scan:
  - The plan contains no `TBD`, `TODO`, or unspecified implementation steps.
- Type consistency:
  - `TransferMode`, `FileTransferOperation`, `FolderCard`, `Workspace`, `WorkspaceStore`, `FileConflictPlanner`, and `FileTransferService` names are consistent across tests and implementation steps.
