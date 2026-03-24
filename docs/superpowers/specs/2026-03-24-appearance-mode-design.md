# Appearance Mode — Design Spec

**项目**：ISeeImageViewer
**日期**：2026-03-24
**状态**：待实现

---

## 目标

为 ISeeImageViewer 加入浅色模式支持，允许用户在深色 / 浅色 / 跟随系统三种外观之间切换，设置持久化。QuickViewer 看图界面保持强制深色不变。

---

## 架构

### 1. 数据模型（AppState.swift）

新增 `AppearanceMode` 枚举，定义在 `AppState.swift` 中：

```swift
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
```

`AppState` 新增 `appearanceMode` 属性，写入时自动持久化到 UserDefaults，读取时从 UserDefaults 恢复，默认值为 `.system`：

```swift
@Published var appearanceMode: AppearanceMode {
    didSet { UserDefaults.standard.set(appearanceMode.rawValue, forKey: "appearanceMode") }
}

init() {
    let raw = UserDefaults.standard.string(forKey: "appearanceMode") ?? "system"
    self.appearanceMode = AppearanceMode(rawValue: raw) ?? .system
}
```

### 2. 颜色系统（DesignSystem.swift）

新增 `Color(light:dark:)` 扩展，基于 `NSColor` appearance 动态返回对应色值：

```swift
extension SwiftUI.Color {
    init(light: SwiftUI.Color, dark: SwiftUI.Color) {
        self.init(NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(dark) : NSColor(light)
        })
    }
}
```

`DS.Color.*` 改造（仅背景层和交互色需要双值，光晕色保持不变）：

| 色票 | Light | Dark |
|------|-------|------|
| `appBackground` | `#F2F2F7` | `#121217` |
| `gridBackground` | `#EBEBF0` | `#141419` |
| `hoverOverlay` | `black.opacity(0.05)` | `white.opacity(0.06)` |
| `separatorColor` | `black.opacity(0.08)` | `white.opacity(0.08)` |
| `glowPrimary` | 不变（紫色） | 不变（紫色） |
| `glowSecondary` | 不变（青绿） | 不变（青绿） |

### 3. 根视图（ContentView.swift）

**移除**：`.preferredColorScheme(.dark)`

**新增**：动态 colorScheme 绑定

```swift
.preferredColorScheme(
    appState.appearanceMode == .system ? nil :
    appState.appearanceMode == .dark   ? .dark : .light
)
```

**新增 Toolbar Menu**（与 SortFilter 同风格，放在 toolbar 中）：

```swift
ToolbarItem(placement: .automatic) {
    Menu {
        ForEach(AppearanceMode.allCases, id: \.self) { mode in
            Button {
                appState.appearanceMode = mode
            } label: {
                Label(mode.label,
                      systemImage: appState.appearanceMode == mode ? "checkmark" : "")
            }
        }
    } label: {
        Image(systemName: "circle.lefthalf.filled")
    }
}
```

### 4. QuickViewer（QuickViewerOverlay.swift）

**不改动**。`QuickViewerOverlay` 保留自身的 `.preferredColorScheme(.dark)`，独立于全局外观设置，始终强制深色。

---

## 数据流

```
UserDefaults
    ↑↓
AppState.appearanceMode   (@Published)
    ↓
ContentView (.preferredColorScheme)
    ↓
所有子视图（自动继承）
    ↓
DS.Color.* (Color(light:dark:) 动态响应 colorScheme)

QuickViewerOverlay → .preferredColorScheme(.dark) 独立，不受影响
```

---

## 边界条件

| 场景 | 处理方式 |
|------|---------|
| 首次启动无 UserDefaults 记录 | 默认 `.system`，行为与系统一致 |
| QuickViewer 打开时切换外观 | 无影响，QuickViewer 强制深色独立 |
| 全屏模式下切换外观 | `preferredColorScheme` 实时生效，无需额外处理 |
| 系统材质（`.ultraThinMaterial` 等） | 自动跟随 `preferredColorScheme`，无需额外处理 |
| 光晕在浅色模式下 | 固定色 + 低 opacity，浅色背景下自然柔和，可接受 |

---

## 涉及文件

| 文件 | 变更类型 |
|------|---------|
| `ISeeImageViewer/FullScreen/AppState.swift` | 新增 `AppearanceMode` 枚举 + `appearanceMode` 属性 |
| `ISeeImageViewer/DesignSystem.swift` | 新增 `Color(light:dark:)` 扩展，更新 `DS.Color.*` 四个色票 |
| `ISeeImageViewer/ContentView.swift` | 移除强制深色，新增动态 colorScheme + Toolbar Menu |
| `ISeeImageViewer/QuickViewer/QuickViewerOverlay.swift` | 不改动 |

---

## 不在本次范围内

- Inspector 面板的外观适配（系统材质已自动处理）
- 图片主色提取驱动光晕色（独立功能）
- 其他设置项（字体大小、缩略图尺寸等）
