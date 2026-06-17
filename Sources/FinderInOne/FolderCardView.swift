import FinderWorkbenchCore
import SwiftUI

struct FolderCardView: View {
    let card: FolderCard

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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
                    Button(card.isLocked ? "Unlock" : "Lock") {}
                    Button("Finder") {}
                    if card.canClose {
                        Button("Close") {}
                    }
                }
                .font(.system(size: 11))
            }

            Divider()

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                GridRow {
                    Text("Name").bold()
                    Text("Date").bold()
                    Text("Kind").bold()
                }
                GridRow {
                    Text("Brief.pdf")
                    Text("Today")
                    Text("PDF")
                }
                GridRow {
                    Text("Images")
                    Text("Jun 14")
                    Text("Folder")
                }
                GridRow {
                    Text("Notes.md")
                    Text("Jun 11")
                    Text("Markdown")
                }
            }
            .font(.system(size: 12, design: .monospaced))

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(card.isLocked ? Color.accentColor.opacity(0.55) : Color.secondary.opacity(0.25), lineWidth: 1)
        )
    }
}
