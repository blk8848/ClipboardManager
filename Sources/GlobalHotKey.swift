import Carbon

/// 全局快捷键管理器 — 支持多组合 fallback 注册
final class GlobalHotKey {

    static let shared = GlobalHotKey()

    /// 快捷键触发回调
    var onTrigger: (() -> Void)?

    /// 实际注册成功的快捷键描述（如 "⌘⌥V"）
    private(set) var registeredCombo: String = ""

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var hotKeyID = EventHotKeyID()

    // MARK: - 候选快捷键列表（按优先级）

    private struct Candidate {
        let key: Int
        let modifiers: UInt32
        let label: String
    }

    /// 依次尝试注册，直到成功
    private var candidates: [Candidate] {
        [
            Candidate(key: kVK_ANSI_V, modifiers: UInt32(cmdKey | optionKey), label: "⌘⌥V"),
            Candidate(key: kVK_ANSI_V, modifiers: UInt32(cmdKey | shiftKey),  label: "⌘⇧V"),
            Candidate(key: kVK_ANSI_X, modifiers: UInt32(cmdKey | shiftKey),  label: "⌘⇧X"),
            Candidate(key: kVK_ANSI_K, modifiers: UInt32(cmdKey | shiftKey),  label: "⌘⇧K"),
        ]
    }

    private init() {}

    // MARK: - 注册

    func register() {
        // 先装事件处理器（仅一次）
        installHandler()

        // 遍历候选快捷键
        for (idx, c) in candidates.enumerated() {
            if tryRegister(key: c.key, modifiers: c.modifiers, id: UInt32(idx + 1)) {
                registeredCombo = c.label
                print("✅ 快捷键已注册: \(c.label)")
                return
            } else {
                print("⚠️ \(c.label) 已被占用，尝试下一个...")
            }
        }

        print("❌ 所有快捷键均注册失败，请关闭冲突应用后重启本程序")
    }

    private func tryRegister(key: Int, modifiers: UInt32, id: UInt32) -> Bool {
        hotKeyID.signature = 0x434D4456  // 'CMDV'
        hotKeyID.id = id

        let status = RegisterEventHotKey(
            UInt32(key),
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        return status == noErr
    }

    private func installHandler() {
        guard handlerRef == nil else { return }

        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, _, userData) -> OSStatus in
                guard let ptr = userData else { return -1 }
                let hotKey = Unmanaged<GlobalHotKey>.fromOpaque(ptr).takeUnretainedValue()
                DispatchQueue.main.async {
                    hotKey.onTrigger?()
                }
                return noErr
            },
            1,
            &eventSpec,
            selfPtr,
            &handlerRef
        )
    }

    // MARK: - 注销

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let ref = handlerRef {
            RemoveEventHandler(ref)
            handlerRef = nil
        }
    }
}
