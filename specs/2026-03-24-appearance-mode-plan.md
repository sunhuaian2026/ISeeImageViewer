# Appearance Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 ISeeImageViewer 加入浅色 / 深色 / 跟随系统三档外观切换，设置持久化，QuickViewer 保持强制深色。

**Architecture:** `AppearanceMode` 枚举和持久化逻辑扩展到现有 `AppState`；`DS.Color.*` 通过新增 `Color(light:dark:)` 扩展实现动态色；根视图 `ISeeImageViewerApp` 用 `@Published appearanceMode` 驱动 `preferredColorScheme`；Toolbar 新增三档 Menu 入口。

**Tech Stack:** SwiftUI, AppKit, UserDefaults, NSColor appearance API（macOS 12+）

**Spec:** `specs/2026-03-24-appearance-mode-design.md`

---

## 文件改动总览

| 文件 | 动作 | 说明 |
|------|------|------|
| `ISeeImageViewer/FullScreen/AppState.swift` | 修改 | 新增 `AppearanceMode` 枚举 + `appearanceMode` 属性 + `init()` |
| `ISeeImageViewer/DesignSystem.swift` | 修改 | 新增 `Color(light:dark:)` 扩展，更新四个 `DS.Color.*` 色票 |
| `ISeeImageViewer/ISeeImageViewerApp.swift` | 修改 | 移除强制深色，改为动态 `preferredColorScheme` |
| `ISeeImageViewer/ImageViewer/ImagePreviewView.swift` | 修改 | 移除 `.preferredColorScheme(.dark)`（第 105 行） |
| `ISeeImageViewer/ContentView.swift` | 修改 | 新增外观切换 Toolbar Menu |
| `ISeeImageViewer/QuickViewer/QuickViewerOverlay.swift` | **不改动** | 保留自身强制深色 |

> **构建验证**：每个 Task 完成后在 `ISeeImageViewer/` 目录执行 `make build`，确认零错误零警告再提交。

---

## Task 1：AppState — 新增 AppearanceMode

**Files:**
- Modify: `ISeeImageViewer/FullScreen/AppState.swift`

- [ ] **Step 1：用完整内容替换 AppState.swift**

```swift
//
//  AppState.swift
//  ISeeImageViewer
//

import AppKit
import Combine

enum AppearanceMode: String, CaseIterable {
    case system = "system"
    case light  = "light"
    case dark   = "dark"

    var label: String {
        switch self {
        case .system: return "跟随系统"
        case .light:  return "浅色"
        case .dark:   return "深色"
        }
    }
}

class AppState: ObservableObject {
    @Published var isFullScreen = false
    weak var window: NSWindow?

    @Published var appearanceMode: AppearanceMode {
        didSet {
            UserDefaults.standard.set(appearanceMode.rawValue, forKey: "appearanceMode")
        }
    }

    // isFullScreen 默认 false，window 默认 nil，无需显式赋值
    init() {
        let raw = UserDefaults.standard.string(forKey: "appearanceMode") ?? "system"
        self.appearanceMode = AppearanceMode(rawValue: raw) ?? .system
    }

    func toggleFullScreen() {
        window?.toggleFullScreen(nil)
    }

    func exitFullScreenIfNeeded() {
        guard isFullScreen else { return }
        window?.toggleFullScreen(nil)
    }
}
```

- [ ] **Step 2：构建验证**

```bash
cd ISeeImageViewer && make build 2>&1 | tail -3
```
期望输出：`** BUILD SUCCEEDED **`

- [ ] **Step 3：提交**

```bash
git add ISeeImageViewer/FullScreen/AppState.swift
git commit -m "完成 AppearanceMode 数据模型"
```

---

## Task 2：DesignSystem — Color(light:dark:) + 色票更新

**Files:**
- Modify: `ISeeImageViewer/DesignSystem.swift`

- [ ] **Step 1：在文件末尾（`enum DS` 闭合括号之后）新增 `Color` 扩展**

在 `DesignSystem.swift` 文件最后一行（`enum DS` 的闭合 `}` 之后）追加：

