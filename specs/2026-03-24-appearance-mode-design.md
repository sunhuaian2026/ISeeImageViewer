# Appearance Mode — Design Spec

**项目**：ISeeImageViewer
**日期**：2026-03-24
**状态**：✅ 已完成

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

`AppState` 新增 `appearanceMode` 属性，写入时自动持久化到 UserDefaults，读取时从 UserDefaults 恢复，默认值为 `.system`。

注意：需要新增显式 `init()`，但 `isFullScreen` 和 `window` 有默认值，无需在 init 中显式赋值：

```swift
@Published var appearanceMode: AppearanceMode {
    didSet { UserDefaults.standard.set(appearanceMode.rawValue, forKey: "appearanceMode") }
}

// isFullScreen 默认 false，window 默认 nil，均无需在 init 中处理
init() {
    let raw = UserDefaults.standard.string(forKey: "appearanceMode") ?? "system"
    self.appearanceMode = AppearanceMode(rawValue: raw) ?? .system
}
```

### 2. 颜色系统（DesignSystem.swift）

> ⚠️ 实际实现与原设计不同。原计划使用 `NSColor(dynamicProvider:)` 方案，上线后发现该方案响应 NSWindow 级别的 NSAppearance，无法响应 SwiftUI per-view `preferredColorScheme` 覆盖，导致 QuickViewer 在浅色模式下颜色错误。已全面替换为以下方案。

新增 `AdaptiveColor` 结构体，实现 `ShapeStyle` 和 `View` 协议。`ShapeStyle.resolve(in:)` 从 `EnvironmentValues.colorScheme` 读取当前外观，可正确响应 per-view `preferredColorScheme` 覆盖：

```swift
struct AdaptiveColor: ShapeStyle, View {
    let light: SwiftUI.Color
    let dark: SwiftUI.Color

    func resolve(in environment: EnvironmentValues) -> some ShapeStyle {
        environment.colorScheme == .dark ? dark : light
    }

    var body: some View {
        _AdaptiveColorBody(light: light, dark: dark)
    }
}
```

`glowPrimary` / `glowSecondary` 不需要自适应，保持 `SwiftUI.Color` 类型不变。

`DS.Color.*` 改造（仅背景层和交互色需要双值，光晕色保持不变）：

| 色票 | Light | Dark |
|------|-------|------|
| `appBackground` | `#F2F2F7` | `#121217` |
| `gridBackground` | `#EBEBF0` | `#141419` |
| `hoverOverlay` | `black.opacity(0.05)` | `white.opacity(0.06)` |
| `separatorColor` | `black.opacity(0.08)` | `white.opacity(0.08)` |
| `glowPrimary` | 不变（紫色） | 不变（紫色） |
| `glowSecondary` | 不变（青绿） | 不变（青绿） |

### 3. 根视图（ISeeImageViewerApp.swift）

`.preferredColorScheme(.dark)` 实际位于 `ISeeImageViewerApp.swift`（`WindowGroup` 层），不在 `ContentView.swift`。

**移除**：`.preferredColorScheme(.dark)`

**新增**：动态 colorScheme 绑定（`appState` 在此文件中已是 `@StateObject`，可直接访问）：

```swift
ContentView()
    .environmentObject(bookmarkManager)
    .environmentObject(folderStore)
    .environmentObject(appState)
    .preferredColorScheme(
        appState.appearanceMode == .system ? nil :
        appState.appearanceMode == .dark   ? .dark : .light
    )
```

### 4. 内嵌预览（ImagePreviewView.swift）

`ImagePreviewView.swift` 有自己的 `.preferredColorScheme(.dark)`，需同步移除，使其跟随全局外观设置。

### 5. Toolbar 入口（ContentView.swift）

在现有 toolbar 中新增外观切换 Menu（与 SortFilter 同风格）：

```swift
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

注意：不使用 `Label(mode.label, systemImage: "")` 的空字符串写法，在部分 SDK 版本下会产生 warning 或异常图标。

### 6. QuickViewer（QuickViewerOverlay.swift）

`QuickViewerOverlay` 保留 `.preferredColorScheme(.dark)`，`DS.Color.*` 在其内部通过 `AdaptiveColor.resolve(in:)` 正确解析为 dark 值。

**实际改动**：所有系统材质（`.regularMaterial` / `.ultraThinMaterial`）已替换为明确的深色半透明色（`Color(white:0, opacity:)`）。原因：系统材质响应 NSWindow 级别的 NSAppearance，当全局为浅色模式时，QuickViewer 内的材质仍渲染为浅色，导致白色图标不可见。由于 QuickViewer 永远深色，不需要材质的自适应能力，直接使用明确深色更可靠。

---

## 数据流

```
UserDefaults
    ↑↓
AppState.appearanceMode   (@Published, @StateObject in App)
    ↓
ISeeImageViewerApp (.preferredColorScheme 动态绑定)
    ↓
所有子视图（自动继承，包括 ContentView / ImagePreviewView 等）
    ↓
DS.Color.* (AdaptiveColor.resolve(in:) 从 EnvironmentValues 读取 colorScheme)

QuickViewerOverlay → .preferredColorScheme(.dark) 独立，不受影响
                   → DS.Color.* 在此上下文中始终解析为 dark 值
```

---

## 边界条件

| 场景 | 处理方式 |
|------|---------|
| 首次启动无 UserDefaults 记录 | 默认 `.system`，行为与系统一致 |
| QuickViewer 打开时切换外观 | 无影响，QuickViewer 强制深色独立 |
| 全屏模式下切换外观 | `preferredColorScheme` 实时生效，无需额外处理 |
| 系统材质（`.ultraThinMaterial` 等） | ⚠️ 响应 NSWindow 级别 NSAppearance，不响应 per-view colorScheme 覆盖。QuickViewer 内已全部替换为明确深色半透明色 |
| 光晕在浅色模式下 | 固定色 + 低 opacity，浅色背景下自然柔和，可接受 |
| 移除 QuickViewerOverlay 的强制深色 | 会导致 DS.Color.* 在其内部解析为 light 值，破坏看图界面，不可移除 |

---

## 涉及文件

| 文件 | 变更类型 |
|------|---------|
| `ISeeImageViewer/FullScreen/AppState.swift` | 新增 `AppearanceMode` 枚举 + `appearanceMode` 属性 + `init()` |
| `ISeeImageViewer/DesignSystem.swift` | 新增 `AdaptiveColor(ShapeStyle, View)`，更新 `DS.Color.*` 四个色票 |
| `ISeeImageViewer/ISeeImageViewerApp.swift` | 移除强制深色，新增动态 colorScheme 绑定 |
| `ISeeImageViewer/ImageViewer/ImagePreviewView.swift` | 移除 `.preferredColorScheme(.dark)` |
| `ISeeImageViewer/ContentView.swift` | 新增外观切换 Toolbar Menu |
| `ISeeImageViewer/QuickViewer/QuickViewerOverlay.swift` | 材质替换为明确深色半透明色 |

---

## 不在本次范围内

- Inspector 面板的外观适配（系统材质已自动处理）
- 图片主色提取驱动光晕色（独立功能）
- 其他设置项（字体大小、缩略图尺寸等）
