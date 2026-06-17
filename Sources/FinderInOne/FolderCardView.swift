import FinderWorkbenchCore
import SwiftUI

struct FolderCardView: View {
    let card: FolderCard
    let items: [FileItem]
    let errorMessage: String?
    let onToggleLock: () -> Void
    let onOpenInFinder: () -> Void
    let onClose: () -> Void

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
        }
        .padding(10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(card.isLocked ? Color.accentColor.opacity(0.55) : Color.secondary.opacity(0.25), lineWidth: 1)
        )
    }

    private var header: some View {
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
                Button(card.isLocked ? "Unlock" : "Lock", action: onToggleLock)
                Button("Finder", action: onOpenInFinder)
                if card.canClose {
                    Button("Close", action: onClose)
                }
            }
            .font(.system(size: 11))
        }
    }

    private var fileRows: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
            GridRow {
                Text("Name").bold()
                Text("Modified").bold()
                Text("Size").bold()
                Text("Kind").bold()
            }
            ForEach(items.prefix(20)) { item in
                GridRow {
                    Text(item.name).lineLimit(1)
                    Text(Self.dateFormatter.string(from: item.modifiedAt ?? .distantPast))
                    Text(item.byteSize.map(Self.byteFormatter.string(fromByteCount:)) ?? "--")
                    Text(item.kind)
                }
            }
        }
        .font(.system(size: 12, design: .monospaced))
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()

    private static let byteFormatter = ByteCountFormatter()
}