```swift
// MARK: - Adaptive Color Extension（macOS 12+）
// 若将来部署目标升级至 macOS 14+，可替换为 Apple 原生 Color.init(light:dark:)
extension SwiftUI.Color {
    init(light: SwiftUI.Color, dark: SwiftUI.Color) {
        self.init(NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(dark) : NSColor(light)
        })
    }
}
```

- [ ] **Step 2：将 `DS.Color` 块替换为自适应版本**

将现有 `enum Color { ... }` 整块替换为：

```swift
// MARK: - Color

enum Color {
    // 背景层（light / dark 双值）
    static let appBackground  = SwiftUI.Color(
        light: SwiftUI.Color(red: 0.95, green: 0.95, blue: 0.97),  // #F2F2F7
        dark:  SwiftUI.Color(red: 0.07, green: 0.07, blue: 0.09)   // #121217
    )
    static let gridBackground = SwiftUI.Color(
        light: SwiftUI.Color(red: 0.92, green: 0.92, blue: 0.94),  // #EBEBF0
        dark:  SwiftUI.Color(red: 0.08, green: 0.08, blue: 0.11)   // #141419
    )

    // 悬停/交互（light / dark 双值）
    static let hoverOverlay   = SwiftUI.Color(
        light: SwiftUI.Color.black.opacity(0.05),
        dark:  SwiftUI.Color.white.opacity(0.06)
    )
    static let separatorColor = SwiftUI.Color(
        light: SwiftUI.Color.black.opacity(0.08),
        dark:  SwiftUI.Color.white.opacity(0.08)
    )

    // 环境光（Liquid Glass 光晕，两种模式均适用，不变）
    static let glowPrimary    = SwiftUI.Color(red: 0.49, green: 0.42, blue: 1.0)  // 紫
    static let glowSecondary  = SwiftUI.Color(red: 0.2,  green: 0.6,  blue: 0.5)  // 青绿
}
```

- [ ] **Step 3：构建验证**

```bash
make build 2>&1 | tail -3
```
期望输出：`** BUILD SUCCEEDED **`

- [ ] **Step 4：提交**

```bash
git add ISeeImageViewer/DesignSystem.swift
git commit -m "完成 DesignSystem 自适应颜色"
```

---

## Task 3：ISeeImageViewerApp — 动态 colorScheme 绑定

**Files:**
- Modify: `ISeeImageViewer/ISeeImageViewerApp.swift`

- [ ] **Step 1：将 `.preferredColorScheme(.dark)` 替换为动态绑定**

找到第 30 行：
```swift
.preferredColorScheme(.dark)
```

替换为：
```swift
.preferredColorScheme(
    appState.appearanceMode == .system ? nil :
    appState.appearanceMode == .dark   ? .dark : .light
)
```

- [ ] **Step 2：构建验证**

```bash
make build 2>&1 | tail -3
```
期望输出：`** BUILD SUCCEEDED **`

- [ ] **Step 3：提交**

```bash
git add ISeeImageViewer/ISeeImageViewerApp.swift
git commit -m "完成 AppearanceMode 根视图绑定"
```

---

## Task 4：ImagePreviewView — 移除强制深色

**Files:**
- Modify: `ISeeImageViewer/ImageViewer/ImagePreviewView.swift`

- [ ] **Step 1：删除第 105 行的强制深色修饰符**

找到：
```swift
.preferredColorScheme(.dark)
```
（位于 `.navigationTitle(...)` 下方，`.onAppear` 上方）

直接删除该行。

- [ ] **Step 2：构建验证**

```bash
make build 2>&1 | tail -3
```
期望输出：`** BUILD SUCCEEDED **`

- [ ] **Step 3：提交**

```bash
git add ISeeImageViewer/ImageViewer/ImagePreviewView.swift
git commit -m "完成 ImagePreviewView 移除强制深色"
```

---

## Task 5：ContentView — 外观切换 Toolbar Menu

**Files:**
- Modify: `ISeeImageViewer/ContentView.swift`

- [ ] **Step 1：在现有 Inspector `ToolbarItem` 闭合括号后插入外观切换 Menu**

