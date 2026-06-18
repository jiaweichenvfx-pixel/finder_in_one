import AppKit
import FinderWorkbenchCore
import SwiftUI
import UniformTypeIdentifiers

extension TransferMode {
    var dragOperation: NSDragOperation {
        switch self {
        case .copy:
            return .copy
        case .moveOnce:
            return .move
        }
    }

    var dropProposalOperation: DropOperation {
        switch self {
        case .copy:
            return .copy
        case .moveOnce:
            return .move
        }
    }
}

@MainActor
struct FolderItemsTableView: NSViewRepresentable {
    let items: [FileItem]
    let selectedItemURLs: Set<URL>
    let transferMode: TransferMode
    let onSelectionChange: (Set<URL>) -> Void
    let onOpenItem: (FileItem) -> Void
    let onPreviewItems: ([FileItem], FileItem?) -> Void
    let onDropURLs: ([URL]) -> Bool

    func makeNSView(context: Context) -> NSScrollView {
        let tableView = FinderTableView()
        tableView.coordinator = context.coordinator
        tableView.style = .plain
        tableView.backgroundColor = .clear
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.allowsMultipleSelection = true
        tableView.allowsEmptySelection = true
        tableView.selectionHighlightStyle = .regular
        tableView.rowSizeStyle = .small
        tableView.intercellSpacing = NSSize(width: 8, height: 2)
        tableView.dataSource = context.coordinator
        tableView.delegate = context.coordinator
        tableView.target = context.coordinator
        tableView.doubleAction = #selector(Coordinator.doubleClicked(_:))
        tableView.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        tableView.setDraggingSourceOperationMask(transferMode.dragOperation, forLocal: true)
        tableView.setDraggingSourceOperationMask(transferMode.dragOperation, forLocal: false)
        tableView.registerForDraggedTypes([.fileURL])

        addColumn("name", title: "Name", width: 190, to: tableView)
        addColumn("modified", title: "Modified", width: 82, to: tableView)
        addColumn("size", title: "Size", width: 74, to: tableView)
        addColumn("kind", title: "Kind", width: 70, to: tableView)

        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.documentView = tableView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let tableView = scrollView.documentView as? NSTableView else {
            return
        }

        context.coordinator.parent = self
        if let tableView = tableView as? FinderTableView {
            tableView.coordinator = context.coordinator
        }
        tableView.setDraggingSourceOperationMask(transferMode.dragOperation, forLocal: true)
        tableView.setDraggingSourceOperationMask(transferMode.dragOperation, forLocal: false)

        let itemFingerprint = items
        let shouldReload = context.coordinator.lastItemFingerprint != itemFingerprint
        let shouldSelect = shouldReload || context.coordinator.lastSelectedItemURLs != selectedItemURLs

        if shouldReload {
            context.coordinator.refreshSortedItems()
            tableView.reloadData()
            context.coordinator.lastItemFingerprint = itemFingerprint
        }
        if shouldSelect {
            context.coordinator.isApplyingSelection = true
            tableView.selectRowIndexes(context.coordinator.selectedRows(for: selectedItemURLs), byExtendingSelection: false)
            context.coordinator.isApplyingSelection = false
            context.coordinator.lastSelectedItemURLs = selectedItemURLs
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private func addColumn(_ identifier: String, title: String, width: CGFloat, to tableView: NSTableView) {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(identifier))
        column.title = title
        column.headerCell = FinderTableHeaderCell(textCell: title)
        column.sortDescriptorPrototype = NSSortDescriptor(key: identifier, ascending: true)
        column.width = width
        column.minWidth = 54
        column.resizingMask = .userResizingMask
        tableView.addTableColumn(column)
    }

    @MainActor
    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        var parent: FolderItemsTableView
        var isApplyingSelection = false
        var lastItemFingerprint: [FileItem] = []
        var lastSelectedItemURLs: Set<URL> = []
        private var sortedItems: [FileItem] = []
        private var sortOrder = FileItemSortOrder(column: .name, ascending: true)

        init(_ parent: FolderItemsTableView) {
            self.parent = parent
            self.sortedItems = FileItemSorter.sorted(parent.items, by: sortOrder)
        }

        func numberOfRows(in tableView: NSTableView) -> Int {
            sortedItems.count
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard let item = item(at: row), let tableColumn else {
                return nil
            }

            let identifier = tableColumn.identifier
            if identifier.rawValue == "name" {
                let cell = tableView.makeView(withIdentifier: identifier, owner: nil) as? FinderNameCellView
                    ?? FinderNameCellView()
                cell.identifier = identifier
                cell.configure(with: item)
                return cell
            }

            let textField = tableView.makeView(withIdentifier: identifier, owner: nil) as? NSTextField
                ?? NSTextField(labelWithString: "")
            textField.identifier = identifier
            textField.stringValue = value(for: item, column: identifier.rawValue)
            textField.lineBreakMode = .byTruncatingMiddle
            textField.maximumNumberOfLines = 1
            textField.font = .systemFont(ofSize: 12)
            textField.textColor = .white.withAlphaComponent(0.88)
            textField.backgroundColor = .clear
            return textField
        }

        func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
            FinderTableRowView()
        }

