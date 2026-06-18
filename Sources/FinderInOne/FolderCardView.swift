import FinderWorkbenchCore
import SwiftUI
import UniformTypeIdentifiers

struct FolderCardView: View {
    let card: FolderCard
    let items: [FileItem]
    let errorMessage: String?
    let onToggleLock: () -> Void
    let onOpenInFinder: () -> Void
    let onClose: () -> Void
    let onMoveEarlier: () -> Void
    let onMoveLater: () -> Void
    let selectedItemURLs: Set<URL>
    let onSelectionChange: (Set<URL>) -> Void
    let onDropFiles: ([URL]) -> Bool
    let onOpenItem: (FileItem) -> Void
    let onMoveTo: (Double, Double, Bool) -> Void
    let onResize: (Double, Double, Bool) -> Void

    @State private var isDropTargeted = false
    @State private var moveStartFrame: CardFrame?
    @State private var resizeStartFrame: CardFrame?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            Divider()
                .overlay(Color.white.opacity(0.18))
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
        .padding(10)
        .foregroundStyle(.white.opacity(0.9))
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor, lineWidth: isDropTargeted ? 2 : 1)
        )
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted, perform: handleDrop(providers:))
    }

    private var header: some View {
        HStack(alignment: .top) {
            titleArea
            HStack(spacing: 4) {
                if card.canMove {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 18, height: 18)
                        .contentShape(Rectangle())
                        .gesture(moveGesture)
                        .help("Drag card")
                    Button(action: onMoveEarlier) {
                        Image(systemName: "chevron.left")
                    }
                    .help("Move earlier")
                    Button(action: onMoveLater) {
                        Image(systemName: "chevron.right")
                    }
                    .help("Move later")
                }
                Button(card.isLocked ? "Unlock" : "Lock", action: onToggleLock)
                Button("Finder", action: onOpenInFinder)
                if card.canClose {
                    Button("Close", action: onClose)
                }
            }
            .font(.system(size: 11))
        }
    }

    @ViewBuilder
    private var titleArea: some View {
        let content = VStack(alignment: .leading, spacing: 2) {
            Text(card.displayName)
                .font(.headline)
            Text(card.folderPath)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.62))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        if card.canMove {
            content
                .contentShape(Rectangle())
                .gesture(moveGesture)
                .help("Drag card")
        } else {
            content
        }
    }

    private var fileRows: some View {
        FolderItemsTableView(
            items: items,
            selectedItemURLs: selectedItemURLs,
            onSelectionChange: onSelectionChange,
            onOpenItem: onOpenItem,
            onDropURLs: onDropFiles
        )
    }

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                let startFrame = moveStartFrame ?? card.frame
                moveStartFrame = startFrame
                onMoveTo(
                    startFrame.x + value.translation.width,
                    startFrame.y + value.translation.height,
                    false
                )
            }
            .onEnded { value in
                let startFrame = moveStartFrame ?? card.frame
                onMoveTo(
                    startFrame.x + value.translation.width,
                    startFrame.y + value.translation.height,
                    true
                )
                moveStartFrame = nil
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
        card.isLocked ? Color(red: 0.18, green: 0.20, blue: 0.22) : Color(red: 0.15, green: 0.16, blue: 0.18)
    }

    private var borderColor: Color {
        if isDropTargeted {
            return .accentColor
        }
        if card.isLocked {
            return Color.accentColor.opacity(0.55)
        }
        return Color.white.opacity(0.16)
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
            return false
        }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            guard let url = Self.fileURL(from: item) else {
                return
            }
            DispatchQueue.main.async {
                _ = onDropFiles([url])
            }
        }
        return true
    }

    nonisolated private static func fileURL(from item: NSSecureCoding?) -> URL? {
        if let url = item as? URL {
            return url
        }
        if let url = item as? NSURL {
            return url as URL
        }
        if let data = item as? Data,
           let string = String(data: data, encoding: .utf8) {
            return URL(string: string)
        }
        return nil
    }
}