找到以下精确文本（ContentView.swift 第 35–43 行）：
```swift
                ToolbarItem(placement: .automatic) {
                    Button {
                        showInspector.toggle()
                    } label: {
                        Label("信息", systemImage: showInspector ? DS.Icon.infoFilled : DS.Icon.info)
                    }
                    .keyboardShortcut("i", modifiers: .command)
                    .disabled(folderStore.selectedImageIndex == nil)
                }
```

替换为（在原 ToolbarItem 之后新增第二个 ToolbarItem）：
```swift
                ToolbarItem(placement: .automatic) {
                    Button {
                        showInspector.toggle()
                    } label: {
                        Label("信息", systemImage: showInspector ? DS.Icon.infoFilled : DS.Icon.info)
                    }
                    .keyboardShortcut("i", modifiers: .command)
                    .disabled(folderStore.selectedImageIndex == nil)
                }
                ToolbarItem(placement: .automatic) {
                    Menu {
                        ForEach(AppearanceMode.allCases, id: \.self) { mode in
                            Button {
                                appState.appearanceMode = mode
                            } label: {
                                if appState.appearanceMode == mode {
                                    Label(mode.label, systemImage: "checkmark")
                                } else {
                                    Text(mode.label)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "circle.lefthalf.filled")
                    }
                }
```

- [ ] **Step 2：构建验证**

```bash
make build 2>&1 | tail -3
```
期望输出：`** BUILD SUCCEEDED **`

- [ ] **Step 3：提交**

```bash
git add ISeeImageViewer/ContentView.swift
git commit -m "完成 AppearanceMode Toolbar 入口"
```

---

## Task 6：文档同步 + 最终验证

**Files:**
- Modify: `specs/Roadmap.md`
- Modify: `CLAUDE.md`

- [ ] **Step 1：在 `specs/Roadmap.md` 已完成模块表格中新增一行**

```markdown
| AppearanceMode | 2026-03-24-appearance-mode-design.md | <commit-hash> | 深/浅/系统三档外观切换，UserDefaults 持久化 |
```

将 `<commit-hash>` 替换为 Task 5 的实际 commit hash（`git log --oneline -1`）。

- [ ] **Step 2：在 `specs/Roadmap.md` 的「关键架构决策」新增一条**

```markdown
11. **AppearanceMode**：外观模式（system/light/dark）存在 `AppState.appearanceMode`，通过 `ISeeImageViewerApp` 的 `preferredColorScheme` 驱动全局外观。`DS.Color.*` 背景/交互色均为 `Color(light:dark:)` 双值。`QuickViewerOverlay` 保留自身 `.preferredColorScheme(.dark)`，使 `DS.Color.*` 在其内部始终解析为 dark 值，不受全局设置影响。
```

- [ ] **Step 3：在 `CLAUDE.md` 文件结构中新增 specs 条目**

在 specs 目录列表中补充：
```
│   └── 2026-03-24-appearance-mode-design.md  ← ✅ 已完成
```

- [ ] **Step 4：clean build 最终验证**

```bash
make clean && make build 2>&1 | tail -3
```
期望输出：`** BUILD SUCCEEDED **`

- [ ] **Step 5：最终提交 + 推送**

```bash
git add specs/Roadmap.md CLAUDE.md
git commit -m "完成 AppearanceMode 文档同步"
git push
```

---

## 手动验收检查（build 通过后）

在本地 MacBook 运行 `~/sync-isee.sh` 拉取并测试：

| 场景 | 期望结果 |
|------|---------|
| 首次启动 | Toolbar 显示 `circle.lefthalf.filled` 图标；外观跟随系统 |
| 选择「浅色」 | 主界面切换为浅色，QuickViewer 仍为深色 |
| 选择「深色」 | 主界面切换为深色 |
| 选择「跟随系统」 | 跟随 macOS 系统设置 |
| 退出重启 | 上次选择的外观模式被恢复 |
| 打开 QuickViewer | 无论全局外观，QuickViewer 始终深色 |
| 当前选中项 | Menu 中对应项显示 ✓ |
