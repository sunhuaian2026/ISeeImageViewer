# Prefetch Spec

## 当前进度：第 9 步已完成（全部完成）

---

## 目标

在 QuickViewer 中，切换到前/后一张图片时做到零延迟显示。当前图片加载完成后，立即在后台预加载相邻的 ±1 张图片并缓存，下次切换时直接从内存取用。

---

## 改动范围

| 文件 | 改动类型 |
|------|----------|
| `QuickViewer/QuickViewerViewModel.swift` | 新增 prefetch 缓存 + 预加载逻辑，修改图片加载路径 |

新增文件：无。

---

## 接口

### QuickViewerViewModel.swift 新增

```swift
// --- Prefetch Cache ---

// 缓存结构：index → CGImage（已解码，可直接渲染）
private var prefetchCache: [Int: CGImage] = [:]

// 正在进行中的预加载 Task，避免重复发起
private var prefetchTasks: [Int: Task<Void, Never>] = [:]

// 缓存最大条目数（当前图 ±2，共最多 5 张）
private let prefetchCacheLimit = 5

// --- 公开方法 ---

// 预加载当前 index 的相邻图片，在 goForward / goBack / 初始显示后调用
private func prefetchAdjacent() {
    let targets = [currentIndex - 1, currentIndex + 1]
        .filter { $0 >= 0 && $0 < images.count }
        .filter { prefetchCache[$0] == nil && prefetchTasks[$0] == nil }

    for idx in targets {
        prefetchTasks[idx] = Task.detached(priority: .background) { [weak self] in
            guard let self else { return }
            let url = await self.images[idx]
            guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return }
            await MainActor.run {
                self.prefetchCache[idx] = img
                self.prefetchTasks.removeValue(forKey: idx)
                self.evictCacheIfNeeded()
            }
        }
    }
}

// Cache eviction：只保留 currentIndex ±2 范围内的缓存
private func evictCacheIfNeeded() {
    let keepRange = (currentIndex - 2)...(currentIndex + 2)
    prefetchCache.keys
        .filter { !keepRange.contains($0) }
        .forEach { prefetchCache.removeValue(forKey: $0) }
}

// 切换文件夹或关闭 QuickViewer 时清空所有缓存和任务
func clearPrefetchCache() {
    prefetchTasks.values.forEach { $0.cancel() }
    prefetchTasks.removeAll()
    prefetchCache.removeAll()
}
```

### 图片加载路径修改

```swift
// 现有的 loadCurrentImage()（或等效方法）改为优先命中缓存：
func loadCurrentImage() {
    if let cached = prefetchCache[currentIndex] {
        // 直接使用缓存，不走磁盘
        self.currentImage = cached
        prefetchAdjacent()
        return
    }
    // cache miss：走原有加载逻辑（Task.detached + CGImageSource）
    // 加载完成后同样调用 prefetchAdjacent()
}
```

### 调用时机

```swift
// goForward() / goBack() 末尾加：
prefetchAdjacent()

// QuickViewerOverlay .onDisappear 或切换文件夹时：
viewModel.clearPrefetchCache()
```

---

## 内存估算

| 场景 | 缓存图片数 | 估算内存（以 4032×3024 JPEG 为例） |
|------|-----------|-----------------------------------|
| 正常浏览 | 最多 5 张（当前 ±2） | 5 × ~46MB ≈ 230MB（解码后 BGRA） |
| 图片较小（截图、设计稿） | 同上 | 5 × ~4MB ≈ 20MB |

实际 macOS 内存压力下系统会触发内存警告，可在 `didReceiveMemoryWarning`（或 `NSWorkspace` 低内存通知）中调用 `clearPrefetchCache()`。

---

## 边界条件

| 场景 | 处理 |
|------|------|
| 图片列表只有 1 张 | `targets` 过滤后为空，`prefetchAdjacent()` 无操作 |
| 当前在第一张/最后一张 | `filter { $0 >= 0 && $0 < images.count }` 自动排除越界 index |
| 同一 index 被重复触发预加载 | `prefetchTasks[$0] == nil` 检查防止重复发起 Task |
| 快速连续切换（连按方向键） | 旧 Task 不取消（后台安静完成），新 index 的 Task 另起，eviction 会清掉不再需要的缓存 |
| 预加载文件读取失败（文件被删除） | `guard let img` 静默跳过，不写入缓存，下次切到该图再走普通加载并展示错误态 |
| 切换文件夹 | `clearPrefetchCache()` 取消所有 Task 并清空缓存，防止旧文件夹图片残留 |
| 关闭 QuickViewer | `clearPrefetchCache()` 释放内存 |
| 系统内存紧张 | 监听低内存通知，调用 `clearPrefetchCache()` |

---

## 实现步骤

1. `QuickViewerViewModel.swift` 新增 `prefetchCache`、`prefetchTasks` 私有属性
2. 实现 `prefetchAdjacent()`、`evictCacheIfNeeded()`、`clearPrefetchCache()`
3. 修改现有图片加载方法，优先从 `prefetchCache` 取
4. 在 `goForward()` / `goBack()` 末尾调用 `prefetchAdjacent()`
5. 在 `QuickViewerOverlay.onDisappear` 和切换文件夹的回调中调用 `clearPrefetchCache()`
6. `make build` 编译验证
7. 手动测试：快速连按 ← →，确认无延迟；切换文件夹后再进入 QuickViewer，确认缓存已清空
8. 更新 `specs/Roadmap.md`
9. git commit「完成 Prefetch」
