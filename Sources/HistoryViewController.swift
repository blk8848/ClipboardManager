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
        static let index   = NSUserInterfaceItemIdentifier("index")
        static let time    = NSUserInterfaceItemIdentifier("time")
        static let preview = NSUserInterfaceItemIdentifier("preview")
        static let delete  = NSUserInterfaceItemIdentifier("delete")
    }

    // MARK: - 生命周期

    override func loadView() {
        // 磨砂半透明背景（macOS 原生视觉效果）
        let effectView = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 470, height: 480))
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
        scrollView.hasHorizontalScroller = false
        scrollView.horizontalScrollElasticity = .none
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

        // 序号列（自适应宽度）
        let idxCol = NSTableColumn(identifier: ColumnID.index)
        idxCol.minWidth = 20; idxCol.maxWidth = 40; idxCol.width = 22
        tableView.addTableColumn(idxCol)

        // 时间列
        let timeCol = NSTableColumn(identifier: ColumnID.time)
        timeCol.width = 68; timeCol.minWidth = 56
        tableView.addTableColumn(timeCol)

        // 预览内容列（自适应：填满剩余空间，初始值随后由 refresh 计算）
        let prevCol = NSTableColumn(identifier: ColumnID.preview)
        prevCol.width = 312
        tableView.addTableColumn(prevCol)

        // 删除按钮列
        let delCol = NSTableColumn(identifier: ColumnID.delete)
        delCol.width = 28; delCol.minWidth = 24
        tableView.addTableColumn(delCol)
    }

    func refresh() {
        items = ClipboardStore.shared.history
        let count = items.count

        // 序号列自适应宽度：根据最大序号字符串精确计算
        let maxStr = String(max(count, 1))
        let idxTextWidth = (maxStr as NSString).size(withAttributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        ]).width
        let idxWidth = min(max(ceil(idxTextWidth) + 10, 22), 40)

        if let idxCol = tableView.tableColumn(withIdentifier: ColumnID.index) {
            idxCol.width = idxWidth
        }

        // 预览列填满剩余空间（scrollView 可见宽 - 序号 - 时间68 - 删除28）
        let visibleWidth = view.bounds.width - 16 - 15   // 边距 - 滚动条
        let previewWidth = visibleWidth - idxWidth - 68 - 28
        if let prevCol = tableView.tableColumn(withIdentifier: ColumnID.preview) {
            prevCol.width = max(previewWidth, 80)
        }

        tableView.reloadData()
    }

    // MARK: - 删除行

    @objc private func deleteRow(_ sender: NSButton) {
        let row = sender.tag
        guard row >= 0, row < items.count else { return }
        ClipboardStore.shared.deleteItem(at: row)
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
        case ColumnID.index:   return "\(items.count - row)"
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
        let colID = tableColumn?.identifier

        // ── 序号列 ──
        if colID == ColumnID.index {
            let reuseID = ColumnID.index
            var cell = tableView.makeView(withIdentifier: reuseID, owner: nil) as? NSTableCellView
            if cell == nil {
                cell = NSTableCellView()
                cell!.identifier = reuseID
                let tf = makeTextField()
                tf.alignment = .center
                tf.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
                tf.textColor = .tertiaryLabelColor
                cell!.textField = tf
                cell!.addSubview(tf)
                NSLayoutConstraint.activate([
                    tf.centerXAnchor.constraint(equalTo: cell!.centerXAnchor),
                    tf.centerYAnchor.constraint(equalTo: cell!.centerYAnchor),
                ])
            }
            cell?.textField?.stringValue = "\(items.count - row)"
            return cell
        }

        // ── 删除按钮列 ──
        if colID == ColumnID.delete {
            let reuseID = ColumnID.delete
            var cell = tableView.makeView(withIdentifier: reuseID, owner: nil)
            if cell == nil {
                let container = NSView(frame: .zero)
                container.identifier = reuseID

                let btn = NSButton(title: "X", target: self, action: #selector(deleteRow(_:)))
                btn.bezelStyle = .inline
                btn.isBordered = false
                btn.font = NSFont.systemFont(ofSize: 15, weight: .regular)
                btn.contentTintColor = .tertiaryLabelColor
                btn.translatesAutoresizingMaskIntoConstraints = false
                container.addSubview(btn)

                NSLayoutConstraint.activate([
                    btn.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                    btn.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                    btn.widthAnchor.constraint(equalToConstant: 22),
                    btn.heightAnchor.constraint(equalToConstant: 22),
                ])
                cell = container
            }
            // 把 row 存到按钮的 tag 里
            if let btn = cell?.subviews.first as? NSButton {
                btn.tag = row
            }
            return cell
        }

        // ── 时间列 / 预览列 ──
        let cellID: NSUserInterfaceItemIdentifier
        let text: String
        let alignment: NSTextAlignment
        let font: NSFont

        if colID == ColumnID.time {
            cellID = NSUserInterfaceItemIdentifier("TimeCell")
            text = item.timeString
            alignment = .right
            font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        } else {
            cellID = NSUserInterfaceItemIdentifier("PreviewCell")
            text = item.preview
            alignment = .left
            font = NSFont.systemFont(ofSize: 13)
        }

        let reuseID = colID ?? cellID
        var cell = tableView.makeView(withIdentifier: reuseID, owner: nil) as? NSTableCellView
        if cell == nil {
            cell = NSTableCellView()
            cell!.identifier = reuseID
            let tf = makeTextField()
            tf.textColor = (colID == ColumnID.time) ? .secondaryLabelColor : .labelColor
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

        return cell
    }

    /// 创建通用 NSTextField
    private func makeTextField() -> NSTextField {
        let tf = NSTextField()
        tf.isBordered = false
        tf.isEditable = false
        tf.drawsBackground = false
        tf.lineBreakMode = .byTruncatingTail
        tf.cell?.wraps = false
        tf.cell?.usesSingleLineMode = true
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool { true }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard tableView.selectedRow >= 0 else { return }
        handleSelection()
    }
}
