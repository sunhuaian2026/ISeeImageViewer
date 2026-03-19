# FullScreen Spec

## 当前进度：第 0 步已完成（未开始）

---

## 目标

进入图片查看器时可切换全屏模式，提供沉浸式看图体验。

---

## 方案

使用 AppKit `NSWindow.toggleFullScreen(_:)` 而非 SwiftUI `.fullScreenCover`。

原因：
- `.fullScreenCover` 会新建独立 Window，丢失当前 NavigationSplitView 状态
- `NSWindow.toggleFullScreen` 是系统级全屏，与 macOS 绿色按钮行为一致
- 全屏时 toolbar/sidebar 可选择性隐藏

---

## 接口

### WindowAccessor（NSViewRepresentable 工具）

```swift
struct WindowAccessor: NSViewRepresentable {
    let onWindow: (NSWindow) -> Void
    // makeNSView 时通过 view.window 拿到 NSWindow
    // 挂在 ContentView 上，拿到 window 引用后存入 AppState
}
```

### AppState（新增，全局 ObservableObject）

```swift
@MainActor
class AppState: ObservableObject {
    @Published var isFullScreen = false
    var window: NSWindow?

    func enterFullScreen() {
        window?.toggleFullScreen(nil)
    }
    func exitFullScreen() {
        guard isFullScreen else { return }
        window?.toggleFullScreen(nil)
    }
}
```

### 全屏触发时机

1. 用户双击缩略图进入查看器时：**不**自动全屏（用户主动触发）
2. 用户按 `F` 键 或 点击 toolbar `arrow.up.left.and.arrow.down.right` 按钮切换全屏
3. 退出查看器（ESC/关闭按钮）时：若当前全屏则先退出全屏，再回到网格

### NSWindowDelegate 监听

```swift
// 监听 windowDidEnterFullScreen / windowDidExitFullScreen
// 同步更新 AppState.isFullScreen
```

---

## UI 变化

| 状态 | Sidebar | Toolbar | Inspector |
|------|---------|---------|-----------|
| 正常 | 显示 | 显示 | 可切换 |
| 全屏 | 隐藏（系统自动） | 鼠标移到顶部时自动显示 | 可切换 |

---

## 边界条件

| 场景 | 处理 |
|------|------|
| 全屏时按 ESC | 先退出查看器，不退出全屏（ESC 语义是关闭查看器） |
| 全屏时按 F | 退出全屏，保持在查看器 |
| 窗口关闭时处于全屏 | 系统自动处理，无需额外逻辑 |
| 多显示器 | NSWindow.toggleFullScreen 在当前显示器全屏，系统行为 |
| Space 在全屏时退出查看器 | 先退出查看器，保持全屏状态（全屏不自动退出） |

---

## 实现步骤

1. 新建 `AppState.swift`，定义 `AppState` ObservableObject
2. 实现 `WindowAccessor`（NSViewRepresentable），获取 NSWindow 引用
3. 在 `ISeeImageViewerApp.swift` 注入 `AppState` 为 EnvironmentObject
4. ContentView 挂载 `WindowAccessor`，将 window 写入 `AppState`
5. 实现 `NSWindowDelegate` 监听全屏状态变化
6. ImageViewerView toolbar 加全屏按钮，绑定 `F` 快捷键
7. ESC 退出查看器逻辑：判断全屏，不联动退出全屏
8. 编译验证
9. git commit「完成 FullScreen」
