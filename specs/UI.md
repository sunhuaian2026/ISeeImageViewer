# UI 规范 — ISeeImageViewer
> 设计方向：Liquid Glass 沉浸感 · 内容优先 · 深色打底
> 参考：macOS Tahoe 26 Liquid Glass、Pixea、Viso、Apple HIG macOS
> 最后更新：2026-03

---

## 设计原则

- **内容优先**：UI 控件只在需要时出现，图片永远是主角
- **层次漂浮**：控件层（Toolbar / Sidebar / Inspector）用毛玻璃材质悬浮于内容层之上，两层有明确的景深感
- **彩色光晕**：用 `radial-gradient` 或图片主色在背景上制造环境光泄漏，让纯深色界面有温度
- **原生克制**：遵循 Apple HIG，SF Symbols + 系统字体，不造自定义控件
- **深色优先**：整体强制深色，减少对图片色彩的干扰

---

## 颜色

### 背景层（内容区）
```swift
// 主背景 — 不用纯黑，保留一点色温
Color(red: 0.07, green: 0.07, blue: 0.09)   // #121217  主背景
Color(red: 0.08, green: 0.08, blue: 0.11)   // #141419  网格区背景
```

### 控件层（毛玻璃，叠在背景上）
```swift
// Sidebar / Inspector / Toolbar 全部使用系统材质，不硬编码颜色
.background(.ultraThinMaterial)              // 主要控件层
.background(.regularMaterial)               // 较厚的面板（Inspector）
.environment(\.colorScheme, .dark)           // 强制材质走深色渲染
```

### 彩色环境光（Liquid Glass 关键细节）
```swift
// 在 ZStack 底层加一个模糊光晕，颜色从当前图片主色取样，或固定用品牌色
// 侧边栏顶部光晕示例：
RadialGradient(
    colors: [Color(red: 0.49, green: 0.42, blue: 1.0).opacity(0.18), .clear],
    center: .topLeading,
    startRadius: 0,
    endRadius: 300
)
// 看图界面光晕示例（右下角暖色）：
RadialGradient(
    colors: [Color(red: 0.2, green: 0.6, blue: 0.5).opacity(0.12), .clear],
    center: .bottomTrailing,
    startRadius: 0,
    endRadius: 400
)
// 规则：光晕 opacity 不超过 0.20，半径不超过窗口短边的 60%
```

### 强调色
```swift
Color.accentColor     // 系统强调色，跟随用户设置
// 选中态：accentColor 边框 2pt + accentColor.opacity(0.15) 背景
// 激活态按钮：accentColor.opacity(0.2) 背景 + accentColor 文字/图标
```

### 文字色
```swift
Color.primary          // 主要文字
Color.secondary        // 次要文字（文件名、数量）
Color.tertiaryLabel    // 辅助信息（时间、格式）
// 控件层文字因毛玻璃背景，对比度自动满足，无需额外处理
```

### 禁止
- 不用纯黑 `#000000`，不用纯白 `#ffffff` 作背景
- 不硬编码颜色值，用系统语义色或上方定义的常量
- 光晕不超过 2 个/视图，避免过度装饰

---

## 字体

全部使用 SF Pro（系统字体），支持 Dynamic Type，禁止硬编码字号。

```swift
.font(.headline)    // 文件夹名、标题
.font(.body)        // 文件名
.font(.callout)     // Toolbar 按钮文字
.font(.caption)     // 数量、格式等次要信息（badge、状态栏）
.font(.caption2)    // Inspector 标签（key 列）
```

---

## 间距（8pt Grid）

```swift
enum DS {
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }
}
```

---

## 圆角

```swift
// 控件层浮动卡片（Toolbar bubble、Badge）
let floatingCornerRadius: CGFloat = 12

// 缩略图
let thumbnailCornerRadius: CGFloat = 8    // 从 4 升到 8，与 Liquid Glass 圆角语言一致

// 侧边栏行选中态
let rowCornerRadius: CGFloat = 8

// Inspector 内预览图
let previewCornerRadius: CGFloat = 10

// 上限：非按钮元素圆角不超过 12pt
```

---

## 缩略图网格

```swift
enum DS {
    enum Thumbnail {
        static let defaultSize: CGFloat = 180   // 默认（UIRefresh 已更新）
        static let minSize: CGFloat = 80
        static let maxSize: CGFloat = 280
        static let spacing: CGFloat = 12        // UIRefresh 已更新
        static let cornerRadius: CGFloat = 8   // 升级，与 Liquid Glass 对齐
    }
}
```

**悬停行为**：
- 缩略图微放大：`scaleEffect(isHovered ? 1.03 : 1.0)`，`animation(.easeOut(duration: 0.15))`
- 悬停时图片下方出现文件名（单行截断），从底部淡入
- 悬停背景：`Color.white.opacity(0.06)` 圆角矩形

**选中态**：
- 描边：`2pt accentColor`
- 内部 overlay：`accentColor.opacity(0.12)`
- 右上角可选勾选标记（多选模式）

