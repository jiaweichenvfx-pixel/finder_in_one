import FinderWorkbenchCore
import CoreGraphics
import Foundation
import Observation

enum WorkspaceItemOpenResult: Equatable {
    case navigated
    case openedExternally
    case failed
}

struct BreadcrumbSegment: Equatable, Identifiable {
    let id: String
    let label: String
    let url: URL
    let isCurrent: Bool

    init(label: String, url: URL, isCurrent: Bool) {
        self.id = url.standardizedFileURL.path
        self.label = label
        self.url = url
        self.isCurrent = isCurrent
    }
}

@MainActor
@Observable
final class WorkspaceViewModel {
    var workspace: Workspace
    var transferMode: TransferMode = .copy
    var itemsByCardID: [UUID: [FileItem]] = [:]
    var errorsByCardID: [UUID: String] = [:]
    var selectedItemURLsByCardID: [UUID: Set<URL>] = [:]
    var suffixFilterTextByCardID: [UUID: String] = [:]
    var sortOrderByCardID: [UUID: FileItemSortOrder] = [:]
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
        restoreCardViewState()
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

    func pickAndAddFolder() {
        guard let url = FolderPicking().pickFolder() else {
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
        suffixFilterTextByCardID[id] = nil
        sortOrderByCardID[id] = nil
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
        updateCard(cardID) { card in
            card.selectedItemPaths = urls
                .map(\.path)
                .sorted { lhs, rhs in lhs.localizedStandardCompare(rhs) == .orderedAscending }
        }
        save()
    }

    func setSuffixFilter(_ text: String, for cardID: UUID) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedText.isEmpty {
            suffixFilterTextByCardID[cardID] = nil
        } else {
            suffixFilterTextByCardID[cardID] = text
        }
        updateCard(cardID) { card in
            card.suffixFilterText = trimmedText.isEmpty ? nil : text
        }
        save()
    }

    func setSortOrder(_ sortOrder: FileItemSortOrder, for cardID: UUID) {
        sortOrderByCardID[cardID] = sortOrder
        updateCard(cardID) { card in
            card.sortOrder = sortOrder
        }
        save()
    }

    func displayedItems(for card: FolderCard) -> [FileItem] {
        let items = itemsByCardID[card.id] ?? []
        let suffixes = parsedSuffixes(for: card.id)
        guard !suffixes.isEmpty else {
            return items
        }

        return items.filter { item in
            item.isDirectory || suffixes.contains(item.url.pathExtension.lowercased())
        }
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
        restoreCardViewState()
        refreshAllCards()
        save()
        return true
    }

    func openInFinder(card: FolderCard) {
        let selectedURLs = orderedSelectedURLs(for: card)
        finderOpening.open(folderURL: card.folderURL, selectedURLs: selectedURLs)
    }

    @discardableResult
    func createFolder(in card: FolderCard, named name: String) -> Bool {
        guard let currentCard = workspace.cards.first(where: { $0.id == card.id }) else {
            return false
        }
        guard let safeName = validatedFileName(name, cardID: card.id) else {
            return false
        }

        let newFolderURL = currentCard.folderURL.appendingPathComponent(safeName, isDirectory: true)
        guard !FileManager.default.fileExists(atPath: newFolderURL.path) else {
            errorsByCardID[card.id] = "Name already exists"
            return false
        }

        do {
            try FileManager.default.createDirectory(at: newFolderURL, withIntermediateDirectories: false)
            refresh(card: currentCard)
            setSelectedItemURLs([newFolderURL], for: card.id)
            errorsByCardID[card.id] = nil
            return true
        } catch {
            errorsByCardID[card.id] = "Create folder failed"
            return false
        }
    }

