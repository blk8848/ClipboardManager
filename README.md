# 📋 ClipboardManager

macOS 状态栏剪切板管理工具，原生 Swift + AppKit 开发。

## 功能

- **自动记录剪切板历史** — 后台每 0.5 秒轮询 `NSPasteboard`，变化时自动去重保存
- **全局快捷键弹出面板** — 默认 `⌘⌥V`，带四级 fallback 防冲突；面板位于状态栏下方
- **单击即复制** — 选中历史条目自动复制到剪切板，面板随之关闭
- **磨砂半透明面板** — `NSVisualEffectView` 原生模糊效果，圆角暗色风格
- **历史持久化** — 最多 50 条，存于 `~/Library/Application Support/ClipboardManager/history.json`

## 预览

```
┌──────────────────────────────────────┐
│  状态栏 📎 图标  ← 点击或 ⌘⌥V 弹出   │
│                                      │
│  ┌────────────────────────────┐      │
│  │  17:40:12 │ Hello World    │      │
│  │  17:39:58 │ https://...    │      │
│  │  17:39:02 │ import Swift   │      │
│  │  ...                       │      │
│  └────────────────────────────┘      │
│        磨砂半透明 · 右下弹出          │
└──────────────────────────────────────┘
```

## 快速开始

```bash
# 编译
make build

# 运行
make run

# 清理
make clean
```

首次运行可能需要授予 **辅助功能权限**（系统设置 → 隐私与安全性 → 辅助功能），用于全局快捷键。

## 快捷键

注册顺序（自动 fallback 到第一个可用组合）：

| 优先级 | 快捷键 | 说明 |
|:---:|--------|------|
| 1 | **⌘⌥V** | 首选，几乎无冲突 |
| 2 | ⌘⇧V | 可能与「粘贴并匹配样式」冲突 |
| 3 | ⌘⇧X | 备选 |
| 4 | ⌘⇧K | 兜底 |

## 项目结构

```
cmd_c_v/
├── Sources/
│   ├── main.swift                    # 入口
│   ├── AppDelegate.swift            # 状态栏、Popover 管理
│   ├── ClipboardStore.swift         # 剪切板轮询、去重、持久化
│   ├── HistoryViewController.swift  # 历史列表面板（NSTableView）
│   └── GlobalHotKey.swift           # Carbon 全局快捷键
├── Resources/
│   ├── Info.plist                   # 应用配置（LSUIElement 隐藏 Dock 图标）
│   └── AppIcon.icns                 # 应用图标
├── gen_icon.py                      # 图标生成脚本
├── Makefile                         # 编译 & 打包
└── README.md
```

## 技术栈

| 模块 | 技术 |
|------|------|
| UI 框架 | AppKit / Cocoa |
| 剪切板监听 | `NSPasteboard.general.changeCount` |
| 全局快捷键 | Carbon `RegisterEventHotKey` |
| 半透明面板 | `NSVisualEffectView` (.behindWindow) |
| 持久化 | `JSONEncoder` / `JSONDecoder` |
| 编译 | `swiftc` + Makefile |

## 系统要求

- macOS 12.0+
- Swift 5.7+

## 生成图标

图标为靛蓝→紫渐变圆角矩形 + 白色剪切板 + 层叠历史效果 + 小时钟徽章。

```bash
pip3 install pillow
python3 gen_icon.py
```
