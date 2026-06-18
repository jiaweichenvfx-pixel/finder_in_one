import FinderWorkbenchCore
import CoreGraphics
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
    var templateSlots: [WorkspaceTemplateSlot] = []
    var activeTemplateIndex: Int?
    var focusedCardID: UUID?

    private let store: WorkspaceStore
    private let templateStore: WorkspaceTemplateStore
    private let listingService: DirectoryListingService
    private let demoFolderProvider: DemoFolderProvider
    private let finderOpening: FinderOpening
    private let fileOpening: FileOpening
    private let filePreviewing: FilePreviewing
    private let allowedTransferRoot: URL?

    init(
        store: WorkspaceStore = WorkspaceStore(fileURL: AppSupport.workspaceStoreURL),
        templateStore: WorkspaceTemplateStore = WorkspaceTemplateStore(fileURL: AppSupport.templateStoreURL),
        listingService: DirectoryListingService = DirectoryListingService(),
        demoFolderProvider: DemoFolderProvider = DemoFolderProvider(),
        finderOpening: FinderOpening = FinderOpening(),
        fileOpening: FileOpening = FileOpening(),
        filePreviewing: FilePreviewing = FilePreviewing(),
        allowedTransferRoot: URL? = nil
    ) {
        self.store = store
        self.templateStore = templateStore
        self.listingService = listingService
        self.demoFolderProvider = demoFolderProvider
        self.finderOpening = finderOpening
        self.fileOpening = fileOpening
        self.filePreviewing = filePreviewing
        self.allowedTransferRoot = allowedTransferRoot
        self.workspace = (try? store.load()) ?? Workspace()
        self.templateSlots = ((try? templateStore.load()) ?? WorkspaceTemplateLibrary()).slots
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
    func addFolder(url: URL, frame: CardFrame? = nil) -> FolderCard? {
        if let existingCard = workspace.cards.first(where: { card in
            normalizedFolderPath(card.folderURL) == normalizedFolderPath(url)
        }) {
            focusedCardID = existingCard.id
            return existingCard
        }

        let card = FolderCard(
            displayName: url.lastPathComponent,
            folderPath: url.path,
            frame: frame ?? frameForNewCard(),
            bookmarkData: bookmarkData(for: url)
        )
        workspace.addCard(card)
        refresh(card: card)
        save()
        focusedCardID = card.id
        return card
    }

    @discardableResult
    func addDroppedFolderURLs(_ urls: [URL], at worldPoint: CGPoint? = nil) -> Bool {
        var didAddFolder = false
        var folderIndex = 0
        for url in urls where isDirectory(url) {
            let frame = worldPoint.map { point in
                CardFrame(
                    x: Double(point.x) + Double(folderIndex * 24),
                    y: Double(point.y) + Double(folderIndex * 24),
                    width: 360,
                    height: 240
                )
            }
            if addFolder(url: url, frame: frame) != nil {
                didAddFolder = true
            }
            folderIndex += 1
        }
        return didAddFolder
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

    @discardableResult
    func setCardColor(_ color: FolderCardColor, for id: UUID) -> Bool {
        guard var card = workspace.cards.first(where: { $0.id == id }) else {
            return false
        }
        card.color = color
        workspace.updateCard(card)
        save()
        return true
    }

    @discardableResult
    func toggleCollapse(for id: UUID) -> Bool {
        guard var card = workspace.cards.first(where: { $0.id == id }) else {
            return false
        }

        let changed = card.isCollapsed ? card.expand() : card.collapse()
        guard changed else {
            return false
        }
        workspace.updateCard(card)
        save()
        return true
    }

    @discardableResult
    func saveTemplate(at index: Int, name: String? = nil) -> Bool {
        var library = currentTemplateLibrary()
        let title = name ?? library.template(at: index)?.name ?? "T\(index + 1)"
        guard library.saveTemplate(normalizedTemplateWorkspace(from: workspace), at: index, name: title) else {
            return false
        }
        saveTemplateLibrary(library)
        activeTemplateIndex = index
        return true
    }

    @discardableResult
    func overwriteTemplate(at index: Int) -> Bool {
        var library = currentTemplateLibrary()
        let changed: Bool
        if library.template(at: index) == nil {
            changed = library.saveTemplate(normalizedTemplateWorkspace(from: workspace), at: index, name: "T\(index + 1)")
        } else {
            changed = library.overwriteTemplate(normalizedTemplateWorkspace(from: workspace), at: index)
        }
        guard changed else {
            return false
        }
        saveTemplateLibrary(library)
        activeTemplateIndex = index
        return true
    }

    @discardableResult
    func renameTemplate(at index: Int, name: String) -> Bool {
        var library = currentTemplateLibrary()
        guard library.renameTemplate(at: index, name: name) else {
            return false
        }
        saveTemplateLibrary(library)
        return true
    }

    @discardableResult
    func deleteTemplate(at index: Int) -> Bool {
        var library = currentTemplateLibrary()
        guard library.deleteTemplate(at: index) else {
            return false
        }
        saveTemplateLibrary(library)
        if activeTemplateIndex == index {
            activeTemplateIndex = nil
        }
        return true
    }

    @discardableResult
    func openTemplate(at index: Int) -> Bool {
        guard let template = currentTemplateLibrary().template(at: index) else {
            return false
        }

        workspace = normalizedTemplateWorkspace(from: template.workspace)
        activeTemplateIndex = index
        itemsByCardID = [:]
        errorsByCardID = [:]
        selectedItemURLsByCardID = [:]
        refreshAllCards()
        save()
        return true
    }

    func openInFinder(card: FolderCard) {
        let selectedURLs = orderedSelectedURLs(for: card)
        finderOpening.open(folderURL: card.folderURL, selectedURLs: selectedURLs)
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

    func preview(items: [FileItem], startingAt startingURL: URL? = nil) {
        let urls = items.map(\.url)
        guard !urls.isEmpty else {
            return
        }
        let selectedIndex = startingURL.flatMap { urls.firstIndex(of: $0) } ?? 0
        filePreviewing.preview(urls, selectedIndex)
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

        let transferRoots = resolvedAllowedTransferRoots(for: items)
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

    private func normalizedFolderPath(_ url: URL) -> String {
        URL(fileURLWithPath: url.path, isDirectory: true).standardizedFileURL.path
    }

    private func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    private func currentTemplateLibrary() -> WorkspaceTemplateLibrary {
        WorkspaceTemplateLibrary(slots: templateSlots)
    }

    private func saveTemplateLibrary(_ library: WorkspaceTemplateLibrary) {
        templateSlots = library.slots
        try? templateStore.save(library)
    }

    private func normalizedTemplateWorkspace(from workspace: Workspace) -> Workspace {
        guard !workspace.cards.isEmpty else {
            return workspace
        }

        let rects = workspace.cards.map { card in
            CGRect(
                x: card.frame.x,
                y: card.frame.y,
                width: max(1, card.frame.width),
                height: max(1, card.frame.height)
            )
        }
        let worldRect = rects.dropFirst().reduce(rects[0]) { $0.union($1) }
        let hasExtremeCoordinates = rects.contains { rect in
            abs(rect.minX) > 20_000 || abs(rect.minY) > 20_000
        }
        let hasExtremeSpread = worldRect.width > 8_000 || worldRect.height > 8_000

        if hasExtremeCoordinates || hasExtremeSpread {
            return Workspace(cards: reflowedCards(workspace.cards))
        }

        let dx = worldRect.minX < 0 ? 20 - worldRect.minX : 0
        let dy = worldRect.minY < 0 ? 20 - worldRect.minY : 0
        guard dx != 0 || dy != 0 else {
            return workspace
        }

        return Workspace(cards: workspace.cards.map { card in
            movedCard(card, dx: dx, dy: dy)
        })
    }

    private func reflowedCards(_ cards: [FolderCard]) -> [FolderCard] {
        cards.enumerated().map { index, card in
            let column = index % 3
            let row = index / 3
            var updated = card
            let width = min(max(card.frame.width, 280), 520)
            let height = card.isCollapsed
                ? FolderCard.collapsedHeight
                : min(max(card.expandedFrame?.height ?? card.frame.height, 180), 340)
            let x = Double(20 + column * 560)
            let y = Double(20 + row * 380)
            updated.frame = CardFrame(x: x, y: y, width: width, height: height)
            if card.isCollapsed, let expandedFrame = card.expandedFrame {
                updated.expandedFrame = CardFrame(
                    x: x,
                    y: y,
                    width: min(max(expandedFrame.width, 280), 520),
                    height: min(max(expandedFrame.height, 180), 340)
                )
            }
            return updated
        }
    }

    private func movedCard(_ card: FolderCard, dx: Double, dy: Double) -> FolderCard {
        var updated = card
        updated.frame.x += dx
        updated.frame.y += dy
        if var expandedFrame = updated.expandedFrame {
            expandedFrame.x += dx
            expandedFrame.y += dy
            updated.expandedFrame = expandedFrame
        }
        return updated
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

    private func orderedSelectedURLs(for card: FolderCard) -> [URL] {
        guard let selectedURLs = selectedItemURLsByCardID[card.id],
              !selectedURLs.isEmpty else {
            return []
        }

        let items = itemsByCardID[card.id] ?? []
        let validSelectedURLs = selectedURLs.filter { url in
            url.deletingLastPathComponent().standardizedFileURL == card.folderURL.standardizedFileURL
        }
        let orderedURLs = items.map(\.url).filter { validSelectedURLs.contains($0) }
        let missingURLs = validSelectedURLs.filter { !orderedURLs.contains($0) }
        return orderedURLs + missingURLs.sorted { lhs, rhs in
            lhs.path.localizedStandardCompare(rhs.path) == .orderedAscending
        }
    }

    private func resolvedAllowedTransferRoots(for items: [FileItem]) -> [URL] {
        if let allowedTransferRoot {
            return [allowedTransferRoot]
        }
        let workspaceRoots = workspace.cards.map(\.folderURL)
        let sourceRoots = items.map { item in
            item.url.deletingLastPathComponent()
        }
        return uniqueStandardizedURLs(workspaceRoots + sourceRoots)
    }

    private func uniqueStandardizedURLs(_ urls: [URL]) -> [URL] {
        var seenPaths = Set<String>()
        return urls.compactMap { url in
            let standardizedURL = url.standardizedFileURL
            guard seenPaths.insert(standardizedURL.path).inserted else {
                return nil
            }
            return standardizedURL
        }
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
