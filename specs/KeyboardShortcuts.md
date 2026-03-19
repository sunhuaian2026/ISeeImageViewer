# KeyboardShortcuts Spec

## 当前进度：第 0 步已完成（未开始）

---

## 目标

在现有 ← → ESC 的基础上，补全 macOS 原生看图体验所需的键盘快捷键。

---

## 快捷键一览

### ImageGridView（网格模式）

| 按键 | 行为 | 实现方式 |
|------|------|----------|
| `Space` | 进入图片查看器（查看选中图片） | `.onKeyPress(.space)` |
| `⌘+1/2/3` | 切换排序（名称/日期/大小） | `.keyboardShortcut` on Menu items |
| `↑↓←→` | 在网格中移动选中项 | `@State selectedIndex` + `.onKeyPress` |

> **注意**：网格的方向键导航需要引入 `selectedIndex`（当前高亮格子），与 `selectedImageIndex`（进入查看器）分离。

### ImageViewerView（查看器模式）

| 按键 | 行为 | 当前状态 |
|------|------|----------|
| `←` | 上一张 | ✅ 已有 |
| `→` | 下一张 | ✅ 已有 |
| `ESC` | 退出查看器 | ✅ 已有 |
| `Space` | 退出查看器（返回网格） | 新增 |
| `⌘+I` | 切换 Inspector 面板 | 新增（依赖 UIRefresh Phase 1） |
| `F` | 切换全屏 | 新增（依赖 FullScreen Phase 4） |
| `0` | 重置缩放（1:1） | 新增 |
| `⌘+0` | 适应窗口（scaledToFit） | 新增 |
| `⌘+=` | 放大 | 新增 |
| `⌘+-` | 缩小 | 新增 |

---

## 接口变更

### ImageGridView

```swift
@State private var highlightedIndex: Int? = nil  // 方向键导航高亮（不进入查看器）

// ThumbnailCell 新增 isHighlighted: Bool 参数
// 高亮时显示更明显的描边（区别于 hover 效果）
```

### ImageViewerView / ImageViewerViewModel

```swift
// ViewModel 新增
func resetZoom()        // scale = 1.0, offset = .zero, baseScale = 1.0
func zoomIn()           // scale = min(scale * 1.25, 5.0)
func zoomOut()          // scale = max(scale / 1.25, 0.5)
func fitToWindow()      // scale = 1.0（scaledToFit 已是默认，重置即可）
```

---

## 边界条件

| 场景 | 处理 |
|------|------|
| 网格为空时按 Space | 无操作 |
| 方向键在网格边缘 | 不越界，停在最后一格 |
| 缩放到最大/最小再继续 | 静默限制，不 crash |
| `⌘+I` 在 Inspector 未实现时 | Phase 1 完成后再启用此快捷键 |

---

## 实现步骤

1. ImageViewerViewModel 增加 `resetZoom()`、`zoomIn()`、`zoomOut()`
2. ImageViewerView 绑定 Space / 0 / ⌘+0 / ⌘+= / ⌘+- 快捷键
3. ImageGridView 引入 `highlightedIndex`，绑定 ↑↓←→ 导航和 Space 进入查看器
4. ThumbnailCell 支持 `isHighlighted` 高亮状态
5. 编译验证
6. git commit「完成 KeyboardShortcuts」
