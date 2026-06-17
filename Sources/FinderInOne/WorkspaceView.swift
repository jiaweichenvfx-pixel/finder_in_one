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
                        FolderCardView(card: card)
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
            Button("Copy") {
                transferMode = .copy
            }
            .buttonStyle(.borderedProminent)
            Button("Move once") {
                transferMode = .moveOnce
            }
            Text("\(workspace.cards.count) folders")
                .foregroundStyle(.secondary)
            Spacer()
            TextField("Search", text: .constant(""))
                .textFieldStyle(.roundedBorder)
                .frame(width: 160)
        }
        .font(.system(size: 12))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private static let sampleCards: [FolderCard] = [
        FolderCard(displayName: "Client A", folderPath: "/Users/test/Client A", frame: CardFrame(x: 0, y: 0, width: 360, height: 260)),
        FolderCard(displayName: "Projects", folderPath: "/Users/test/Projects", frame: CardFrame(x: 0, y: 0, width: 360, height: 220), isLocked: true),
        FolderCard(displayName: "Downloads", folderPath: "/Users/test/Downloads", frame: CardFrame(x: 0, y: 0, width: 260, height: 180)),
    ]
}
