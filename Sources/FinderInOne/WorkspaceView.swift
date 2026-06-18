import FinderWorkbenchCore
import SwiftUI
import UniformTypeIdentifiers

struct WorkspaceView: View {
    @State private var viewModel = WorkspaceViewModel()
    @State private var viewport = CanvasViewport()
    @State private var viewportSize: CGSize = .zero
    @State private var renamingTemplateIndex: Int?
    @State private var templateNameDraft = ""

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    Color(nsColor: .windowBackgroundColor)
                    CanvasInputView(
                        onZoom: { factor, point in
                            viewport.zoom(by: factor, around: point)
                        },
                        onPan: { delta in
                            viewport.pan(by: delta)
                        }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    ForEach(viewModel.workspace.cards) { card in
                        cardView(for: card)
                    }
                }
                .clipped()
                .onDrop(
                    of: [.fileURL, .url],
                    delegate: CanvasFolderDropDelegate(
                        viewport: viewport,
                        operation: viewModel.transferMode.dropProposalOperation,
                        onDropFolderURLs: { urls, worldPoint in
                            viewModel.addDroppedFolderURLs(urls, at: worldPoint)
                        }
                    )
                )
                .onAppear {
                    viewportSize = geometry.size
                }
                .onChange(of: geometry.size) { _, newSize in
                    viewportSize = newSize
                }
                .onChange(of: viewModel.focusedCardID) { _, focusedCardID in
                    guard let focusedCardID,
                          let card = viewModel.workspace.cards.first(where: { $0.id == focusedCardID }) else {
                        return
                    }
                    viewport.reset(
                        toWorldRect: CGRect(
                            x: card.frame.x,
                            y: card.frame.y,
                            width: card.frame.width,
                            height: card.frame.height
                        ),
                        viewportSize: viewportSize
                    )
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .alert("Rename Template", isPresented: renameTemplateBinding) {
            TextField("Name", text: $templateNameDraft)
            Button("Cancel", role: .cancel) {
                renamingTemplateIndex = nil
            }
            Button("Rename") {
                if let index = renamingTemplateIndex {
                    viewModel.renameTemplate(at: index, name: templateNameDraft)
                }
                renamingTemplateIndex = nil
            }
        }
    }

    private func cardView(for card: FolderCard) -> some View {
        FolderCardView(
            card: card,
            items: viewModel.itemsByCardID[card.id] ?? [],
            errorMessage: viewModel.errorsByCardID[card.id],
            onToggleLock: { viewModel.toggleLock(for: card.id) },
            onToggleCollapse: { viewModel.toggleCollapse(for: card.id) },
            onNavigateUp: { viewModel.navigateToParent(of: card) },
            onOpenInFinder: { viewModel.openInFinder(card: card) },
            onClose: { viewModel.closeCard(id: card.id) },
            onSetColor: { color in viewModel.setCardColor(color, for: card.id) },
            selectedItemURLs: viewModel.selectedItemURLsByCardID[card.id] ?? [],
            transferMode: viewModel.transferMode,
            onSelectionChange: { urls in
                viewModel.setSelectedItemURLs(urls, for: card.id)
            },
            onDropFiles: { urls in
                viewModel.transfer(items: urls.map(fileItem(for:)), to: card)
            },
            onOpenItem: { item in
                viewModel.open(item: item, in: card)
            },
            onPreviewItems: { items, startingItem in
                viewModel.preview(items: items, startingAt: startingItem?.url)
            },
            onMoveTo: { x, y, persist in
                viewModel.moveCard(id: card.id, x: x, y: y, persist: persist)
            },
            onResize: { width, height, persist in
                viewModel.resizeCard(id: card.id, width: width, height: height, persist: persist)
            },
            viewportScale: viewport.scale
        )
        .frame(width: card.frame.width, height: card.frame.height)
        .scaleEffect(viewport.scale, anchor: .topLeading)
        .frame(
            width: card.frame.width * viewport.scale,
            height: card.frame.height * viewport.scale,
            alignment: .topLeading
        )
        .position(
            x: viewport.offset.width + (card.frame.x + card.frame.width / 2) * viewport.scale,
            y: viewport.offset.height + (card.frame.y + card.frame.height / 2) * viewport.scale
        )
    }

