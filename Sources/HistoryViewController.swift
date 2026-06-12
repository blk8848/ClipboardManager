import Cocoa

// MARK: - 通知：请求关闭面板

extension Notification.Name {
    static let closeHistoryPanel = Notification.Name("closeHistoryPanel")
}

// MARK: - 历史面板视图控制器

final class HistoryViewController: NSViewController {

    private let scrollView = NSScrollView()
    private let tableView = NSTableView()
    private var items: [ClipboardItem] = []

    /// 防止 viewWillAppear 中的 selectRow 触发 selectionDidChange 回调
    private var suppressSelectionCallback = false

    private enum ColumnID {
        static let time   = NSUserInterfaceItemIdentifier("time")
        static let preview = NSUserInterfaceItemIdentifier("preview")
    }

    // MARK: - 生命周期

    override func loadView() {
        // 磨砂半透明背景（macOS 原生视觉效果）
        let effectView = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 460, height: 480))
        effectView.blendingMode = .behindWindow
        effectView.material = .popover
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 10
        effectView.layer?.masksToBounds = true
        view = effectView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
        refresh()

        ClipboardStore.shared.onHistoryChanged = { [weak self] in
            DispatchQueue.main.async { self?.refresh() }
        }
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        refresh()
        // 自动高亮首行（不触发复制）
        if tableView.numberOfRows > 0 {
            suppressSelectionCallback = true
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            suppressSelectionCallback = false
            view.window?.makeFirstResponder(tableView)
        }
    }

    // MARK: - TableView

    private func setupTableView() {
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = tableView
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8),
        ])

        tableView.headerView = nil
        tableView.selectionHighlightStyle = .regular
        tableView.backgroundColor = .clear
        tableView.rowHeight = 36
        tableView.intercellSpacing = NSSize(width: 0, height: 2)
        tableView.allowsMultipleSelection = false
        tableView.delegate = self
        tableView.dataSource = self

        let timeCol = NSTableColumn(identifier: ColumnID.time)
        timeCol.width = 70; timeCol.minWidth = 60
        tableView.addTableColumn(timeCol)

        let prevCol = NSTableColumn(identifier: ColumnID.preview)
        prevCol.width = 370
        tableView.addTableColumn(prevCol)
    }

    func refresh() {
        items = ClipboardStore.shared.history
        tableView.reloadData()
    }

    // MARK: - 选中 → 复制 → 关闭

    private func handleSelection() {
        guard !suppressSelectionCallback else { return }
        let row = tableView.selectedRow
        guard row >= 0, row < items.count else { return }

        ClipboardStore.shared.copyToClipboard(items[row])
        // 通知 AppDelegate 关闭 popover
        NotificationCenter.default.post(name: .closeHistoryPanel, object: nil)
    }
}

// MARK: - NSTableViewDataSource

extension HistoryViewController: NSTableViewDataSource {

    func numberOfRows(in tableView: NSTableView) -> Int { items.count }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        guard row < items.count else { return nil }
        let item = items[row]
        switch tableColumn?.identifier {
        case ColumnID.time:    return item.timeString
        case ColumnID.preview: return item.preview
        default:               return nil
        }
    }
}

// MARK: - NSTableViewDelegate

extension HistoryViewController: NSTableViewDelegate {

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < items.count else { return nil }
        let item = items[row]

        let cellID: NSUserInterfaceItemIdentifier
        let text: String
        let alignment: NSTextAlignment
        let font: NSFont

        switch tableColumn?.identifier {
        case ColumnID.time:
            cellID = NSUserInterfaceItemIdentifier("TimeCell")
            text = item.timeString
            alignment = .right
            font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        case ColumnID.preview:
            cellID = NSUserInterfaceItemIdentifier("PreviewCell")
            text = item.preview
            alignment = .left
            font = NSFont.systemFont(ofSize: 13)
        default:
            return nil
        }

        let reuseID = tableColumn?.identifier ?? cellID
        var cell = tableView.makeView(withIdentifier: reuseID, owner: nil) as? NSTableCellView
        if cell == nil {
            cell = NSTableCellView()
            cell!.identifier = reuseID

            let tf = NSTextField()
            tf.isBordered = false
            tf.isEditable = false
            tf.drawsBackground = false
            tf.lineBreakMode = .byTruncatingTail
            tf.cell?.wraps = false
            tf.cell?.usesSingleLineMode = true
            tf.translatesAutoresizingMaskIntoConstraints = false
            cell!.textField = tf
            cell!.addSubview(tf)

            NSLayoutConstraint.activate([
                tf.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 4),
                tf.trailingAnchor.constraint(equalTo: cell!.trailingAnchor, constant: -4),
                tf.centerYAnchor.constraint(equalTo: cell!.centerYAnchor),
            ])
        }

        cell?.textField?.stringValue = text
        cell?.textField?.alignment = alignment
        cell?.textField?.font = font
        cell?.textField?.textColor = (tableColumn?.identifier == ColumnID.time)
            ? .secondaryLabelColor
            : .labelColor

        return cell
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool { true }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard tableView.selectedRow >= 0 else { return }
        handleSelection()
    }
}