---

## 侧边栏

```swift
enum DS {
    enum Sidebar {
        static let width: CGFloat = 220
        static let minWidth: CGFloat = 180
        static let maxWidth: CGFloat = 300
        static let rowHeight: CGFloat = 36
        static let rowPaddingH: CGFloat = 8
        static let iconSize: CGFloat = 16
    }
}
```

**视觉处理**：
- 背景：`.ultraThinMaterial` + `.environment(\.colorScheme, .dark)`
- 顶部加 1 个彩色光晕（紫/蓝，opacity ≤ 0.18）
- 与主内容区分隔线：`Divider()`（系统自动适配材质）

**文件夹行**：
```swift
// 区块标题
.font(.caption)
.foregroundStyle(.tertiary)
.textCase(.uppercase)
.tracking(0.5)

// 选中行
RoundedRectangle(cornerRadius: 8)
    .fill(.ultraThinMaterial)              // 毛玻璃选中态
    .overlay(
        RoundedRectangle(cornerRadius: 8)
            .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
    )

// 图片数量 badge（每行右侧）
Text("\(count)")
    .font(.caption2)
    .foregroundStyle(.secondary)
    .padding(.horizontal, 6)
    .padding(.vertical, 2)
    .background(.ultraThinMaterial, in: Capsule())
```

---

## Toolbar（浮动气泡式）

**布局**：Toolbar 不贴边，以圆角胶囊/气泡形式浮在内容上方，对齐 Liquid Glass 风格。

```swift
// 容器
RoundedRectangle(cornerRadius: 12)
    .fill(.ultraThinMaterial)
    .overlay(
        RoundedRectangle(cornerRadius: 12)
            .stroke(Color.white.opacity(0.1), lineWidth: 1)
    )
    .shadow(color: .black.opacity(0.3), radius: 12, y: 6)

// 高度
let toolbarHeight: CGFloat = 44   // 比原 52pt 更紧凑，符合浮动气泡比例

// 按钮间距：8pt
// 分隔线：Divider().frame(height: 16)
```

**图标尺寸**：`20pt`（工具栏），`16pt`（侧边栏/菜单）

---

## 看图界面（ImageViewerView）

```swift
// 主背景
DS.Color.viewerBackground  // #121217，不加任何装饰

// 但在 ZStack 底层叠加 1-2 个环境光光晕（见颜色章节）

// 浮动控件卡片效果（图片容器）
.clipShape(RoundedRectangle(cornerRadius: 16))
.shadow(color: .black.opacity(0.5), radius: 24, y: 8)
.padding(12)

// 控件自动隐藏
// 鼠标静止 2s 后所有浮层控件 opacity → 0（easeInOut 0.25s）
// 鼠标移动立即恢复 opacity → 1
// 实现：onContinuousHover + Timer

// 底部 Filmstrip
// 高度 72pt（含上方渐变遮罩）
// 缩略图 56×56pt，当前项描边 2pt accentColor + scaleEffect(1.08)
// 背景：LinearGradient(transparent → .black.opacity(0.6))，不用材质
// 鼠标进入底部 80pt 区域时渐显，离开后 1.5s 渐隐
```

**缩放范围**：最小 10%，最大 1600%（双击切换 fit/100%）

---

## Inspector 面板

```swift
// 宽度：260pt 固定
// 背景：.regularMaterial + dark colorScheme
// 顶部：文件预览小图（圆角 10pt，高度 120pt）
// 内容：Form + Section + LabeledContent
//   - Section "文件"：文件名、尺寸、大小、修改日期
//   - Section "相机"（有 EXIF 才显示）：相机型号、镜头、光圈、快门、ISO
// key 列：.caption2 + .tertiary
// value 列：.caption + .primary
// 默认收起（columnVisibility = .doubleColumn）
// ⌘+I 切换显示
```

---

## 动画

```swift
enum DS {
    enum Animation {
        static let fast   = SwiftUI.Animation.easeInOut(duration: 0.15)
        static let normal = SwiftUI.Animation.easeInOut(duration: 0.2)
        static let slow   = SwiftUI.Animation.easeInOut(duration: 0.35)
    }
}

// 图片切换：DS.Animation.fast
// 控件显隐：DS.Animation.normal（含 Filmstrip）
// Zoom transition（matchedGeometryEffect）：DS.Animation.slow
// 缩略图 hover 放大：easeOut(0.15)

// 禁止在看图主界面用 .spring()，分散注意力
```

---

## 深浅色模式

App 支持深色 / 浅色 / 跟随系统三档切换（AppearanceMode），由 `AppState.appearanceMode` 驱动 `ISeeImageViewerApp` 的 `preferredColorScheme`。**QuickViewerOverlay 保留 `.preferredColorScheme(.dark)`，始终强制深色。**

### AdaptiveColor（颜色自适应方案）

背景层和交互色使用 `AdaptiveColor` 结构体，实现 `ShapeStyle.resolve(in:)`，从 `EnvironmentValues.colorScheme` 读取外观——可正确响应 SwiftUI per-view `preferredColorScheme` 覆盖：