    @discardableResult
    func renameSelectedItem(in card: FolderCard, to name: String) -> Bool {
        guard let currentCard = workspace.cards.first(where: { $0.id == card.id }) else {
            return false
        }
        guard let selectedURLs = selectedItemURLsByCardID[card.id],
              selectedURLs.count == 1,
              let sourceURL = selectedURLs.first else {
            errorsByCardID[card.id] = "Select one item to rename"
            return false
        }
        guard sourceURL.deletingLastPathComponent().standardizedFileURL == currentCard.folderURL.standardizedFileURL else {
            errorsByCardID[card.id] = "Selection is outside this folder"
            return false
        }
        guard let safeName = validatedFileName(name, cardID: card.id) else {
            return false
        }

        let destinationURL = currentCard.folderURL.appendingPathComponent(safeName)
        guard destinationURL.standardizedFileURL != sourceURL.standardizedFileURL else {
            errorsByCardID[card.id] = nil
            return true
        }
        guard !FileManager.default.fileExists(atPath: destinationURL.path) else {
            errorsByCardID[card.id] = "Name already exists"
            return false
        }

        do {
            try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
            refresh(card: currentCard)
            setSelectedItemURLs([destinationURL], for: card.id)
            errorsByCardID[card.id] = nil
            return true
        } catch {
            errorsByCardID[card.id] = "Rename failed"
            return false
        }
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

    func breadcrumbSegments(for card: FolderCard) -> [BreadcrumbSegment] {
        let currentURL = card.folderURL.standardizedFileURL
        let currentPath = currentURL.path
        var segments: [BreadcrumbSegment] = []
        var url = URL(fileURLWithPath: "/", isDirectory: true)

        segments.append(BreadcrumbSegment(label: "/", url: url, isCurrent: currentPath == "/"))

        for component in currentURL.pathComponents.dropFirst() {
            url.appendPathComponent(component, isDirectory: true)
            segments.append(
                BreadcrumbSegment(
                    label: component,
                    url: url,
                    isCurrent: url.standardizedFileURL.path == currentPath
                )
            )
        }

        return segments
    }

    @discardableResult
    func navigate(cardID: UUID, toFolder url: URL) -> Bool {
        guard var currentCard = workspace.cards.first(where: { $0.id == cardID }),
              isDirectory(url) else {
            return false
        }

        let targetURL = url.standardizedFileURL
        guard targetURL.path != currentCard.folderURL.standardizedFileURL.path else {
            return true
        }

        navigate(card: &currentCard, to: targetURL)
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
        guard transferMode != .delete else {
            errorsByCardID[targetCard.id] = "Drop on blank canvas to delete"
            return false
        }
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

    @discardableResult
    func trashDroppedItems(at urls: [URL]) -> Bool {
        guard transferMode == .delete else {
            return false
        }
        defer {
            transferMode = .copy
        }

        let standardizedURLs = uniqueStandardizedURLs(urls)
        guard !standardizedURLs.isEmpty else {
            return false
        }

        var impactedCardIDs = Set<UUID>()
        var didTrashAllItems = true
        for url in standardizedURLs {
            do {
                _ = try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                impactedCardIDs.formUnion(cardIDsImpactedByDeleting(url))
            } catch {
                didTrashAllItems = false
            }
        }

        for cardID in impactedCardIDs {
            guard let card = workspace.cards.first(where: { $0.id == cardID }) else {
                continue
            }
            refresh(card: card)
            selectedItemURLsByCardID[cardID]?.subtract(standardizedURLs)
        }

        if didTrashAllItems {
            for cardID in impactedCardIDs {
                errorsByCardID[cardID] = nil
            }
        } else {
            for cardID in impactedCardIDs {
                errorsByCardID[cardID] = "Delete failed"
            }
        }
        return didTrashAllItems
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

    private func restoreCardViewState() {
        selectedItemURLsByCardID = [:]
        suffixFilterTextByCardID = [:]
        sortOrderByCardID = [:]

        for card in workspace.cards {
            if let suffixFilterText = card.suffixFilterText,
               !suffixFilterText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                suffixFilterTextByCardID[card.id] = suffixFilterText
            }
            if let sortOrder = card.sortOrder {
                sortOrderByCardID[card.id] = sortOrder
            }
            let selectedURLs = Set(card.selectedItemPaths.map { URL(fileURLWithPath: $0) })
            if !selectedURLs.isEmpty {
                selectedItemURLsByCardID[card.id] = selectedURLs
            }
        }
    }

    private func updateCard(_ cardID: UUID, mutate: (inout FolderCard) -> Void) {
        guard var card = workspace.cards.first(where: { $0.id == cardID }) else {
            return
        }
        mutate(&card)
        workspace.updateCard(card)
    }

    private func validatedFileName(_ name: String, cardID: UUID) -> String? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorsByCardID[cardID] = "Name is empty"
            return nil
        }
        guard trimmedName != "." && trimmedName != ".." && !trimmedName.contains("/") else {
            errorsByCardID[cardID] = "Name is invalid"
            return nil
        }
        return trimmedName
    }

    private func normalizedFolderPath(_ url: URL) -> String {
        URL(fileURLWithPath: url.path, isDirectory: true).standardizedFileURL.path
    }

    private func parsedSuffixes(for cardID: UUID) -> Set<String> {
        guard let filterText = suffixFilterTextByCardID[cardID] else {
            return []
        }

        let suffixes = filterText
            .split { character in
                character == "," || character == " " || character == "\n" || character == "\t"
            }
            .map { suffix in
                suffix.trimmingCharacters(in: CharacterSet(charactersIn: ".").union(.whitespacesAndNewlines)).lowercased()
            }
            .filter { !$0.isEmpty }

        return Set(suffixes)
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
        card.selectedItemPaths = []
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
        case .delete:
            return .copy
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

    private func cardIDsImpactedByDeleting(_ url: URL) -> Set<UUID> {
        let standardizedURL = url.standardizedFileURL
        let parentURL = standardizedURL.deletingLastPathComponent().standardizedFileURL
        return Set(workspace.cards.compactMap { card in
            let cardURL = card.folderURL.standardizedFileURL
            if cardURL == parentURL || cardURL == standardizedURL || cardURL.path.hasPrefix(standardizedURL.path + "/") {
                return card.id
            }
            return nil
        })
    }
}
