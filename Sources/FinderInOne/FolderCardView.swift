import FinderWorkbenchCore
import SwiftUI
import UniformTypeIdentifiers

struct FolderCardView: View {
    let card: FolderCard
    let items: [FileItem]
    let errorMessage: String?
    let onToggleLock: () -> Void
    let onToggleCollapse: () -> Void
    let onNavigateUp: () -> Void
    let onOpenInFinder: () -> Void
    let onClose: () -> Void
    let onSetColor: (FolderCardColor) -> Void
    let onRequestCreateFolder: () -> Void
    let onRequestRenameSelectedItem: () -> Void
    let breadcrumbSegments: [BreadcrumbSegment]
    let selectedItemURLs: Set<URL>
    let suffixFilterText: String
    let sortOrder: FileItemSortOrder
    let transferMode: TransferMode
    let onSelectionChange: (Set<URL>) -> Void
    let onSuffixFilterChange: (String) -> Void
    let onSortOrderChange: (FileItemSortOrder) -> Void
    let onNavigateToBreadcrumb: (URL) -> Void
    let onDropFiles: ([URL]) -> Bool
    let onOpenItem: (FileItem) -> Void
    let onPreviewItems: ([FileItem], FileItem?) -> Void
    let onMoveTo: (Double, Double, Bool) -> Void
    let onResize: (Double, Double, Bool) -> Void
    let viewportScale: CGFloat

