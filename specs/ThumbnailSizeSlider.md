# ThumbnailSizeSlider Spec

## 当前进度：第 9 步已完成（全部完成）

---

## 目标

在 ImageGridView Toolbar 加入缩略图尺寸滑块，允许用户实时调整网格密度，调整结果持久化到 UserDefaults。满足用户在整理不同密度图库时的浏览习惯差异。

---

## 改动范围

| 文件 | 改动类型 |
|------|----------|
| `FolderBrowser/FolderStore.swift` | 新增 `thumbnailSize` 属性，UserDefaults 持久化 |
| `FolderBrowser/ImageGridView.swift` | Toolbar 新增 Slider，LazyVGrid columns 响应 `thumbnailSize` |

新增文件：无。

---

## 接口

### FolderStore.swift 新增

```swift
// 默认值与 DS.Thumbnail.defaultSize 对齐（180pt）
@Published var thumbnailSize: CGFloat = DS.Thumbnail.defaultSize {
    didSet {
        UserDefaults.standard.set(Double(thumbnailSize), forKey: "thumbnailSize")
    }
}

// init() 中恢复持久化值：
let saved = UserDefaults.standard.double(forKey: "thumbnailSize")
if saved >= Double(DS.Thumbnail.minSize) && saved <= Double(DS.Thumbnail.maxSize) {
    thumbnailSize = CGFloat(saved)
}
// saved == 0（首次启动无记录）时保持默认值，无需特殊处理
```

### ImageGridView.swift 变更

#### Toolbar 新增 Slider

```swift
// 放在排序 Menu 按钮左侧，同一 ToolbarItemGroup 内
ToolbarItem(placement: .automatic) {
    HStack(spacing: 6) {
        Image(systemName: "square.grid.3x3")
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
        Slider(
            value: $folderStore.thumbnailSize,
            in: DS.Thumbnail.minSize...DS.Thumbnail.maxSize,
            step: 10
        )
        .frame(width: 88)
        Image(systemName: "square.grid.2x2")
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
    }
    .help("调整缩略图大小")
}
```

#### LazyVGrid columns 响应 thumbnailSize

```swift
// 将原来固定的 columns 定义改为计算属性：
private var gridColumns: [GridItem] {
    [GridItem(.adaptive(
        minimum: folderStore.thumbnailSize,
        maximum: folderStore.thumbnailSize + 20
    ), spacing: DS.Thumbnail.spacing)]
}

// 在 LazyVGrid 中使用：
LazyVGrid(columns: gridColumns, spacing: DS.Thumbnail.spacing) { ... }
```

#### ThumbnailCell 尺寸跟随

```swift
// ThumbnailCell 的 frame 从硬编码改为接收参数：
// 原：.frame(width: 150, height: 150)
// 改：.frame(width: folderStore.thumbnailSize, height: folderStore.thumbnailSize)
// 并加过渡动画：
.animation(DS.Anim.fast, value: folderStore.thumbnailSize)
```

---

## DesignSystem 确认

`DS.Thumbnail` 现有常量已覆盖本功能所需范围，无需新增：

```swift
// 确认 DesignSystem.swift 中已有（如无则补充）：
enum Thumbnail {
    static let defaultSize: CGFloat = 180
    static let minSize:     CGFloat = 80
    static let maxSize:     CGFloat = 280
    static let spacing:     CGFloat = 12
    static let cornerRadius: CGFloat = 8
}
```

---

## 边界条件

| 场景 | 处理 |
|------|------|
| 首次启动无 UserDefaults 记录 | `saved == 0`，保持 `DS.Thumbnail.defaultSize`（180pt） |
| UserDefaults 中存储值超出合法范围 | `init()` 中范围检查，不合法则忽略，使用默认值 |
| 拖动滑块时实时重布局 | `LazyVGrid` 响应 `@Published thumbnailSize`，SwiftUI 自动 diff，性能可接受 |
| 图片列表为空时拖动滑块 | 网格无内容，滑块正常操作，不 crash |
| 切换文件夹后尺寸是否重置 | 不重置，`thumbnailSize` 是全局状态，跨文件夹保持 |
| 极小尺寸（80pt）下文件名截断 | 文件名 `lineLimit(1)` + `truncationMode(.middle)` 自然截断，已有实现无需改动 |
| 极大尺寸（280pt）下每行只有 2-3 张 | `adaptive` 列自动计算，列数减少，布局正常 |

---

## 实现步骤

1. 确认 `DesignSystem.swift` 中 `DS.Thumbnail.minSize / maxSize / defaultSize` 均已定义
2. `FolderStore.swift` 新增 `thumbnailSize` `@Published` 属性，`didSet` 写 UserDefaults，`init()` 恢复
3. `ImageGridView.swift` 将 `LazyVGrid` 的 `columns` 改为响应 `thumbnailSize` 的计算属性
4. `ThumbnailCell` 的 `frame` 从硬编码改为 `folderStore.thumbnailSize`，加 `.animation(DS.Anim.fast)`
5. Toolbar 新增 Slider，左右两侧加小/大网格图标作为视觉提示
6. `make build` 编译验证
7. 手动测试：拖动滑块确认网格实时响应；重启 App 确认尺寸已恢复；切换文件夹确认尺寸保持
8. 更新 `specs/Roadmap.md`
9. git commit「完成 ThumbnailSizeSlider」
