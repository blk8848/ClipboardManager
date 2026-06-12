import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        setupPopover()

        // 监听面板关闭请求（来自 HistoryViewController 选中行后）
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(closePopover),
            name: .closeHistoryPanel,
            object: nil
        )

        // 全局快捷键（带 fallback）
        GlobalHotKey.shared.onTrigger = { [weak self] in
            self?.togglePopover()
        }
        GlobalHotKey.shared.register()

        // 延迟更新 tooltip（等待注册完成）
        DispatchQueue.main.async { [weak self] in
            let combo = GlobalHotKey.shared.registeredCombo
            if !combo.isEmpty {
                self?.statusItem.button?.toolTip = "剪切板管理器 (\(combo))"
            }
        }
    }

    // MARK: - 状态栏图标

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "paperclip",
                accessibilityDescription: "Clipboard Manager"
            )
            button.image?.isTemplate = true
            button.target = self
            button.action = #selector(togglePopover)
            button.toolTip = "剪切板管理器"
        }
    }

    // MARK: - Popover

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 460, height: 480)
        popover.behavior = .transient
        popover.animates = true
        popover.appearance = NSAppearance(named: .vibrantDark)
        popover.contentViewController = HistoryViewController()
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(
                relativeTo: button.bounds,
                of: button,
                preferredEdge: .minY
            )
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    @objc private func closePopover() {
        if popover.isShown {
            popover.performClose(nil)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        GlobalHotKey.shared.unregister()
        NotificationCenter.default.removeObserver(self)
    }
}
