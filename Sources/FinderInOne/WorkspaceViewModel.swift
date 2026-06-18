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
    var selectedItemURLsByCardID: [UUID: Set<URL>] = [:]

    private let store: WorkspaceStore
    private let listingService: DirectoryListingService
    private let demoFolderProvider: DemoFolderProvider
    private let finderOpening: FinderOpening
    private let fileOpening: FileOpening
    private let filePreviewing: FilePreviewing
    private let allowedTransferRoot: URL?

    init(
        store: WorkspaceStore = WorkspaceStore(fileURL: AppSupport.workspaceStoreURL),
        listingService: DirectoryListingService = DirectoryListingService(),
        demoFolderProvider: DemoFolderProvider = DemoFolderProvider(),
        finderOpening: FinderOpening = FinderOpening(),
        fileOpening: FileOpening = FileOpening(),
        filePreviewing: FilePreviewing = FilePreviewing(),
        allowedTransferRoot: URL? = nil
    ) {
        self.store = store
        self.listingService = listingService
        self.demoFolderProvider = demoFolderProvider
        self.finderOpening = finderOpening
        self.fileOpening = fileOpening
        self.filePreviewing = filePreviewing
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
        selectedItemURLsByCardID[id] = nil
        save()
    }

    @discardableResult
    func resizeCard(id: UUID, width: Double, height: Double, persist: Bool = true) -> Bool {
        guard var card = workspace.cards.first(where: { $0.id == id }) else {
            return false
        }
        guard card.resize(width: width, height: height) else {
            return false
        }
        workspace.updateCard(card)
        if persist {
            save()
        }
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
    func moveCard(id: UUID, x: Double, y: Double, persist: Bool = true) -> Bool {
        guard var card = workspace.cards.first(where: { $0.id == id }) else {
            return false
        }
        guard card.move(toX: x, y: y) else {
            return false
        }
        workspace.updateCard(card)
        if persist {
            save()
        }
        return true
    }

    func setSelectedItemURLs(_ urls: Set<URL>, for cardID: UUID) {
        selectedItemURLsByCardID[cardID] = urls
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
        navigate(card: &currentCard, to: item.url)
        return .navigated
    }

    @discardableResult
    func navigateToParent(of card: FolderCard) -> Bool {
        guard var currentCard = workspace.cards.first(where: { $0.id == card.id }) else {
            return false
        }

        let currentURL = currentCard.folderURL.standardizedFileURL
        let parentURL = currentURL.deletingLastPathComponent()
        guard parentURL.path != currentURL.path else {
            return false
        }

        navigate(card: &currentCard, to: parentURL)
        return true
    }

    func preview(items: [FileItem]) {
        let urls = items.map(\.url)
        guard !urls.isEmpty else {
            return
        }
        filePreviewing.preview(urls)
    }

    @discardableResult
    func transfer(item: FileItem, to targetCard: FolderCard) -> Bool {
        transfer(items: [item], to: targetCard)
    }

    @discardableResult
    func transfer(items: [FileItem], to targetCard: FolderCard) -> Bool {
        guard !items.isEmpty else {
            return false
        }

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

        let transferService = ScopedFileTransferService(allowedRoots: transferRoots)
        var didTransferAllItems = true
        for item in items {
            do {
                _ = try transferService.transfer(
                    sourceURL: item.url,
                    targetDirectory: targetCard.folderURL,
                    operation: operation,
                    conflictPolicy: .keepBoth
                )
                refreshImpactedCards(for: item, targetCard: targetCard)
            } catch {
                didTransferAllItems = false
            }
        }

        if didTransferAllItems {
            errorsByCardID[targetCard.id] = nil
        } else {
            errorsByCardID[targetCard.id] = "Transfer failed"
        }
        return didTransferAllItems
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

    private func navigate(card: inout FolderCard, to url: URL) {
        card.folderPath = url.path
        card.displayName = url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
        workspace.updateCard(card)
        selectedItemURLsByCardID[card.id] = []
        refresh(card: card)
        save()
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