        func tableViewSelectionDidChange(_ notification: Notification) {
            guard !isApplyingSelection,
                  let tableView = notification.object as? NSTableView else {
                return
            }

            let selectedURLs = Set(tableView.selectedRowIndexes.compactMap { row -> URL? in
                item(at: row)?.url
            })
            parent.onSelectionChange(selectedURLs)
        }

        func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
            item(at: row)?.url as NSURL?
        }

        func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
            guard let descriptor = tableView.sortDescriptors.first,
                  let key = descriptor.key,
                  let column = FileItemSortColumn(rawValue: key) else {
                return
            }

            sortOrder = FileItemSortOrder(column: column, ascending: descriptor.ascending)
            refreshSortedItems()
            tableView.reloadData()

            isApplyingSelection = true
            tableView.selectRowIndexes(selectedRows(for: parent.selectedItemURLs), byExtendingSelection: false)
            isApplyingSelection = false
        }

        func tableView(
            _ tableView: NSTableView,
            validateDrop info: NSDraggingInfo,
            proposedRow row: Int,
            proposedDropOperation dropOperation: NSTableView.DropOperation
        ) -> NSDragOperation {
            if let source = info.draggingSource as? NSTableView, source === tableView {
                return []
            }
            tableView.setDropRow(-1, dropOperation: .on)
            return parent.transferMode.dragOperation
        }

        func tableView(
            _ tableView: NSTableView,
            acceptDrop info: NSDraggingInfo,
            row: Int,
            dropOperation: NSTableView.DropOperation
        ) -> Bool {
            let urls = urls(from: info.draggingPasteboard)
            guard !urls.isEmpty else {
                return false
            }
            return parent.onDropURLs(urls)
        }

        @objc func doubleClicked(_ sender: NSTableView) {
            guard let item = item(at: sender.clickedRow) else {
                return
            }
            parent.onOpenItem(item)
        }

        func previewSelection(in tableView: NSTableView) {
            let selectedItems = tableView.selectedRowIndexes.compactMap { row -> FileItem? in
                item(at: row)
            }

            if selectedItems.isEmpty,
               let clickedItem = item(at: tableView.clickedRow) {
                parent.onPreviewItems(sortedItems, clickedItem)
            } else if selectedItems.count == 1, let first = selectedItems.first {
                parent.onPreviewItems(sortedItems, first)
            } else {
                parent.onPreviewItems(selectedItems, selectedItems.first)
            }
        }

        func previewAdjacentSelection(in tableView: NSTableView, direction: Int) {
            guard !sortedItems.isEmpty else {
                return
            }

            let currentRow: Int
            if direction < 0 {
                currentRow = tableView.selectedRowIndexes.min() ?? tableView.clickedRow
            } else {
                currentRow = tableView.selectedRowIndexes.max() ?? tableView.clickedRow
            }

            let fallbackRow = currentRow >= 0 ? currentRow : 0
            let nextRow = min(max(fallbackRow + direction, 0), sortedItems.count - 1)
            guard let nextItem = item(at: nextRow) else {
                return
            }

            isApplyingSelection = true
            tableView.selectRowIndexes(IndexSet(integer: nextRow), byExtendingSelection: false)
            tableView.scrollRowToVisible(nextRow)
            isApplyingSelection = false
            parent.onSelectionChange([nextItem.url])
            parent.onPreviewItems(sortedItems, nextItem)
        }

        func refreshSortedItems() {
            sortedItems = FileItemSorter.sorted(parent.items, by: sortOrder)
        }

        func selectedRows(for selectedItemURLs: Set<URL>) -> IndexSet {
            IndexSet(sortedItems.indices.filter { selectedItemURLs.contains(sortedItems[$0].url) })
        }

        private func item(at row: Int) -> FileItem? {
            guard row >= 0, row < sortedItems.count else {
                return nil
            }
            return sortedItems[row]
        }

        private func value(for item: FileItem, column: String) -> String {
            switch column {
            case "name":
                return item.name
            case "modified":
                guard let modifiedAt = item.modifiedAt else {
                    return "--"
                }
                return Self.dateFormatter.string(from: modifiedAt)
            case "size":
                return item.byteSize.map(Self.byteFormatter.string(fromByteCount:)) ?? "--"
            case "kind":
                return item.kind
            default:
                return ""
            }
        }

        private func urls(from pasteboard: NSPasteboard) -> [URL] {
            if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL] {
                return urls
            }

            guard let items = pasteboard.pasteboardItems else {
                return []
            }

            return items.compactMap { item in
                guard let string = item.string(forType: .fileURL) else {
                    return nil
                }
                return URL(string: string)
            }
        }

        private static let dateFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .none
            return formatter
        }()

        private static let byteFormatter = ByteCountFormatter()
    }
}

