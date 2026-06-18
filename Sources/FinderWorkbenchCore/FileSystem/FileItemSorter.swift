import Foundation

public enum FileItemSortColumn: String, Sendable {
    case name
    case modified
    case size
    case kind
}

public struct FileItemSortOrder: Equatable, Sendable {
    public let column: FileItemSortColumn
    public let ascending: Bool

    public init(column: FileItemSortColumn, ascending: Bool) {
        self.column = column
        self.ascending = ascending
    }
}

public enum FileItemSorter {
    public static func sorted(
        _ items: [FileItem],
        by order: FileItemSortOrder = FileItemSortOrder(column: .name, ascending: true),
        keepsFoldersFirst: Bool = true
    ) -> [FileItem] {
        items.sorted { lhs, rhs in
            if keepsFoldersFirst, lhs.isDirectory != rhs.isDirectory {
                return lhs.isDirectory && !rhs.isDirectory
            }

            let primary = compare(lhs, rhs, by: order)
            if primary != .orderedSame {
                return primary == .orderedAscending
            }

            let name = compareStrings(lhs.name, rhs.name, ascending: true)
            if name != .orderedSame {
                return name == .orderedAscending
            }

            return lhs.url.path < rhs.url.path
        }
    }

    private static func compare(
        _ lhs: FileItem,
        _ rhs: FileItem,
        by order: FileItemSortOrder
    ) -> ComparisonResult {
        switch order.column {
        case .name:
            return compareStrings(lhs.name, rhs.name, ascending: order.ascending)
        case .modified:
            return compareOptional(lhs.modifiedAt, rhs.modifiedAt, ascending: order.ascending)
        case .size:
            return compareOptional(lhs.byteSize, rhs.byteSize, ascending: order.ascending)
        case .kind:
            return compareStrings(lhs.kind, rhs.kind, ascending: order.ascending)
        }
    }

    private static func compareStrings(
        _ lhs: String,
        _ rhs: String,
        ascending: Bool
    ) -> ComparisonResult {
        let result = lhs.localizedStandardCompare(rhs)
        return ascending ? result : result.reversed
    }

    private static func compareOptional<Value: Comparable>(
        _ lhs: Value?,
        _ rhs: Value?,
        ascending: Bool
    ) -> ComparisonResult {
        switch (lhs, rhs) {
        case (nil, nil):
            return .orderedSame
        case (nil, _):
            return .orderedDescending
        case (_, nil):
            return .orderedAscending
        case let (lhs?, rhs?):
            if lhs == rhs {
                return .orderedSame
            }
            let result: ComparisonResult = lhs < rhs ? .orderedAscending : .orderedDescending
            return ascending ? result : result.reversed
        }
    }
}

private extension ComparisonResult {
    var reversed: ComparisonResult {
        switch self {
        case .orderedAscending:
            return .orderedDescending
        case .orderedDescending:
            return .orderedAscending
        case .orderedSame:
            return .orderedSame
        }
    }
}