    private func fileItem(for url: URL) -> FileItem {
        FileItem(
            url: url,
            name: url.lastPathComponent,
            modifiedAt: nil,
            byteSize: nil,
            isDirectory: false
        )
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Text("\(viewModel.workspace.cards.count) folders")
                .foregroundStyle(.secondary)
            Text("\(Int(viewport.scale * 100))%")
                .foregroundStyle(.secondary)
            templateMenus
            Spacer()
            Button {
                viewport.zoom(by: 0.9, around: viewportCenter)
            } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .help("Zoom out")
            Button {
                viewport.zoom(by: 1.1, around: viewportCenter)
            } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .help("Zoom in")
            Button {
                viewport.reset(toWorldRect: cardsWorldRect, viewportSize: viewportSize)
            } label: {
                Image(systemName: "scope")
            }
            .help("Fit folders")
            modeButton("Copy", isSelected: viewModel.transferMode == .copy) {
                viewModel.transferMode = .copy
            }
            modeButton("Move once", isSelected: viewModel.transferMode == .moveOnce) {
                viewModel.transferMode = .moveOnce
            }
            Button {
                viewModel.refreshAllCards()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Refresh folders")
            Button {
                Task {
                    await viewModel.pickAndAddFolder()
                }
            } label: {
                Image(systemName: "plus")
            }
            .help("Add folder")
        }
        .font(.system(size: 12))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private var templateMenus: some View {
        HStack(spacing: 4) {
            ForEach(viewModel.templateSlots) { slot in
                Menu {
                    if slot.template != nil {
                        Button("Open") {
                            viewModel.openTemplate(at: slot.index)
                            viewport.reset(toWorldRect: cardsWorldRect, viewportSize: viewportSize)
                        }
                        Button("Overwrite") {
                            viewModel.overwriteTemplate(at: slot.index)
                        }
                        Button("Rename Template...") {
                            renamingTemplateIndex = slot.index
                            templateNameDraft = slot.template?.name ?? slot.displayName
                        }
                        Button("Delete", role: .destructive) {
                            viewModel.deleteTemplate(at: slot.index)
                        }
                    } else {
                        Button("Save Current") {
                            viewModel.saveTemplate(at: slot.index, name: slot.displayName)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(templateMarkerColor(for: slot))
                            .frame(width: 6, height: 6)
                        Text(templateLabel(for: slot))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .frame(minWidth: 54, maxWidth: 96)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .foregroundStyle(templateForeground(for: slot))
                    .background(templateBackground(for: slot))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(templateBorder(for: slot), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .menuStyle(.borderlessButton)
                .help(templateHelp(for: slot))
            }
        }
    }

    private var renameTemplateBinding: Binding<Bool> {
        Binding(
            get: { renamingTemplateIndex != nil },
            set: { isPresented in
                if !isPresented {
                    renamingTemplateIndex = nil
                }
            }
        )
    }

    private func templateLabel(for slot: WorkspaceTemplateSlot) -> String {
        guard let template = slot.template else {
            return "T\(slot.index + 1) empty"
        }
        return "T\(slot.index + 1) \(template.name)"
    }

    private func templateForeground(for slot: WorkspaceTemplateSlot) -> Color {
        if viewModel.activeTemplateIndex == slot.index {
            return .white
        }
        return slot.template == nil ? .white.opacity(0.55) : .white.opacity(0.94)
    }

    private func templateBackground(for slot: WorkspaceTemplateSlot) -> Color {
        if viewModel.activeTemplateIndex == slot.index {
            return Color.accentColor.opacity(0.82)
        }
        if slot.template == nil {
            return Color.white.opacity(0.04)
        }
        return templateMarkerColor(for: slot).opacity(0.24)
    }

    private func templateBorder(for slot: WorkspaceTemplateSlot) -> Color {
        if viewModel.activeTemplateIndex == slot.index {
            return Color.white.opacity(0.42)
        }
        return slot.template == nil ? Color.white.opacity(0.12) : templateMarkerColor(for: slot).opacity(0.58)
    }

    private func templateMarkerColor(for slot: WorkspaceTemplateSlot) -> Color {
        guard slot.template != nil else {
            return Color.white.opacity(0.22)
        }
        let colors: [Color] = [
            Color(red: 0.28, green: 0.62, blue: 1.00),
            Color(red: 0.25, green: 0.78, blue: 0.55),
            Color(red: 0.96, green: 0.62, blue: 0.24),
            Color(red: 0.87, green: 0.42, blue: 0.62),
            Color(red: 0.63, green: 0.55, blue: 0.98)
        ]
        return colors[slot.index % colors.count]
    }

    private func templateHelp(for slot: WorkspaceTemplateSlot) -> String {
        guard let template = slot.template else {
            return "T\(slot.index + 1): empty - save current layout"
        }
        let names = template.workspace.cards.map(\.displayName)
        let preview = names.prefix(6).joined(separator: ", ")
        let more = names.count > 6 ? " +" + String(names.count - 6) : ""
        return "T\(slot.index + 1): \(template.name)\n\(names.count) folders: \(preview)\(more)"
    }

    private var viewportCenter: CGPoint {
        CGPoint(x: viewportSize.width / 2, y: viewportSize.height / 2)
    }

    private var cardsWorldRect: CGRect? {
        let rects = viewModel.workspace.cards.map { card in
            CGRect(
                x: card.frame.x,
                y: card.frame.y,
                width: card.frame.width,
                height: card.frame.height
            )
        }
        guard var union = rects.first else {
            return nil
        }
        for rect in rects.dropFirst() {
            union = union.union(rect)
        }
        return union
    }

    @ViewBuilder
    private func modeButton(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        if isSelected {
            Button(title, action: action)
                .buttonStyle(.borderedProminent)
        } else {
            Button(title, action: action)
                .buttonStyle(.bordered)
        }
    }

}

private struct CanvasFolderDropDelegate: DropDelegate {
    let viewport: CanvasViewport
    let operation: DropOperation
    let onDropFolderURLs: ([URL], CGPoint) -> Bool

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: DropURLParsing.acceptedFileURLTypeIdentifiers)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: operation)
    }

    func performDrop(info: DropInfo) -> Bool {
        let providers = info.itemProviders(for: DropURLParsing.acceptedFileURLTypeIdentifiers)
        guard !providers.isEmpty else {
            return false
        }

        let worldPoint = CGPoint(
            x: (info.location.x - viewport.offset.width) / viewport.scale,
            y: (info.location.y - viewport.offset.height) / viewport.scale
        )
        loadFileURLs(from: providers) { urls in
            guard !urls.isEmpty else {
                return
            }
            _ = onDropFolderURLs(urls, worldPoint)
        }
        return true
    }

    private func loadFileURLs(from providers: [NSItemProvider], completion: @escaping ([URL]) -> Void) {
        let group = DispatchGroup()
        let collector = CanvasDropURLCollector()

        for provider in providers {
            group.enter()
            DropURLParsing.loadFileURL(from: provider) { url in
                if let url {
                    collector.append(url)
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            completion(collector.urls)
        }
    }
}

private final class CanvasDropURLCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var storedURLs: [URL] = []

    var urls: [URL] {
        lock.lock()
        defer { lock.unlock() }
        return storedURLs
    }

    func append(_ url: URL) {
        lock.lock()
        storedURLs.append(url)
        lock.unlock()
    }
}
