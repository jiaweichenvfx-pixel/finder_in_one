import Foundation

public struct Workspace: Codable, Equatable, Sendable {
    public private(set) var cards: [FolderCard]

    public init(cards: [FolderCard] = []) {
        self.cards = cards
    }

    public mutating func addCard(_ card: FolderCard) {
        cards.append(card)
    }

    @discardableResult
    public mutating func closeCard(id: UUID) -> Bool {
        guard let index = cards.firstIndex(where: { $0.id == id }) else {
            return false
        }
        guard cards[index].canClose else {
            return false
        }
        cards.remove(at: index)
        return true
    }

    public mutating func updateCard(_ card: FolderCard) {
        guard let index = cards.firstIndex(where: { $0.id == card.id }) else {
            return
        }
        cards[index] = card
    }
}
