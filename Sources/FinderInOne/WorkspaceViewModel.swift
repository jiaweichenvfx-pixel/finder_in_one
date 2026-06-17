import FinderWorkbenchCore
import Foundation
import Observation

enum WorkspaceItemOpenResult: Equatable {
    case navigated
    case openedExternally
    case failed
}

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
    private let fileOpening: FileOpening
    private let allowedTransferRoot: URL?

    init(
        store: WorkspaceStore = WorkspaceStore(fileURL: AppSupport.workspaceStoreURL),
        listingService: DirectoryListingService = DirectoryListingService(),
        demoFolderProvider: DemoFolderProvider = DemoFolderProvider(),
        finderOpening: FinderOpening = FinderOpening(),
        fileOpening: FileOpening = FileOpening(),
        allowedTransferRoot: URL? = nil
    ) {
        self.store = store
        self.listingService = listingService
        self.demoFolderProvider = demoFolderProvider
        self.finderOpening = finderOpening
        self.fileOpening = fileOpening
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
            frame: frameForNewCard(),
            bookmarkData: demoFolder.bookmarkData
        )
        workspace.addCard(card)
        refresh(card: card)
        save()
    }

    @discardableResult
    func addFolder(url: URL) -> FolderCard? {
        let card = FolderCard(
            displayName: url.lastPathComponent,
            folderPath: url.path,
            frame: frameForNewCard(),
            bookmarkData: bookmarkData(for: url)
        )
        workspace.addCard(card)
        refresh(card: card)
        save()
        return card
    }

    func pickAndAddFolder() async {
        guard let url = await FolderPicking().pickFolder() else {
            return
        }
        addFolder(url: url)
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

    @discardableResult
    func moveCard(id: UUID, offset: Int) -> Bool {
        guard let currentIndex = workspace.cards.firstIndex(where: { $0.id == id }) else {
            return false
        }
        guard workspace.moveCard(id: id, toIndex: currentIndex + offset) else {
            return false
        }
        save()
        return true
    }

    @discardableResult
    func moveCard(id: UUID, x: Double, y: Double) -> Bool {
        guard var card = workspace.cards.first(where: { $0.id == id }) else {
            return false
        }
        guard card.move(toX: x, y: y) else {
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
    func open(item: FileItem, in card: FolderCard) -> WorkspaceItemOpenResult {
        guard item.isDirectory else {
            fileOpening.open(item.url)
            return .openedExternally
        }
        guard var currentCard = workspace.cards.first(where: { $0.id == card.id }) else {
            return .failed
        }
        currentCard.folderPath = item.url.path
        currentCard.displayName = item.name
        workspace.updateCard(currentCard)
        refresh(card: currentCard)
        save()
        return .navigated
    }

    @discardableResult
    func transfer(item: FileItem, to targetCard: FolderCard) -> Bool {
        let operation = currentTransferOperation
        defer {
            if transferMode == .moveOnce {
                transferMode = .copy
            }
        }

        let transferRoots = resolvedAllowedTransferRoots()
        guard !transferRoots.isEmpty else {
            errorsByCardID[targetCard.id] = "Transfer root unavailable"
            return false
        }

        do {
            _ = try ScopedFileTransferService(allowedRoots: transferRoots).transfer(
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

    private func bookmarkData(for url: URL) -> Data? {
        try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    private func frameForNewCard() -> CardFrame {
        let index = workspace.cards.count
        let column = index % 3
        let row = index / 3
        return CardFrame(
            x: Double(20 + column * 390),
            y: Double(20 + row * 280),
            width: 360,
            height: 240
        )
    }

    private var currentTransferOperation: FileTransferOperation {
        switch transferMode {
        case .copy:
            return .copy
        case .moveOnce:
            return .move
        }
    }

    private func resolvedAllowedTransferRoots() -> [URL] {
        if let allowedTransferRoot {
            return [allowedTransferRoot]
        }
        return workspace.cards.map(\.folderURL)
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
