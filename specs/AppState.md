# AppState Spec

`AppState.swift` 是全局 ObservableObject，通过 `EnvironmentObject` 注入全 App，持有 NSWindow 引用、全屏状态和外观模式。

**当前进度：全部功能已完成（FullScreen: 0abcae6 / AppearanceMode: b4363e7）**

---

## AppState 完整接口

```swift
@MainActor
class AppState: ObservableObject {
    // 全屏
    @Published var isFullScreen = false
    var window: NSWindow?

    // 外观模式
    @Published var appearanceMode: AppearanceMode

    init()
    func toggleFullScreen()          // 进入/退出全屏（toggle）
    func exitFullScreenIfNeeded()    // 仅在全屏时退出
    func hideTrafficLights()         // 隐藏窗口左上角按钮（guard !isFullScreen）
    func showTrafficLights()         // 恢复按钮（无 isFullScreen guard，见 TrafficLightHide.md）
}

enum AppearanceMode: String, CaseIterable {
    case system = "system"
    case light  = "light"
    case dark   = "dark"

    var label: String { /* 跟随系统 / 浅色 / 深色 */ }
}
```

`appearanceMode` 通过 `didSet` 自动写入 UserDefaults（key: `"appearanceMode"`），`init()` 从 UserDefaults 恢复，默认值 `.system`。

---

## WindowAccessor

```swift
struct WindowAccessor: NSViewRepresentable {
    let onWindow: (NSWindow) -> Void
    // makeNSView 时通过 view.window 拿到 NSWindow，存入 AppState
}
```

挂在 `ContentView` 上，拿到 `NSWindow` 引用后写入 `AppState.window`，同时设置 `NSWindowDelegate` 监听全屏状态。

---

## 全屏

### 方案

使用 AppKit `NSWindow.toggleFullScreen(_:)`，而非 SwiftUI `.fullScreenCover`（后者会新建独立 Window，丢失 NavigationSplitView 状态）。

### 触发时机

- 用户按 `F` 键，或点击 QuickViewer BottomToolbar 的全屏按钮
- **QuickViewer 内 ESC/X/Space**：全屏时退出全屏（留在 QuickViewer），非全屏时关闭 QuickViewer

### NSWindowDelegate 监听

`windowDidEnterFullScreen` / `windowDidExitFullScreen` → 同步 `AppState.isFullScreen`

### UI 变化

| 状态 | Sidebar | Toolbar | Inspector |
|------|---------|---------|-----------|
| 正常 | 显示 | 显示 | 可切换 |
| 全屏 | 隐藏（系统自动） | 鼠标移到顶部时自动显示 | 可切换 |

### 边界条件

| 场景 | 处理 |
|------|------|
| QuickViewer 内全屏时按 ESC/X/Space | 退出全屏，保持在 QuickViewer |
| QuickViewer 内非全屏时按 ESC/X/Space | 关闭 QuickViewer |
| 全屏时按 F | 退出全屏，保持在查看器 |
| 多显示器 | NSWindow.toggleFullScreen 在当前显示器全屏，系统行为 |

---

## 外观模式（AppearanceMode）

### 数据流

```
UserDefaults
    ↑↓
AppState.appearanceMode   (@Published, @StateObject in ISeeImageViewerApp)
    ↓
ISeeImageViewerApp (.preferredColorScheme 动态绑定)
    ↓
所有子视图（自动继承 colorScheme）
    ↓
DS.Color.* (AdaptiveColor.resolve(in:) 从 EnvironmentValues 读取 colorScheme)

QuickViewerOverlay → .preferredColorScheme(.dark) 独立，始终深色
```

### 根视图绑定（ISeeImageViewerApp.swift）

```swift
ContentView()
    .environmentObject(appState)
    .preferredColorScheme(
        appState.appearanceMode == .system ? nil :
        appState.appearanceMode == .dark   ? .dark : .light
    )
```

### Toolbar 入口（ContentView.swift）

```swift
ToolbarItem(placement: .automatic) {
    Menu {
        ForEach(AppearanceMode.allCases, id: \.self) { mode in
            Button { appState.appearanceMode = mode } label: {
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

### 边界条件

| 场景 | 处理 |
|------|------|
| 首次启动无 UserDefaults 记录 | 默认 `.system`，行为与系统一致 |
| QuickViewer 打开时切换外观 | 无影响，QuickViewer 强制深色独立 |
| 全屏模式下切换外观 | `preferredColorScheme` 实时生效 |
| 系统材质在 QuickViewer 内 | 已全部替换为明确深色半透明色，见 UI.md |
