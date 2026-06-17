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
    private let allowedTransferRoot: URL?

    init(
        store: WorkspaceStore = WorkspaceStore(fileURL: AppSupport.workspaceStoreURL),
        listingService: DirectoryListingService = DirectoryListingService(),
        demoFolderProvider: DemoFolderProvider = DemoFolderProvider(),
        finderOpening: FinderOpening = FinderOpening(),
        allowedTransferRoot: URL? = nil
    ) {
        self.store = store
        self.listingService = listingService
        self.demoFolderProvider = demoFolderProvider
        self.finderOpening = finderOpening
        self.allowedTransferRoot = allowedTransferRoot
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

    @discardableResult
    func resizeCard(id: UUID, width: Double, height: Double) -> Bool {
        guard var card = workspace.cards.first(where: { $0.id == id }) else {
            return false
        }
        guard card.resize(width: width, height: height) else {
            return false
        }
        workspace.updateCard(card)
        save()
        return true
    }

    func openInFinder(card: FolderCard) {
        finderOpening.openInFinder(card.folderURL)
    }

    @discardableResult
    func transfer(item: FileItem, to targetCard: FolderCard) -> Bool {
        let operation = currentTransferOperation
        defer {
            if transferMode == .moveOnce {
                transferMode = .copy
            }
        }

        guard let transferRoot = resolvedAllowedTransferRoot() else {
            errorsByCardID[targetCard.id] = "Transfer root unavailable"
            return false
        }

        do {
            _ = try ScopedFileTransferService(allowedRoot: transferRoot).transfer(
                sourceURL: item.url,
                targetDirectory: targetCard.folderURL,
                operation: operation,
                conflictPolicy: .keepBoth
            )
            refreshImpactedCards(for: item, targetCard: targetCard)
            errorsByCardID[targetCard.id] = nil
            return true
        } catch {
            errorsByCardID[targetCard.id] = "Transfer failed"
            return false
        }
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

    private var currentTransferOperation: FileTransferOperation {
        switch transferMode {
        case .copy:
            return .copy
        case .moveOnce:
            return .move
        }
    }

    private func resolvedAllowedTransferRoot() -> URL? {
        if let allowedTransferRoot {
            return allowedTransferRoot
        }
        return try? demoFolderProvider.demoRootURL()
    }

    private func refreshImpactedCards(for item: FileItem, targetCard: FolderCard) {
        let sourceDirectory = item.url.deletingLastPathComponent().standardizedFileURL
        if let sourceCard = workspace.cards.first(where: { $0.folderURL.standardizedFileURL == sourceDirectory }) {
            refresh(card: sourceCard)
        }
        if targetCard.folderURL.standardizedFileURL != sourceDirectory {
            refresh(card: targetCard)
        }
    }
}