    @State private var isDropTargeted = false
    @State private var isMoving = false
    @State private var moveStartFrame: CardFrame?
    @State private var moveTranslation: CGSize = .zero
    @State private var resizeStartFrame: CardFrame?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if !card.isCollapsed {
                Divider()
                    .overlay(Color.white.opacity(0.18))
                if dragPresentation.showsFileContent {
                    suffixFilterField
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.68))
                        Spacer(minLength: 0)
                    } else if items.isEmpty {
                        Text("No visible items")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.68))
                        Spacer(minLength: 0)
                    } else {
                        fileRows
                    }
                    if card.canResize {
                        resizeHandle
                    }
                }
            }
        }
        .padding(card.isCollapsed ? 8 : 10)
        .foregroundStyle(.white.opacity(0.9))
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor, lineWidth: isDropTargeted ? 2 : 1)
        )
        .onDrop(of: [.fileURL, .url], isTargeted: $isDropTargeted, perform: handleDrop(providers:))
        .offset(moveTranslation)
        .animation(nil, value: moveTranslation)
    }

    private var dragPresentation: FolderCardDragPresentation {
        FolderCardDragPresentation(isMoving: isMoving)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 8) {
            titleArea
            headerControls
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    private var headerControls: some View {
        HStack(spacing: 6) {
            HStack(spacing: 4) {
                Button(action: onNavigateUp) {
                    Image(systemName: "arrow.up")
                }
                .help("Parent folder")
                Button(action: onToggleCollapse) {
                    Image(systemName: card.isCollapsed ? "chevron.down" : "chevron.up")
                }
                .help(card.isCollapsed ? "Restore card" : "Collapse card")
                Menu {
                    ForEach(FolderCardColor.allCases, id: \.self) { color in
                        Button {
                            onSetColor(color)
                        } label: {
                            Label(color.label, systemImage: color == card.color ? "checkmark.circle.fill" : "circle")
                        }
                    }
                } label: {
                    Text("Color")
                }
                .menuStyle(.button)
                .help("Card color")
                Button(action: onRequestCreateFolder) {
                    Image(systemName: "folder.badge.plus")
                }
                .help("New folder")
                Button(action: onRequestRenameSelectedItem) {
                    Image(systemName: "pencil")
                }
                .disabled(selectedItemURLs.count != 1)
                .help("Rename selected item")
                Button(card.isLocked ? "Unlock" : "Lock", action: onToggleLock)
                Button("Finder", action: onOpenInFinder)
                if card.canClose {
                    Button("Close", action: onClose)
                }
            }
        }
        .font(.system(size: 11))
    }

    @ViewBuilder
    private var titleArea: some View {
        let content = VStack(alignment: .leading, spacing: 2) {
            Text(card.displayName)
                .font(card.isCollapsed ? .subheadline : .headline)
                .lineLimit(1)
            if !card.isCollapsed {
                breadcrumbRow
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .layoutPriority(1)

        if card.canMove {
            content
                .contentShape(Rectangle())
                .gesture(moveGesture)
                .help("Drag card")
        } else {
            content
        }
    }

    private var breadcrumbRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 3) {
                ForEach(breadcrumbSegments) { segment in
                    if segment.id != breadcrumbSegments.first?.id {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.34))
                    }
                    Button {
                        onNavigateToBreadcrumb(segment.url)
                    } label: {
                        Text(segment.label)
                            .font(.system(size: 10, weight: segment.isCurrent ? .semibold : .regular))
                            .lineLimit(1)
                            .foregroundStyle(segment.isCurrent ? .white.opacity(0.82) : .white.opacity(0.58))
                    }
                    .buttonStyle(.plain)
                    .disabled(segment.isCurrent)
                    .help(segment.url.path)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 14)
    }

    private var fileRows: some View {
        FolderItemsTableView(
            items: items,
            selectedItemURLs: selectedItemURLs,
            sortOrder: sortOrder,
            transferMode: transferMode,
            onSelectionChange: onSelectionChange,
            onSortOrderChange: onSortOrderChange,
            onOpenItem: onOpenItem,
            onPreviewItems: onPreviewItems,
            onDropURLs: onDropFiles
        )
        .allowsHitTesting(dragPresentation.allowsFileInteraction)
    }

    private var suffixFilterField: some View {
        HStack(spacing: 5) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.52))
            TextField("suffix: mov, jpg", text: Binding(
                get: { suffixFilterText },
                set: { newValue in
                    onSuffixFilterChange(newValue)
                }
            ))
            .textFieldStyle(.plain)
            .font(.system(size: 11))
            .foregroundStyle(.white.opacity(0.88))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.black.opacity(0.18))
            .clipShape(RoundedRectangle(cornerRadius: 5))
            if !suffixFilterText.isEmpty {
                Button {
                    onSuffixFilterChange("")
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.58))
                .help("Clear suffix filter")
            }
        }
        .help("Filter files by suffix. Folders stay visible.")
    }

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                moveStartFrame = moveStartFrame ?? card.frame
                isMoving = true
                moveTranslation = value.translation
            }
            .onEnded { value in
                let startFrame = moveStartFrame ?? card.frame
                onMoveTo(
                    startFrame.x + value.translation.width,
                    startFrame.y + value.translation.height,
                    true
                )
                moveTranslation = .zero
                moveStartFrame = nil
                isMoving = false
            }
    }

    private var resizeHandle: some View {
        HStack {
            Spacer()
            Image(systemName: "arrow.down.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.58))
                .frame(width: 18, height: 18)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 2)
                        .onChanged { value in
                            let startFrame = resizeStartFrame ?? card.frame
                            resizeStartFrame = startFrame
                            onResize(
                                startFrame.width + value.translation.width,
                                startFrame.height + value.translation.height,
                                false
                            )
                        }
                        .onEnded { value in
                            let startFrame = resizeStartFrame ?? card.frame
                            onResize(
                                startFrame.width + value.translation.width,
                                startFrame.height + value.translation.height,
                                true
                            )
                            resizeStartFrame = nil
                        }
                )
        }
    }

    private var cardBackground: Color {
        card.isLocked ? card.color.lockedBackgroundColor : card.color.backgroundColor
    }

    private var borderColor: Color {
        if isDropTargeted {
            return .accentColor
        }
        if card.isLocked {
            return card.color.accentColor.opacity(0.58)
        }
        return card.color.accentColor.opacity(card.color == .graphite ? 0.20 : 0.44)
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        let fileProviders = providers.filter { provider in
            provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
                || provider.hasItemConformingToTypeIdentifier(UTType.url.identifier)
        }
        guard !fileProviders.isEmpty else {
            return false
        }

        let group = DispatchGroup()
        let collector = DropURLCollector()

        for provider in fileProviders {
            group.enter()
            DropURLParsing.loadFileURL(from: provider) { url in
                if let url {
                    collector.append(url)
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            let urls = collector.urls
            guard !urls.isEmpty else {
                return
            }
            _ = onDropFiles(urls)
        }
        return true
    }
}

struct FolderCardDragPresentation {
    let isMoving: Bool

    var showsFileContent: Bool {
        true
    }

    var allowsFileInteraction: Bool {
        !isMoving
    }

}

private final class DropURLCollector: @unchecked Sendable {
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

private extension FolderCardColor {
    var label: String {
        switch self {
        case .graphite:
            return "Graphite"
        case .blue:
            return "Blue"
        case .green:
            return "Green"
        case .amber:
            return "Amber"
        case .rose:
            return "Rose"
        case .violet:
            return "Violet"
        }
    }

    var accentColor: Color {
        switch self {
        case .graphite:
            return Color.white.opacity(0.34)
        case .blue:
            return Color(red: 0.30, green: 0.58, blue: 0.95)
        case .green:
            return Color(red: 0.24, green: 0.66, blue: 0.46)
        case .amber:
            return Color(red: 0.86, green: 0.56, blue: 0.24)
        case .rose:
            return Color(red: 0.78, green: 0.36, blue: 0.50)
        case .violet:
            return Color(red: 0.56, green: 0.48, blue: 0.86)
        }
    }

    var backgroundColor: Color {
        switch self {
        case .graphite:
            return Color(red: 0.15, green: 0.16, blue: 0.18)
        case .blue:
            return Color(red: 0.12, green: 0.17, blue: 0.24)
        case .green:
            return Color(red: 0.12, green: 0.20, blue: 0.17)
        case .amber:
            return Color(red: 0.23, green: 0.18, blue: 0.12)
        case .rose:
            return Color(red: 0.23, green: 0.14, blue: 0.17)
        case .violet:
            return Color(red: 0.17, green: 0.15, blue: 0.24)
        }
    }

    var lockedBackgroundColor: Color {
        backgroundColor.opacity(0.88)
    }
}
