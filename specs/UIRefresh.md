# UIRefresh Spec（混合方案 A + B + C）

## 当前进度：第 0 步已完成（未开始）

---

## 目标

以 2025 macOS Liquid Glass 设计语言为基础，混合三个方案的精华：
- **方案 A**：精炼细节（自动隐藏控件、大缩略图、Toolbar 排序、文件夹 badge）
- **方案 B**：三栏布局（右侧可折叠 Inspector 面板，为 EXIF 功能预留）
- **方案 C**：沉浸体验（进入查看器的 zoom transition、底部 filmstrip）

---

## 改动范围

### 1. ContentView — 三栏布局

```
[Sidebar 文件夹] | [Detail 网格/查看器] | [Inspector 元信息]
```

- 使用 `NavigationSplitView` 三列（sidebar / content / detail）
- Inspector 列默认收起（`columnVisibility` 控制）
- `⌘+I` 快捷键 / toolbar `info.circle` 按钮切换 Inspector 显示
- Inspector 宽度：260pt 固定

### 2. FolderSidebarView — 细节优化

- 文件夹行末尾加图片数量 badge（灰色圆角标签，来自 FolderStore）
- FolderStore 新增 `imageCount: [URL: Int]` 字典，扫描完成后更新

### 3. ImageGridView — 大缩略图 + 动画入口

- 缩略图尺寸：150×150 → **180×180**，间距 8 → **12**
- 双击缩略图：使用 `.matchedGeometryEffect` 做 zoom transition 进入查看器（方案 C）
- 悬停时在缩略图下方显示文件名（单行截断）

### 4. ImageViewerView — 自动隐藏控件 + Filmstrip

**自动隐藏（方案 A）**：
- 导航按钮、关闭按钮、进度标签：鼠标静止 2s 后渐隐（opacity 0），移动时渐显
- 使用 `onContinuousHover` + `Timer` 实现

**底部 Filmstrip（方案 C）**：
- 横向滚动的小缩略图条，高度 64pt，显示当前文件夹全部图片
- 当前图片高亮（描边 + 轻微放大）
- 点击 filmstrip 缩略图切换当前图片
- 鼠标进入 viewer 底部区域时渐显，离开后 1.5s 渐隐

**Zoom Transition（方案 C）**：
- 进入查看器时，图片从缩略图位置放大到全尺寸（`matchedGeometryEffect`）
- 退出时反向缩小回格子

### 5. 新增 InspectorPlaceholderView

- Phase 1 先放占位内容（文件名、尺寸、修改日期）
- Phase 3 再补充完整 EXIF（Inspector.md 负责）
- 使用 `Form` + `LabeledContent` 布局

---

## 接口变更

### ContentView

```swift
struct ContentView: View {
    @State private var showInspector = false
    @State private var columnVisibility = NavigationSplitViewVisibility.doubleColumn
    // 三列 NavigationSplitView
}
```

### FolderStore（新增）

```swift
@Published var imageCountByFolder: [URL: Int] = [:]
// selectFolder 扫描完成后写入 imageCountByFolder[url] = images.count
```

### ImageGridView（新增 namespace）

```swift
@Namespace private var zoomNamespace
// ThumbnailCell 加 .matchedGeometryEffect(id: url, in: zoomNamespace)
// ImageViewerView 的图片容器加同样 id+namespace
```

### ImageViewerView（新增参数）

```swift
// 新增 namespace 参数，用于 zoom transition
init(images: [URL], startIndex: Int, namespace: Namespace.ID, onDismiss: @escaping () -> Void)
```

---

## 边界条件

| 场景 | 处理 |
|------|------|
| Inspector 面板宽度在小窗口下挤压内容区 | `NavigationSplitView` 自动处理，最小宽度 680pt |
| Filmstrip 图片数量 > 500 | `LazyHStack` 懒加载，不预加载缩略图 |
| matchedGeometryEffect 在切换文件夹后 id 失效 | 退出查看器时 reset namespace |
| 自动隐藏时鼠标在按钮上 | hover 在按钮上时不触发隐藏计时器 |

---

## 实现步骤

1. FolderStore 增加 `imageCountByFolder`，扫描完后更新
2. FolderSidebarView 文件夹行加 badge
3. ImageGridView 缩略图尺寸 180×180，间距 12，悬停显示文件名
4. ContentView 改为三列 NavigationSplitView，新增 InspectorPlaceholderView
5. ImageGridView + ImageViewerView 加 `matchedGeometryEffect` zoom transition
6. ImageViewerView 增加控件自动隐藏逻辑（Timer + opacity）
7. ImageViewerView 增加底部 Filmstrip
8. 编译验证，对照 spec 逐条检查
9. git commit「完成 UIRefresh」