@MainActor
private final class FinderNameCellView: NSTableCellView {
    private let iconView = NSImageView()
    private let nameField = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func configure(with item: FileItem) {
        iconView.image = NSImage(
            systemSymbolName: item.isDirectory ? "folder.fill" : "doc",
            accessibilityDescription: item.isDirectory ? "Folder" : "File"
        )
        iconView.contentTintColor = item.isDirectory
            ? NSColor.systemBlue.withAlphaComponent(0.92)
            : NSColor.white.withAlphaComponent(0.58)
        nameField.stringValue = item.name
        nameField.font = item.isDirectory
            ? .systemFont(ofSize: 12, weight: .medium)
            : .systemFont(ofSize: 12)
        nameField.textColor = item.isDirectory
            ? .white.withAlphaComponent(0.96)
            : .white.withAlphaComponent(0.86)
    }

    private func setup() {
        guard subviews.isEmpty else {
            return
        }

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        iconView.imageScaling = .scaleProportionallyDown

        nameField.translatesAutoresizingMaskIntoConstraints = false
        nameField.lineBreakMode = .byTruncatingMiddle
        nameField.maximumNumberOfLines = 1
        nameField.backgroundColor = .clear

        addSubview(iconView)
        addSubview(nameField)
        imageView = iconView
        textField = nameField

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),
            nameField.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 6),
            nameField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            nameField.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
}

@MainActor
private final class FinderTableView: NSTableView {
    weak var coordinator: FolderItemsTableView.Coordinator?

    override func keyDown(with event: NSEvent) {
        if event.charactersIgnoringModifiers == " " {
            coordinator?.previewSelection(in: self)
            return
        }
        if FilePreviewing.isPreviewVisible, event.keyCode == 126 {
            coordinator?.previewAdjacentSelection(in: self, direction: -1)
            return
        }
        if FilePreviewing.isPreviewVisible, event.keyCode == 125 {
            coordinator?.previewAdjacentSelection(in: self, direction: 1)
            return
        }
        super.keyDown(with: event)
    }
}

private final class FinderTableHeaderCell: NSTableHeaderCell {
    override func draw(withFrame cellFrame: NSRect, in controlView: NSView) {
        NSColor(red: 0.23, green: 0.24, blue: 0.26, alpha: 1).setFill()
        cellFrame.fill()
        super.drawInterior(withFrame: cellFrame.insetBy(dx: 6, dy: 0), in: controlView)
    }

    override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byTruncatingTail
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.66),
            .paragraphStyle: paragraphStyle
        ]
        let attributedTitle = NSAttributedString(string: stringValue, attributes: attributes)
        attributedTitle.draw(in: cellFrame.insetBy(dx: 6, dy: 3))
    }
}

private final class FinderTableRowView: NSTableRowView {
    override func drawBackground(in dirtyRect: NSRect) {
        if isSelected {
            NSColor.controlAccentColor.withAlphaComponent(0.86).setFill()
            dirtyRect.fill()
        } else if isEmphasized {
            NSColor.white.withAlphaComponent(0.04).setFill()
            dirtyRect.fill()
        }
    }
}
