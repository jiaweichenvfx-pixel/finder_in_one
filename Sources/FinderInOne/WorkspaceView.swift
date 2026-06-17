import FinderWorkbenchCore
import SwiftUI

struct WorkspaceView: View {
    @State private var workspace = Workspace(cards: WorkspaceView.sampleCards)
    @State private var transferMode = TransferMode.copy

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 10)], spacing: 10) {
                    ForEach(workspace.cards) { card in
                        FolderCardView(
                            card: card,
                            onToggleLock: { toggleLock(for: card.id) },
                            onClose: { closeCard(id: card.id) }
                        )
                            .frame(height: card.frame.height)
                    }
                }
                .padding(10)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Button("+") {}
                .help("Add folder")
            modeButton("Copy", isSelected: transferMode == .copy) {
                transferMode = .copy
            }
            modeButton("Move once", isSelected: transferMode == .moveOnce) {
                transferMode = .moveOnce
            }
            Text("\(workspace.cards.count) folders")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .font(.system(size: 12))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
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

    private func toggleLock(for id: UUID) {
        guard var card = workspace.cards.first(where: { $0.id == id }) else {
            return
        }
        card.isLocked.toggle()
        workspace.updateCard(card)
    }

    private func closeCard(id: UUID) {
        workspace.closeCard(id: id)
    }

    private static let sampleCards: [FolderCard] = [
        FolderCard(displayName: "Client A", folderPath: "/Users/test/Client A", frame: CardFrame(x: 0, y: 0, width: 360, height: 260)),
        FolderCard(displayName: "Projects", folderPath: "/Users/test/Projects", frame: CardFrame(x: 0, y: 0, width: 360, height: 220), isLocked: true),
        FolderCard(displayName: "Downloads", folderPath: "/Users/test/Downloads", frame: CardFrame(x: 0, y: 0, width: 260, height: 180)),
    ]
}
