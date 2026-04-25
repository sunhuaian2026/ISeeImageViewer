# QuickViewer Spec

## 当前进度：全部步骤已完成（commit 9018877）

## 目标

双击缩略图弹出全窗口沉浸式查看器，支持完整缩放、平移、导航体验。
替代现有「detail pane 内嵌查看器」方案。

---

## 架构

### ContentView 变更

```swift
// ZStack 替代当前 if/else 切换 detail
ZStack {
    NavigationSplitView {
        FolderSidebarView()
    } detail: {
        ImageGridView()   // 始终显示，不再切换
    }

    if folderStore.selectedImageIndex != nil {
        QuickViewerOverlay()
            .transition(.opacity)
            .animation(DS.Animation.normal, value: folderStore.selectedImageIndex)
    }
}
```

好处：
- 侧边栏状态完整保留，关闭查看器后网格原位恢复
- 覆盖层不受 NavigationSplitView 列宽限制，真正铺满窗口

---

## QuickViewerViewModel

```swift
enum ZoomMode {
    case fit        // 自适应窗口（默认）
    case oneToOne   // 原始像素 1:1
    case custom     // 用户手动缩放
}

@MainActor
class QuickViewerViewModel: ObservableObject {
    // 数据
    let images: [URL]
    @Published var currentIndex: Int
    @Published var currentNSImage: NSImage?

    // 缩放
    @Published var zoomMode: ZoomMode = .fit
    @Published var scale: CGFloat = 1.0       // 实际渲染倍率
    @Published var offset: CGSize = .zero     // 平移量

    // 辅助
    var baseScale: CGFloat = 1.0              // 手势基准
    var viewportSize: CGSize = .zero          // 由视图注入，用于计算 fit scale

    // 计算属性
    var progress: String          // "3 / 20"
    var zoomPercent: String       // "75%"
    var canGoBack: Bool
    var canGoForward: Bool
    var canPan: Bool              // scale > fitScale 时允许拖拽

    // 导航
    func goBack()
    func goForward()
    func goTo(index: Int)

    // 缩放
    func resetToFit()             // mode = .fit，scale = fitScale，offset = .zero
    func resetToOneToOne()        // mode = .oneToOne，scale = 1.0，offset = .zero
    func zoomIn()                 // scale *= 1.25，mode = .custom，clamp
    func zoomOut()                // scale /= 1.25，mode = .custom，clamp
    func setScale(_ s: CGFloat, anchor: CGPoint, viewSize: CGSize) // 滚轮缩放，以光标为中心

    // 内部
    private func fitScale(for image: NSImage, in viewport: CGSize) -> CGFloat
    private func clampOffset()    // 防止拖出边界
    private func loadCurrentImage()
}
```

**fitScale 计算**（Preview.app + Quick Look 混合策略，commit 4f9fb18 修复）：
```swift
let fit = min(viewport.w / image.w, viewport.h / image.h)
return fit >= DS.Viewer.nativeScale ? DS.Viewer.nativeScale : fit * DS.Viewer.fitPadding
// DS.Viewer.nativeScale = 1.0（1:1 原生像素 sentinel）
// DS.Viewer.fitPadding  = 0.9（大图 fit 的窗口占比）
// 图 ≤ 窗口：保 1:1 原生像素（不上采样，小图不拉伸变糊）
// 图 >  窗口：缩到窗口 90% 占比，四周留呼吸边
```

> **历史**：旧实现 `min(scaleW, scaleH, 1.0)` 和 `QuickViewerOverlay.imageLayer` 的 `.scaledToFit() + .scaleEffect(scale)` 双变换叠加，导致大图打开只占窗口 30-40%（双 fit 再乘一次 scale）。修复把 imageLayer 改用 `.frame(width: native * scale, height: native * scale)` 单一变换，scale 语义统一为"相对原生像素的倍率"。

---

## QuickViewerOverlay

### 布局结构

```
ZStack {
    DS.Color.viewerBackground.ignoresSafeArea()     // 深色背景

    ZoomScrollView(...)                              // 图片 + 缩放手势
        .frame(maxWidth: .infinity, maxHeight: .infinity)

    // 顶部状态栏（自动隐藏）
    VStack {
        TopBar
        Spacer()
    }

    // 导航按钮（自动隐藏）
    HStack {
        NavButton(← )
        Spacer()
        NavButton(→ )
    }

    // 底部工具栏（自动隐藏）
    VStack {
        Spacer()
        BottomToolbar     // 缩放控件
        Filmstrip         // 缩略图条（现有逻辑迁移）
    }
}
.preferredColorScheme(.dark)
```

### TopBar（自动隐藏）

```
[×]  filename.jpg          75%      3 / 20
```
- 左：关闭按钮（ESC 同效）
- 中：文件名（单行截断）
- 右：缩放比例 + 进度
- 高度：`DS.Viewer.toolbarHeight`（52pt）
- 背景：`.ultraThinMaterial`

### BottomToolbar（自动隐藏，在 Filmstrip 上方）

