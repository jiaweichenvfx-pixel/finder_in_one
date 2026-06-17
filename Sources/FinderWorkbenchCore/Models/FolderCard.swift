import Foundation

public struct CardFrame: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct FolderCard: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var displayName: String
    public var folderPath: String
    public var frame: CardFrame
    public var isLocked: Bool

    public init(id: UUID = UUID(), displayName: String, folderPath: String, frame: CardFrame, isLocked: Bool = false) {
        self.id = id
        self.displayName = displayName
        self.folderPath = folderPath
        self.frame = frame
        self.isLocked = isLocked
    }

    public var canMove: Bool { !isLocked }
    public var canResize: Bool { !isLocked }
    public var canClose: Bool { !isLocked }

    @discardableResult
    public mutating func move(toX x: Double, y: Double) -> Bool {
        guard canMove else { return false }
        frame.x = x
        frame.y = y
        return true
    }

    @discardableResult
    public mutating func resize(width: Double, height: Double) -> Bool {
        guard canResize else { return false }
        frame.width = max(180, width)
        frame.height = max(120, height)
        return true
    }
}