```swift
struct AdaptiveColor: ShapeStyle, View {
    let light: SwiftUI.Color
    let dark: SwiftUI.Color

    func resolve(in environment: EnvironmentValues) -> some ShapeStyle {
        environment.colorScheme == .dark ? dark : light
    }
}
```

> ⚠️ 不要用 `NSColor(dynamicProvider:)`——该方案响应 NSWindow 级别的 NSAppearance，无法响应 per-view colorScheme 覆盖，会导致 QuickViewer 在浅色模式下颜色错误。

### 色票（自适应）

| 常量 | Light | Dark |
|------|-------|------|
| `DS.Color.appBackground` | `#F2F2F7` | `#121217` |
| `DS.Color.gridBackground` | `#EBEBF0` | `#141419` |
| `DS.Color.hoverOverlay` | `black.opacity(0.05)` | `white.opacity(0.06)` |
| `DS.Color.separatorColor` | `black.opacity(0.08)` | `white.opacity(0.08)` |
| `DS.Color.glowPrimary` | 不变（紫色） | 不变（紫色） |
| `DS.Color.glowSecondary` | 不变（青绿） | 不变（青绿） |

`glowPrimary` / `glowSecondary` 不需要自适应，保持 `SwiftUI.Color` 类型。

### 系统材质注意事项

`.ultraThinMaterial` / `.regularMaterial` 响应 NSWindow 级别的 NSAppearance，**不**响应 per-view `preferredColorScheme` 覆盖。QuickViewerOverlay 内所有材质已替换为明确深色半透明色（`Color(white: 0, opacity:)`）。其他视图（侧边栏、Inspector）使用系统材质时，外观跟随 `NSWindow.appearance`，行为正确。

---

## DesignSystem.swift 完整模板

```swift
import SwiftUI

enum DS {

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }

    enum Thumbnail {
        static let defaultSize: CGFloat = 180
        static let minSize: CGFloat = 80
        static let maxSize: CGFloat = 280
        static let spacing: CGFloat = 12
        static let cornerRadius: CGFloat = 8
    }

    enum Sidebar {
        static let width: CGFloat = 220
        static let minWidth: CGFloat = 180
        static let maxWidth: CGFloat = 300
        static let rowHeight: CGFloat = 36
        static let rowPaddingH: CGFloat = 8
        static let iconSize: CGFloat = 16
    }

    enum Viewer {
        static let filmstripHeight: CGFloat = 72
        static let filmstripThumbSize: CGFloat = 56
        static let cardCornerRadius: CGFloat = 16
        static let cardPadding: CGFloat = 12
    }

    enum Inspector {
        static let width: CGFloat = 260
        static let previewHeight: CGFloat = 120
        static let previewCornerRadius: CGFloat = 10
    }

    enum Toolbar {
        static let height: CGFloat = 44
        static let cornerRadius: CGFloat = 12
    }

    enum Anim {
        static let fast   = SwiftUI.Animation.easeInOut(duration: 0.15)
        static let normal = SwiftUI.Animation.easeInOut(duration: 0.2)
        static let slow   = SwiftUI.Animation.easeInOut(duration: 0.35)
    }

    enum Color {
        // 背景层
        static let appBackground   = SwiftUI.Color(red: 0.07, green: 0.07, blue: 0.09)
        static let gridBackground  = SwiftUI.Color(red: 0.08, green: 0.08, blue: 0.11)

        // 悬停/交互
        static let hoverOverlay    = SwiftUI.Color.white.opacity(0.06)
        static let separatorColor  = SwiftUI.Color.white.opacity(0.08)

        // 环境光（Liquid Glass 光晕）
        static let glowPrimary     = SwiftUI.Color(red: 0.49, green: 0.42, blue: 1.0)   // 紫
        static let glowSecondary   = SwiftUI.Color(red: 0.2,  green: 0.6,  blue: 0.5)   // 青绿
    }
}
```

---

## 禁止项

- 不硬编码任何颜色值和字号，全部用 `DS.*` 常量或系统语义色
- 不用纯黑 `#000000` / 纯白 `#ffffff` 作背景
- 不在看图界面叠加超过 2 个光晕
- 不用 `.spring()` 动画在主看图界面
- 不使用非 SF Symbols 图标
- 圆角上限 12pt（浮动控件），看图卡片 16pt
- 光晕 opacity 上限 0.20

---

## 与其他 Spec 的关系

| Spec 文件 | 与本文档关系 |
|---|---|
| `UIRefresh.md` | 已完成的迭代任务，数值变更已合并入本文档，可归档 |
| `FolderBrowserView.md` | 布局结构定义，视觉细节以本文档为准 |
| `ImageViewerView.md` | 功能逻辑定义，Filmstrip/自动隐藏视觉以本文档为准 |
| `Inspector.md` | Inspector 功能逻辑，面板视觉以本文档为准 |