```
[适合窗口]  [1:1]  [－]  [75%]  [＋]  [全屏]
```
- 按钮尺寸：32×32，圆角 8，`.ultraThinMaterial` 背景
- 缩放比例点击可输入（选做，Phase 2）
- 高度：44pt

### Filmstrip（现有逻辑，迁移自 ImageViewerView）

- 高度：`DS.Viewer.filmstripHeight`（76pt）
- 懒加载，当前图片高亮 + 居中滚动

---

## ZoomScrollView（NSViewRepresentable）

负责：
- **滚轮缩放**（以光标位置为中心）
- **拖拽平移**（`canPan == scale > fitScale` 时启用，1:1 倍率：鼠标 1pt = 图 1pt）
  - `mouseDragged` 把 `event.deltaX / event.deltaY` 累加到 VM `panBy(deltaX:deltaY:)`
  - `event.deltaX/Y` 是自上次 event 的 **incremental** 位移（不是 cumulative），直接累加
  - y 不取反：`NSEvent.mouseDragged.deltaY` 是 device/screen 坐标系（y↓ 为正：鼠标向下拖 deltaY > 0），跟 SwiftUI `.offset` 同向，直接累加。早期实现误以为 deltaY 跟 AppKit view 坐标 y↑ 同向所以取反，结果鼠标向上→图向下（98573e9 之后由用户实测发现，方向修正后 commit 跟随补丁）
  - VM `panBy` 内部 `clampOffset()` 兜底边界，不漏白
  - 旧实现（第一版 fix 前）用 `dragStartOffset` 做"基准 + cumulative delta"，但 re-accumulate 是 NO-OP，导致 offset 永远 = `mouseDown 时 offset + 当前 event 的小 delta`，连续拖图像在小范围内跳变（用户感觉抖动 + 拖不动）
- **双击切换** Fit ↔ 1:1

```swift
struct ZoomScrollView: NSViewRepresentable {
    @ObservedObject var viewModel: QuickViewerViewModel

    // 内部 NSView 子类
    class ZoomView: NSView {
        override func scrollWheel(with event: NSEvent) {
            // deltaY → scale delta，以 event.locationInWindow 为锚点
        }
        override func mouseDown(with event: NSEvent) {
            if event.clickCount == 2 { /* toggle fit/1:1 */ }
        }
        // 拖拽：mouseDragged
    }
}
```

SwiftUI 手势层（捏合）同时叠加在图片上：
```swift
MagnificationGesture()
    .onChanged { value in viewModel.setScale(...) }
    .onEnded { _ in viewModel.baseScale = viewModel.scale }
```

---

## 自动隐藏逻辑

与现有 ImageViewerView 相同：
- `onContinuousHover` 鼠标移动 → 显示控件，重置 2s 计时器
- 鼠标离开 → 1s 后隐藏
- `DS.Animation.normal`（easeInOut 0.2s）淡入淡出

---

## 键盘快捷键

| 按键 | 行为 |
|------|------|
| `ESC` / `Space` | 关闭查看器 |
| `←` / `→` | 上一张 / 下一张 |
| `⌘0` | 适合窗口（Fit） |
| `⌘1` | 原始大小（1:1） |
| `⌘=` | 放大 25% |
| `⌘-` | 缩小 25% |
| `F` | 全屏切换（调用 FullScreen 模块，Phase 4） |

---

## 边界条件

| 场景 | 处理 |
|------|------|
| 图片比窗口小（小图） | fitScale ≤ 1.0，不放大，居中显示 |
| 缩放到最小/大继续操作 | clamp 到 DS.Viewer.minZoom / maxZoom，静默限制 |
| 拖拽超出图片边界 | `panBy` 内部调 `clampOffset()` 阻止图片拖离视口 |
| 切换图片时 | resetToFit()，offset = .zero |
| 图片加载中 | ProgressView 居中，加载完后 fade in |
| 图片列表为空 | 不显示覆盖层（selectedImageIndex 不会被设置）|
| 窗口 resize | viewportSize 更新，重算 fitScale，保持 fit 模式自适应 |

---

## 实现步骤

1. 新建 `QuickViewer/QuickViewerViewModel.swift`，实现 ZoomMode + 所有缩放/导航方法
2. 新建 `QuickViewer/ZoomScrollView.swift`，NSViewRepresentable 接入滚轮 + 双击 + 拖拽
3. 新建 `QuickViewer/QuickViewerOverlay.swift`，ZStack 布局（背景 + ZoomScrollView + TopBar + NavButtons + BottomToolbar + Filmstrip）
4. 重构 `ContentView.swift`：改为 ZStack，NavigationSplitView detail 始终显示 ImageGridView，覆盖层叠加在顶部
5. 迁移 Filmstrip 逻辑（从 ImageViewerView 移动到 QuickViewerOverlay）
6. 删除 `ImageViewerView.swift` + `ImageViewerViewModel.swift`（功能已被 QuickViewer 替代）
7. 编译验证，零错误零 warning
8. 对照本 spec 逐条检查
9. git commit「完成 QuickViewer」
10. 更新 Roadmap.md / CLAUDE.md
