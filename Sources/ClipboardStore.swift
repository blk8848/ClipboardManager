import Cocoa

/// 剪切板历史条目
struct ClipboardItem: Codable, Equatable {
    let content: String
    let timestamp: Date

    /// 单行预览（最多 80 字符）
    var preview: String {
        let singleLine = content.replacingOccurrences(of: "\n", with: " ⏎ ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if singleLine.count <= 80 { return singleLine }
        return String(singleLine.prefix(80)) + "…"
    }

    /// 格式化时间
    var timeString: String {
        let fmt = DateFormatter()
        if Calendar.current.isDateInToday(timestamp) {
            fmt.dateFormat = "HH:mm:ss"
        } else if Calendar.current.isDateInYesterday(timestamp) {
            fmt.dateFormat = "'昨天' HH:mm"
        } else {
            fmt.dateFormat = "MM-dd HH:mm"
        }
        return fmt.string(from: timestamp)
    }

    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        lhs.content == rhs.content
    }
}

// MARK: - 剪切板存储器

final class ClipboardStore {

    static let shared = ClipboardStore()

    private(set) var history: [ClipboardItem] = [] {
        didSet { saveHistory() }
    }

    private let maxCount = 50
    private var lastChangeCount: Int = 0
    private var timer: Timer?
    private let storeURL: URL

    /// 历史变化回调（供 UI 刷新）
    var onHistoryChanged: (() -> Void)?

    private init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ClipboardManager")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        storeURL = dir.appendingPathComponent("history.json")

        loadHistory()
        lastChangeCount = NSPasteboard.general.changeCount
        startPolling()
    }

    // MARK: - 轮询

    private func startPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    private func poll() {
        let pb = NSPasteboard.general
        let currentCount = pb.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        guard let text = pb.string(forType: .string),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return }

        // 去重：移除旧相同内容
        history.removeAll { $0.content == text }
        history.insert(ClipboardItem(content: text, timestamp: Date()), at: 0)

        if history.count > maxCount {
            history = Array(history.prefix(maxCount))
        }

        DispatchQueue.main.async { [weak self] in
            self?.onHistoryChanged?()
        }
    }

    // MARK: - 删除

    func deleteItem(at index: Int) {
        guard index >= 0, index < history.count else { return }
        history.remove(at: index)
        DispatchQueue.main.async { [weak self] in
            self?.onHistoryChanged?()
        }
    }

    // MARK: - 复制

    func copyToClipboard(_ item: ClipboardItem) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(item.content, forType: .string)
        lastChangeCount = pb.changeCount  // 避免回读自身写入
    }

    // MARK: - 持久化

    private func loadHistory() {
        guard let data = try? Data(contentsOf: storeURL),
              let items = try? JSONDecoder().decode([ClipboardItem].self, from: data)
        else { return }
        history = items
    }

    private func saveHistory() {
        guard let data = try? JSONEncoder().encode(history) else { return }
        try? data.write(to: storeURL, options: .atomic)
    }
}
