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

public enum FolderCardColor: String, Codable, CaseIterable, Equatable, Sendable {
    case graphite
    case blue
    case green
    case amber
    case rose
    case violet
}

public struct FolderCard: Codable, Equatable, Identifiable, Sendable {
    public static let collapsedHeight: Double = 42

    public var id: UUID
    public var displayName: String
    public var folderPath: String
    public var frame: CardFrame
    public var isLocked: Bool
    public var bookmarkData: Data?
    public var isCollapsed: Bool
    public var expandedFrame: CardFrame?
    public var color: FolderCardColor
    public var suffixFilterText: String?
    public var sortOrder: FileItemSortOrder?
    public var selectedItemPaths: [String]

    public init(
        id: UUID = UUID(),
        displayName: String,
        folderPath: String,
        frame: CardFrame,
        isLocked: Bool = false,
        bookmarkData: Data? = nil,
        isCollapsed: Bool = false,
        expandedFrame: CardFrame? = nil,
        color: FolderCardColor = .graphite,
        suffixFilterText: String? = nil,
        sortOrder: FileItemSortOrder? = nil,
        selectedItemPaths: [String] = []
    ) {
        self.id = id
        self.displayName = displayName
        self.folderPath = folderPath
        self.frame = frame
        self.isLocked = isLocked
        self.bookmarkData = bookmarkData
        self.isCollapsed = isCollapsed
        self.expandedFrame = expandedFrame
        self.color = color
        self.suffixFilterText = suffixFilterText
        self.sortOrder = sortOrder
        self.selectedItemPaths = selectedItemPaths
    }

    public var folderURL: URL {
        URL(fileURLWithPath: folderPath, isDirectory: true)
    }

    public var canMove: Bool { !isLocked }
    public var canResize: Bool { !isLocked && !isCollapsed }
    public var canClose: Bool { !isLocked }

    public var canCollapse: Bool { true }
    public var canExpand: Bool { isCollapsed }

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

    @discardableResult
    public mutating func collapse() -> Bool {
        guard !isCollapsed else {
            return false
        }
        expandedFrame = frame
        frame.height = FolderCard.collapsedHeight
        isCollapsed = true
        return true
    }

    @discardableResult
    public mutating func expand() -> Bool {
        guard isCollapsed else {
            return false
        }
        if let expandedFrame {
            frame = expandedFrame
        } else {
            frame.height = 240
        }
        isCollapsed = false
        self.expandedFrame = nil
        return true
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case folderPath
        case frame
        case isLocked
        case bookmarkData
        case isCollapsed
        case expandedFrame
        case color
        case suffixFilterText
        case sortOrder
        case selectedItemPaths
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        folderPath = try container.decode(String.self, forKey: .folderPath)
        frame = try container.decode(CardFrame.self, forKey: .frame)
        isLocked = try container.decode(Bool.self, forKey: .isLocked)
        bookmarkData = try container.decodeIfPresent(Data.self, forKey: .bookmarkData)
        isCollapsed = try container.decodeIfPresent(Bool.self, forKey: .isCollapsed) ?? false
        expandedFrame = try container.decodeIfPresent(CardFrame.self, forKey: .expandedFrame)
        color = try container.decodeIfPresent(FolderCardColor.self, forKey: .color) ?? .graphite
        suffixFilterText = try container.decodeIfPresent(String.self, forKey: .suffixFilterText)
        sortOrder = try container.decodeIfPresent(FileItemSortOrder.self, forKey: .sortOrder)
        selectedItemPaths = try container.decodeIfPresent([String].self, forKey: .selectedItemPaths) ?? []
    }
}
