import FinderWorkbenchCore
import SwiftUI

struct WorkspaceView: View {
    @State private var viewModel = WorkspaceViewModel()

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            ScrollView([.horizontal, .vertical]) {
                ZStack(alignment: .topLeading) {
                    ForEach(viewModel.workspace.cards) { card in
                        cardView(for: card)
                    }
                }
                .frame(width: canvasSize.width, height: canvasSize.height, alignment: .topLeading)
                .padding(10)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func cardView(for card: FolderCard) -> some View {
        FolderCardView(
            card: card,
            items: viewModel.itemsByCardID[card.id] ?? [],
            errorMessage: viewModel.errorsByCardID[card.id],
            onToggleLock: { viewModel.toggleLock(for: card.id) },
            onOpenInFinder: { viewModel.openInFinder(card: card) },
            onClose: { viewModel.closeCard(id: card.id) },
            onMoveEarlier: { viewModel.moveCard(id: card.id, offset: -1) },
            onMoveLater: { viewModel.moveCard(id: card.id, offset: 1) },
            onDropFile: { url in
                viewModel.transfer(item: fileItem(for: url), to: card)
            },
            onOpenItem: { item in
                viewModel.open(item: item, in: card)
            },
            onMoveTo: { x, y in
                viewModel.moveCard(id: card.id, x: x, y: y)
            },
            onResize: { width, height in
                viewModel.resizeCard(id: card.id, width: width, height: height)
            }
        )
        .frame(width: card.frame.width, height: card.frame.height)
        .position(x: card.frame.x + card.frame.width / 2, y: card.frame.y + card.frame.height / 2)
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
            Spacer()
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

    private var canvasSize: CGSize {
        let rightEdge = viewModel.workspace.cards.map { $0.frame.x + $0.frame.width }.max() ?? 900
        let bottomEdge = viewModel.workspace.cards.map { $0.frame.y + $0.frame.height }.max() ?? 600
        return CGSize(width: max(900, rightEdge + 40), height: max(600, bottomEdge + 40))
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
