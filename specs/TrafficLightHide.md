# TrafficLightHide Spec

## 当前进度：全部步骤已完成

---

## 目标

进入 QuickViewer 时隐藏窗口左上角的 Traffic Light 按钮（关闭 / 最小化 / 缩放），退出时恢复。让全窗口看图模式下窗口变成纯粹的画布，消除系统 UI 对图片的视觉干扰。

---

## 改动范围

| 文件 | 改动类型 |
|------|----------|
| `FullScreen/AppState.swift` | 新增两个方法 |
| `QuickViewer/QuickViewerOverlay.swift` | 新增 `.onAppear` / `.onDisappear` 调用 |

新增文件：无。

---

## 接口

### AppState.swift 新增

```swift
// 隐藏 Traffic Light（进入 QuickViewer 时调用）
func hideTrafficLights() {
    guard !isFullScreen else { return }   // 全屏下系统已隐藏，无需操作
    [NSWindow.ButtonType.closeButton,
     .miniaturizeButton,
     .zoomButton].forEach {
        window?.standardWindowButton($0)?.isHidden = true
    }
}

// 恢复 Traffic Light（退出 QuickViewer 时调用）
func showTrafficLights() {
    guard !isFullScreen else { return }   // 全屏下保持系统行为，不干预
    [NSWindow.ButtonType.closeButton,
     .miniaturizeButton,
     .zoomButton].forEach {
        window?.standardWindowButton($0)?.isHidden = false
    }
}
```

### QuickViewerOverlay.swift 新增

```swift
// 在 QuickViewerOverlay 的最外层 View 上添加：
.onAppear  { appState.hideTrafficLights() }
.onDisappear { appState.showTrafficLights() }
```

---

## 边界条件

| 场景 | 处理 |
|------|------|
| 全屏状态下进入 QuickViewer | `guard !isFullScreen` 跳过，系统已隐藏 Traffic Light，不重复操作 |
| 全屏状态下退出 QuickViewer | `showTrafficLights()` 不加 `isFullScreen` guard，始终恢复 `isHidden = false`。全屏下系统靠 hover 显示按钮，但前提是 `isHidden == false`，若跳过恢复则按钮永久消失 |
| QuickViewer 打开时切换全屏（按 F） | 全屏进入后 Traffic Light 已被系统隐藏，状态一致，无需额外处理 |
| QuickViewer 打开时 App 失去焦点再恢复 | macOS 会在 App 重新激活时自动恢复 window button 状态，`.onAppear` 不会重复触发，无副作用 |
| `AppState.window` 为 nil（极端情况） | `window?.standardWindowButton` 用可选链，静默跳过，不 crash |
| 多窗口（若存在） | `AppState.window` 始终指向主窗口，只操作主窗口，符合预期 |

---

## 实现步骤

1. `AppState.swift` 新增 `hideTrafficLights()` 和 `showTrafficLights()` 两个方法
2. `QuickViewerOverlay.swift` 在最外层容器上添加 `.onAppear` / `.onDisappear`，注入 `@EnvironmentObject var appState: AppState`（若尚未注入）
3. `make build` 编译验证，零错误零警告
4. 手动测试：正常模式进入/退出 QuickViewer，确认按钮隐藏/恢复；全屏模式下进入/退出，确认无异常
5. 更新 `specs/Roadmap.md`：Bug Fix 记录 + 关键架构决策（AppState 新增方法说明）
6. git commit「完成 TrafficLightHide」
