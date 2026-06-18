import AppKit
import FinderWorkbenchCore
import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct FolderItemsTableView: NSViewRepresentable {
    let items: [FileItem]
    let selectedItemURLs: Set<URL>
    let onSelectionChange: (Set<URL>) -> Void
    let onOpenItem: (FileItem) -> Void
    let onPreviewItems: ([FileItem]) -> Void
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
        tableView.setDraggingSourceOperationMask([.copy, .move], forLocal: true)
        tableView.setDraggingSourceOperationMask([.copy, .move], forLocal: false)
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

        let itemFingerprint = items
        let selection = selectedRows()
        let shouldReload = context.coordinator.lastItemFingerprint != itemFingerprint
        let shouldSelect = shouldReload || context.coordinator.lastSelectedItemURLs != selectedItemURLs

        if shouldReload {
            tableView.reloadData()
            context.coordinator.lastItemFingerprint = itemFingerprint
        }
        if shouldSelect {
            context.coordinator.isApplyingSelection = true
            tableView.selectRowIndexes(selection, byExtendingSelection: false)
            context.coordinator.isApplyingSelection = false
            context.coordinator.lastSelectedItemURLs = selectedItemURLs
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private func selectedRows() -> IndexSet {
        IndexSet(items.indices.filter { selectedItemURLs.contains(items[$0].url) })
    }

    private func addColumn(_ identifier: String, title: String, width: CGFloat, to tableView: NSTableView) {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(identifier))
        column.title = title
        column.headerCell = FinderTableHeaderCell(textCell: title)
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

        init(_ parent: FolderItemsTableView) {
            self.parent = parent
        }

        func numberOfRows(in tableView: NSTableView) -> Int {
            parent.items.count
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard row < parent.items.count, let tableColumn else {
                return nil
            }

            let identifier = tableColumn.identifier
            let textField = tableView.makeView(withIdentifier: identifier, owner: nil) as? NSTextField
                ?? NSTextField(labelWithString: "")
            textField.identifier = identifier
            textField.stringValue = value(for: parent.items[row], column: identifier.rawValue)
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
                guard row < parent.items.count else {
                    return nil
                }
                return parent.items[row].url
            })
            parent.onSelectionChange(selectedURLs)
        }

        func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
            guard row < parent.items.count else {
                return nil
            }
            return parent.items[row].url as NSURL
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
            return .copy
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
            guard sender.clickedRow >= 0, sender.clickedRow < parent.items.count else {
                return
            }
            parent.onOpenItem(parent.items[sender.clickedRow])
        }

        func previewSelection(in tableView: NSTableView) {
            let selectedItems = tableView.selectedRowIndexes.compactMap { row -> FileItem? in
                guard row < parent.items.count else {
                    return nil
                }
                return parent.items[row]
            }

            if selectedItems.isEmpty,
               tableView.clickedRow >= 0,
               tableView.clickedRow < parent.items.count {
                parent.onPreviewItems([parent.items[tableView.clickedRow]])
            } else {
                parent.onPreviewItems(selectedItems)
            }
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
private final class FinderTableView: NSTableView {
    weak var coordinator: FolderItemsTableView.Coordinator?

    override func keyDown(with event: NSEvent) {
        if event.charactersIgnoringModifiers == " " {
            coordinator?.previewSelection(in: self)
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
