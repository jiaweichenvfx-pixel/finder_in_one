import FinderWorkbenchCore
import SwiftUI

struct WorkspaceView: View {
    @State private var viewModel = WorkspaceViewModel()

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 10)], spacing: 10) {
                    ForEach(viewModel.workspace.cards) { card in
                        cardView(for: card)
                    }
                }
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
            onDropFile: { url in
                viewModel.transfer(item: fileItem(for: url), to: card)
            },
            onResize: { width, height in
                viewModel.resizeCard(id: card.id, width: width, height: height)
            }
        )
        .frame(minWidth: 260, idealWidth: card.frame.width)
        .frame(height: card.frame.height)
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
            Button("+") {
                viewModel.addDemoFolder()
            }
                .help("Add folder")
            modeButton("Copy", isSelected: viewModel.transferMode == .copy) {
                viewModel.transferMode = .copy
            }
            modeButton("Move once", isSelected: viewModel.transferMode == .moveOnce) {
                viewModel.transferMode = .moveOnce
            }
            Text("\(viewModel.workspace.cards.count) folders")
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

}
