# ImageViewerView Spec

## 职责

全屏查看单张图片，支持：
- 翻页（上一张/下一张）
- 缩放（0.5x～5x，双指捏合）
- 键盘快捷键（← → ESC）
- 进度显示（如 "3 / 20"）

## ImageViewerViewModel

```swift
@MainActor
class ImageViewerViewModel: ObservableObject {
    @Published var currentIndex: Int
    @Published var scale: CGFloat = 1.0
    @Published var offset: CGSize = .zero
    @Published var currentNSImage: NSImage?
    var baseScale: CGFloat = 1.0
    let images: [URL]

    var progress: String   // "3 / 20"
    var canGoBack: Bool
    var canGoForward: Bool

    func goBack()
    func goForward()
    func resetZoom()
}
```

- 图片加载：`NSImage(contentsOf:)` 在 `Task.detached` 后台线程执行
- 切换图片时重置缩放（scale=1, offset=.zero）

## ImageViewerView

- 黑色全屏背景
- 图片居中，`.resizable().scaledToFit()`
- `MagnificationGesture` 缩放（范围 0.5x～5x）
- 左右按钮半透明浮层（disabled 时隐藏/半透明）
- 右上角进度文字 `"3 / 20"`
- `.focusable()` + `.onKeyPress`：
  - `←`：goBack
  - `→`：goForward
  - `Escape`：onDismiss()
- `onAppear` 时主动获取键盘焦点

## 数据流

```
ContentView 发现 selectedImageIndex != nil
  → 创建 ImageViewerView(images:, startIndex:, onDismiss:)
  → ViewModel 加载图片
用户 ←/→ / 按钮 → ViewModel.currentIndex 变化 → 重新加载图片
用户 ESC → onDismiss() → folderStore.selectedImageIndex = nil → 回到 ImageGridView
```
