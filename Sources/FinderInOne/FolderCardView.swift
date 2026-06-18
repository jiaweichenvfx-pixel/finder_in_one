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
    let onDropFile: (URL) -> Bool
    let onOpenItem: (FileItem) -> Void
    let onMoveTo: (Double, Double) -> Void
    let onResize: (Double, Double) -> Void

    @State private var isDropTargeted = false
    @State private var moveStartFrame: CardFrame?
    @State private var resizeStartFrame: CardFrame?

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
            if card.canResize {
                resizeHandle
            }
        }
        .padding(10)
        .background(.regularMaterial)
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
                .foregroundStyle(.secondary)
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
        ScrollView {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                GridRow {
                    Text("Name").bold()
                    Text("Modified").bold()
                    Text("Size").bold()
                    Text("Kind").bold()
                }
                ForEach(items.prefix(100)) { item in
                    GridRow {
                        Text(item.name).lineLimit(1)
                        Text(Self.dateFormatter.string(from: item.modifiedAt ?? .distantPast))
                        Text(item.byteSize.map(Self.byteFormatter.string(fromByteCount:)) ?? "--")
                        Text(item.kind)
                    }
                    .onDrag {
                        NSItemProvider(object: item.url as NSURL)
                    }
                    .onTapGesture(count: 2) {
                        onOpenItem(item)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.system(size: 12, design: .monospaced))
    }

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                let startFrame = moveStartFrame ?? card.frame
                moveStartFrame = startFrame
                onMoveTo(
                    startFrame.x + value.translation.width,
                    startFrame.y + value.translation.height
                )
            }
            .onEnded { _ in
                moveStartFrame = nil
            }
    }

    private var resizeHandle: some View {
        HStack {
            Spacer()
            Image(systemName: "arrow.down.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 18, height: 18)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 2)
                        .onChanged { value in
                            let startFrame = resizeStartFrame ?? card.frame
                            resizeStartFrame = startFrame
                            onResize(
                                startFrame.width + value.translation.width,
                                startFrame.height + value.translation.height
                            )
                        }
                        .onEnded { _ in
                            resizeStartFrame = nil
                        }
                )
        }
    }

    private var borderColor: Color {
        if isDropTargeted {
            return .accentColor
        }
        if card.isLocked {
            return Color.accentColor.opacity(0.55)
        }
        return Color.secondary.opacity(0.25)
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
                _ = onDropFile(url)
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

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()

    private static let byteFormatter = ByteCountFormatter()
}
