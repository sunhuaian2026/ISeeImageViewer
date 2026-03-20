# UI 规范 — ISeeImageViewer
> 设计方向：极简、内容优先、深色友好
> 参考：Pixea、Viso、Apple HIG macOS

---

## 设计原则

- **内容优先**：UI 元素只在需要时出现，图片永远是主角
- **克制**：没有多余的装饰，间距和留白就是设计
- **原生**：遵循 Apple HIG，用户打开就觉得是 Mac 上该有的样子
- **深色优先**：看图场景默认深色背景，减少对图片的干扰

---

## 颜色

### 背景色
```swift
// 看图界面背景（深色，突出图片）
Color(red: 0.1, green: 0.1, blue: 0.1)   // #1A1A1A 主背景
Color(red: 0.15, green: 0.15, blue: 0.15) // #262626 侧边栏背景
Color(red: 0.2, green: 0.2, blue: 0.2)   // #333333 悬停/选中态
```

### 文字色
```swift
Color.primary          // 主要文字（自动适配深浅色）
Color.secondary        // 次要文字（文件名、数量等）
Color.tertiaryLabel    // 辅助信息（时间、格式等）
```

### 强调色
```swift
Color.accentColor      // 系统强调色（跟随用户系统设置）
// 选中态边框、激活状态等
```

### 语义色（直接用系统变量）
```swift
// 全部使用系统语义色，自动适配深浅色模式
Color(NSColor.windowBackgroundColor)
Color(NSColor.controlBackgroundColor)
Color(NSColor.separatorColor)
```

---

## 字体

遵循 Apple HIG，全部使用 SF Pro（系统字体），支持 Dynamic Type。

```swift
// 标题（文件夹名、相册名）
.font(.headline)           // SF Pro 13pt Medium（macOS）

// 正文（文件名）
.font(.body)               // SF Pro 13pt Regular

// 次要信息（数量、格式、尺寸）
.font(.caption)            // SF Pro 11pt Regular
.font(.caption2)           // SF Pro 10pt Regular

// 工具栏按钮文字
.font(.callout)            // SF Pro 12pt Regular
```

**禁止：**
- 不硬编码字体大小（`.font(.system(size: 14))`）
- 不使用非系统字体

---

## 间距（8pt Grid）

所有间距基于 8pt 网格系统：

```swift
// 间距常量（在 DesignSystem.swift 里统一定义）
enum Spacing {
    static let xs: CGFloat = 4    // 极小间距（图标与文字）
    static let sm: CGFloat = 8    // 小间距（列表行内部）
    static let md: CGFloat = 16   // 中间距（组件之间）
    static let lg: CGFloat = 24   // 大间距（区块之间）
    static let xl: CGFloat = 32   // 超大间距（页面边距）
}
```

**具体应用：**
- 侧边栏内边距：`16pt`
- 列表行高：`36pt`
- 列表行内图标与文字间距：`8pt`
- 缩略图网格间距：`8pt`
- 缩略图圆角：`4pt`
- 工具栏高度：`52pt`

---

## 缩略图网格

```swift
// 网格列宽
let thumbnailSize: CGFloat = 160   // 默认尺寸
let thumbnailMin: CGFloat = 80     // 最小（缩小时）
let thumbnailMax: CGFloat = 280    // 最大（放大时）

// 网格间距
let gridSpacing: CGFloat = 8

// 缩略图内圆角
let thumbnailCornerRadius: CGFloat = 4

// 选中态
// 边框：2pt accentColor
// 背景：accentColor.opacity(0.15)

// 悬停态
// 背景：Color.white.opacity(0.08)
```

---

## 侧边栏

```swift
// 宽度
let sidebarWidth: CGFloat = 220
let sidebarMinWidth: CGFloat = 180
let sidebarMaxWidth: CGFloat = 300

// 列表行
let rowHeight: CGFloat = 36
let rowPaddingH: CGFloat = 12
let rowIconSize: CGFloat = 16

// 区块标题（FOLDERS / ALBUMS）
.font(.caption)
.foregroundColor(.secondary)
// 字母全大写，tracking: 0.5
```

---

## 看图界面

```swift
// 背景
Color(red: 0.1, green: 0.1, blue: 0.1)  // 纯深色，不加任何装饰

// 工具栏（顶部）
// 默认隐藏，鼠标移到顶部 1 秒后显示
// 高度 52pt，半透明毛玻璃效果
.background(.ultraThinMaterial)

// 图片信息（底部）
// 默认隐藏，与工具栏同步显示/隐藏
// 显示：文件名、尺寸、格式、索引（3/128）

// 缩放
// 双击：切换 fit / 100%
// 双指捏合：自由缩放
// 最小缩放：10%，最大缩放：1600%
```

---

## 图标

全部使用 SF Symbols，不使用自定义图标。

```swift
// 常用图标
"folder"              // 文件夹
"photo.on.rectangle"  // 相册
"plus"                // 添加
"trash"               // 删除
"heart"               // 收藏
"magnifyingglass"     // 搜索
"arrow.left"          // 上一张
"arrow.right"         // 下一张
"arrow.up.left.and.arrow.down.right"  // 全屏

// 图标尺寸
// 工具栏：20pt
// 侧边栏列表：16pt
// 上下文菜单：16pt
```

---

## 动画

```swift
// 图片切换
.animation(.easeInOut(duration: 0.15), value: currentIndex)

// 工具栏显示/隐藏
.animation(.easeInOut(duration: 0.2), value: isToolbarVisible)

// 缩略图选中
.animation(.easeInOut(duration: 0.1), value: selectedItem)

// 禁止使用弹簧动画（.spring）在看图主界面，会让人分心
```

---

## 深浅色模式

```swift
// 看图界面：强制深色（图片在深色背景下效果最好）
.preferredColorScheme(.dark)

// 侧边栏 + 缩略图界面：跟随系统
// 不强制，让用户自己选
```

---

## 禁止项

- 不使用纯黑 `#000000` 作为背景（用 `#1A1A1A`）
- 不硬编码颜色值（用系统语义色或上面定义的常量）
- 不在看图界面加任何装饰性元素（边框、阴影、渐变）
- 不使用非 SF Symbols 的图标
- 不硬编码字体大小
- 圆角不超过 `8pt`（除按钮外）

---

## DesignSystem.swift 实现模板

在项目里新建 `DesignSystem.swift`，把上面的常量统一管理：

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
        static let defaultSize: CGFloat = 160
        static let minSize: CGFloat = 80
        static let maxSize: CGFloat = 280
        static let spacing: CGFloat = 8
        static let cornerRadius: CGFloat = 4
    }

    enum Sidebar {
        static let width: CGFloat = 220
        static let minWidth: CGFloat = 180
        static let maxWidth: CGFloat = 300
        static let rowHeight: CGFloat = 36
        static let iconSize: CGFloat = 16
    }

    enum Animation {
        static let fast = SwiftUI.Animation.easeInOut(duration: 0.15)
        static let normal = SwiftUI.Animation.easeInOut(duration: 0.2)
    }

    enum Color {
        static let viewerBackground = SwiftUI.Color(red: 0.1, green: 0.1, blue: 0.1)
        static let sidebarBackground = SwiftUI.Color(red: 0.15, green: 0.15, blue: 0.15)
        static let hoverBackground = SwiftUI.Color.white.opacity(0.08)
    }
}
```

使用方式：
```swift
.padding(DS.Spacing.md)
.frame(width: DS.Sidebar.width)
.background(DS.Color.viewerBackground)
```
