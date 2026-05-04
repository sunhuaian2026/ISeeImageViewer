# Glance（原 ISeeImageViewer）Roadmap

## 总体目标

打造一款 macOS 原生风格、界面精致的本地看图 app。

---

## 当前进度（2026-03-25）

**所有模块已完成，Bug 修复中**

---

## 已完成模块

| 模块 | Spec | 最后 Commit | 说明 |
|------|------|-------------|------|
| BookmarkManager | BookmarkManager.md | d88baa0 | Security Scoped Bookmark 持久化 |
| FolderStore | FolderStore.md | d88baa0 | 状态管理，含 imageCountByFolder |
| FolderSidebarView | FolderBrowserView.md | 0abde01 | 右键菜单、badge、文件夹列表 |
| ImageGridView | FolderBrowserView.md | 0abde01 | 160px 缩略图、文件名、双击进入 |
| ImageViewerView | ImageViewerView.md | 0abde01 | 自动隐藏控件、Filmstrip |
| DesignSystem | UI.md | 9230bc7 | DS.* 所有 UI 常量，全代码已对齐 |
| UIRefresh（Phase 1） | UIRefresh.md | 0abde01 | 三栏布局、Inspector 面板、过渡动画 |
| QuickViewer | QuickViewer.md | 9018877 | 沉浸式全窗口查看器，缩放/平移/导航，替代 ImageViewerView |
| KeyboardShortcuts | KeyboardShortcuts.md | 8885893 | 网格方向键导航、Space 进入查看器、缩放快捷键 |
| SortFilter | SortFilter.md | a2d1fc2 | 6 种排序，UserDefaults 持久化，Toolbar Menu |
| Inspector | Inspector.md | faf77ac | EXIF 元信息面板，相机/拍摄参数/GPS |
| FullScreen | AppState.md | 0abcae6 | NSWindow.toggleFullScreen，F 键切换，NSWindowDelegate 监听 |
| Liquid Glass UI | UI.md | 9a0cfde | DS.Anim / 新色系 / 毛玻璃控件 / 光晕 / 浮动气泡 Toolbar |
| 树形侧边栏 | FolderBrowserView.md | e8aec40 | FolderNode + discoverTree，List(children:) 展开/折叠 |
| AppearanceMode | AppState.md | b4363e7 | 深/浅/系统三档外观切换，UserDefaults 持久化 |
| ThumbnailSizeSlider | ThumbnailSizeSlider.md | 85ca376 | Toolbar 滑块调整缩略图尺寸（80~280pt），UserDefaults 持久化 |
| Prefetch | Prefetch.md | 849b4ae | QuickViewer ±1 图片预加载缓存，切换零延迟，CGImage 缓存 ±2 窗口 |
| AppIcon | — | fb6231c | Claude Design (Anthropic Labs) 出的 The Eye Mark · Cool Violet 方向：紫主底 + 青绿瞳孔光晕 + 白细描边，呼应 "I See" / 「一眼」双关 + 项目 DS.Color 紫青配色。master `assets/icon-1024.png` 透明背景方形画布；10 个 macOS 标准尺寸（16/32/128/256/512 各 1x+2x）由 sips 派生到 `Assets.xcassets/AppIcon.appiconset/`，Contents.json 配齐 filename 引用，xcodebuild 自动打包成 AppIcon.icns 进 .app/Contents/Resources |
| Rename | — | 8e6de41 | 应用全面重命名 ISeeImageViewer → **Glance · 一眼**（2026-04-27），三阶段 commit：6a7f870 phase 1 / 8e6de41 phase 2（主） / f46f8cd phase 3。phase 1 (6a7f870)：Bundle ID `uupt.ISeeImageViewer` → `com.sunhongjun.glance`，双语 Display Name 走 Apple i18n（zh-Hans 显示「一眼」/ en 显示「Glance」，via lproj/InfoPlist.strings）。phase 2 (8e6de41)：target / 源目录 / xcodeproj / App struct（`ISeeImageViewerApp` → `GlanceApp`）/ entitlements / Makefile / verify.sh / pre-push hook / 13 个干净 .swift header 全部统一。phase 3 (f46f8cd)：文档 + auto-memory + 全局 sunerpang CLAUDE.md 同步 [docs-only]。**未改**：项目根目录磁盘路径（保 auto-memory 路径连续）、GitHub 仓库名（择日单独操作）、git 历史 commit message（真实历史保留）、`docs/archive/*.md`（历史快照）、`Glance/ContentView.swift` & `Glance/FolderBrowser/ImageGridView.swift` 的旧 header（用户未提交 debug 代码占位中）。Bookmark / UserDefaults 因 Bundle ID 变更失效（已与用户确认重测可接受）|

---

## Bug Fix 记录

| Commit | 说明 |
|--------|------|
| 1234d68 | QuickViewer 顶部栏改为三个独立浮动气泡，去掉全宽背景遮挡问题 |
| 3ae95b3 | ImagePreviewView 文件名改用 `.navigationTitle`，消除与系统 toolbar 重叠 |
| fe82225 | 切换文件夹或取消图片选择时自动关闭 Inspector |
| f4a69da | 无图片选中时禁用 Inspector（ⓘ）按钮，防止空 Inspector 挤压网格布局 |
| 4162d7b | QuickViewer 打开时隐藏 window toolbar，修复侧边栏切换按钮点击无响应问题 |
| 2e32207 | DesignSystem 改用 `AdaptiveColor(ShapeStyle)`，修复 QuickViewer 浅色模式下颜色全错问题 |
| a8cc21f | FolderSidebarView 移除强制深色环境，侧边栏背景改为 `DS.Color.appBackground` 自适应 |
| ce79d8b | ImagePreviewView 所有硬编码 `.white` 改为 `Color.primary`，修复浅色模式导航箭头不可见问题 |
| e8e7c54 | FolderSidebarView 行背景加 `listRowBackground(DS.Color.appBackground)`，消除侧边栏与内容区色差 |
| 39b87f8 | QuickViewerOverlay 所有系统材质替换为明确深色半透明色，修复浅色模式图标不清晰问题 |
| aeca565 | 设置默认窗口尺寸 1280×800（首次启动生效，之后 macOS 记住用户调整值） |
| c6da6b5 | QuickViewer 工具栏：整体背景减淡至 opacity 0.28，移除按钮独立背景，突出图标 |
| 9d185fb | 侧边栏选中高亮：`listRowBackground` 改为 `accentColor.opacity(0.2)`，深浅模式下均正确显示 |
| decc675 | ImagePreviewView 缺少 `.focusable()` + `.focused()`，内嵌预览左右方向键无响应 |
| f00a584 | 进入 QuickViewer 时隐藏 Traffic Light 按钮，退出时恢复 |
| a064033 | TrafficLightHide：全屏中退出 QuickViewer 后 traffic light 不恢复；`showTrafficLights()` 的 `isFullScreen` guard 设计有误，去掉后修复 |
| a60008c | 列表页双击图片多出渲染框 + QuickViewer 关闭后错误回到预览页；双击时多余的 selectedImageIndex 赋值导致，删除后修复 |
| 45a61f1 | TrafficLightHide：hideTrafficLights() 挂在内层 ZStack.onAppear，与外层 onDisappear 不对称，移至同节点修复 |
| 6da903c | QuickViewer 全屏中 ESC/X 应退出全屏而非关闭 QuickViewer；加 isFullScreen 判断分支 |
| 6da903c | 列表页双击时单击 handler 同步触发设置 selectedImageIndex，导致 QuickViewer 关闭后落到预览页；onDoubleClick 中清除 selectedImageIndex 修复 |
| 0dd7241 | 预览页双击进入 QuickViewer 再关闭后方向键失效；QuickViewer 为 overlay 故 ImagePreviewView 从未 disappear，onAppear 不再触发；用 focusTrigger(UUID) 信号恢复焦点 |
| f5f992d | Slider 加 labelsHidden()，宽度从 88 改为 140；消除滑块下方多余 label 区域 |
| 9b2168d | 缩略图模糊：loadThumbnail 改为 size × backingScaleFactor，Retina 屏下正确分辨率 |
| 577c302 | 侧边栏选中行两侧浅色背景块：listRowBackground 选中时改 Color.clear，去掉 accentColor.opacity(0.2) 与系统选中高亮叠加。聚焦/失焦颜色差异（Accent Color vs 灰色）为 macOS 原生行为，符合系统规范，不做修改 |
| 577c302 | 返回缩略图页全部重载：mainContent 改 ZStack，ImageGridView 始终在层级里；预览模式下隐藏 Grid toolbar items |
| 5186338 | 排序菜单无响应：根本原因是 macOS SwiftUI `Menu { Button }` in ToolbarItem 的 NSMenuItem action 桥接失效；改为 `Picker(.menu)` + 独立方向切换 Button，完全绕开该路径 |
| 3c72730 | 排序后缩略图显示错误：`ForEach` 用 `id: \.element`（URL）但 VStack 上的 `.id(index)` 覆盖了视图身份为位置索引；排序后 SwiftUI 复用同位置视图，`@State thumbnail` 残留旧图；改为 `.id(url)` + `scrollTo(folderStore.images[next])` 修复 |
| 4560625 | 排序后预览图片随机错位（+n）：`applySortKey` 异步排序，Task 完成时 `ImagePreviewView.currentIndex`(@State) 仍指向旧位置；`onChange(of: images)` 按 URL 重新映射修复。标题栏显示文件夹名：ZStack 中两个 `.navigationTitle` 冲突，移除 `ImagePreviewView` 的，改由 `ImageGridView` 按 `selectedImageIndex` 动态决定 |
| 0330d6b | `applySortKey` 改为同步排序（`sortImagesSync`），彻底消除排序竞态。保留异步 `sortImages` 供 `scanImages` 使用 |
| e0c418d | 排序后缩略图索引错位（部分）：`applySortKey` 未重置 `selectedImageIndex`；ContentView 未在 images 变化时关闭 QuickViewer。修复：排序前置 `selectedImageIndex = nil`；`onChange(of: images)` 关闭 QuickViewer |
| 175e82a | 排序后预览索引错位（部分）：ImagePreviewView 的 `@State currentIndex` 在 `startIndex` 参数变化时不重置。修复：存储 `startIndex` 属性 + `onChange(of: startIndex)` 重置 `currentIndex` + `.id(idx)` 强制重建视图 |
| b67ab3c | 排序后点击缩略图预览错位（根因修复）：`ForEach(enumerated(), id: \.element)` 在 LazyVGrid 中排序后闭包捕获的 `index` 过期，点击时写入旧索引。修复：`highlightedIndex: Int?` 改为 `highlightedURL: URL?`，单击/双击/键盘导航全部从 URL 实时查找当前索引，彻底消除位置编号过期问题 |
| 68042e0 | Enhancement：Finder 文件夹拖到侧边栏等同 Add Folder。`FolderStore` 拆 `addFolder()`（panel）/ `addFolder(from:autoSelect:)`（单 URL）/ `addFolders(from:)`（批量，单个选中、多个保留原选择）；`FolderSidebarView` 加 `.dropDestination(for: URL.self)` 在 ZStack 整块接受，`isTargeted` 驱动紫色 strokeBorder 高亮；Security Scope 复用 `BookmarkManager.saveBookmark`（拖入 URL 在 sandbox 下自带授权）。非目录 URL 静默过滤，多文件夹循环 auto-select false 避免焦点跳 |
| 0e3ec10 | QuickViewer 拖拽 y 方向反了（98573e9 follow-up）：旧 `vm.panBy(deltaY: -event.deltaY)` 假设 NSEvent y↑ 跟 SwiftUI offset y↓ 取反，实测 NSEvent.mouseDragged.deltaY 是 device/screen 坐标 y↓，跟 SwiftUI offset 同向。修复：去掉 `-` 改 `event.deltaY` 直接累加；注释纠错；spec ZoomScrollView 节同步说明 |
| 98573e9 | QuickViewer 1:1 大图拖拽抖动 + 拖不动。根因：`ZoomScrollView.mouseDragged` 用 `dragStartOffset + event.deltaX * 2` 计算，再 `dragStartOffset = vm.offset - event.deltaX * 2` 重设——是 NO-OP（`dragStartOffset` 永远停在 `mouseDown` 时的值）。而 `NSEvent.mouseDragged.deltaX` 是 incremental 而非 cumulative，导致连续 dragged event 把 offset 设成 `init + 当前 event 的小 delta`，图像在小范围内跳变（抖动）+ 总走不远（拖不动）。修复：`QuickViewerViewModel` 加 `panBy(deltaX:deltaY:)` 累加 + `clampOffset()`；`ZoomScrollView.mouseDragged` 简化为 `vm.panBy(event.deltaX, -event.deltaY)`（1:1 倍率，y 反转 AppKit↔SwiftUI），删除 `dragStartOffset` 字段和 `mouseDown` 的 else 分支 |
| 4f9fb18 | QuickViewer 图片打开只占窗口 30-40% 的双 bug 修复（self-fix round 1 = 4bc3c11：fitScale 里 1.0 → DS.Viewer.nativeScale）。根因 A：`fitScale` 卡顶 `min(...,1.0)` 阻止任何上采样；根因 B（主凶）：`QuickViewerOverlay.imageLayer` 同时用 `.scaledToFit() + .scaleEffect(scale)` 双变换，`.scaledToFit` 已填满容器后 `.scaleEffect` 再乘一次 fitScale，图被双重压缩。修复：`fitScale` 改 Preview+Quick Look 混合策略（图 ≤ 窗口保 1:1 不上采样；图 > 窗口缩到 `DS.Viewer.fitPadding = 0.9` 占比留呼吸边）；`imageLayer` 改 `.frame(width: native.w * scale, height: native.h * scale)` 单一变换，`scale` 语义统一为相对原生像素的倍率。`clampOffset` / `canPan` 使用 `image.size * scale` 恰好对齐新的渲染尺寸，拖拽边界随之修复 |
| 1a517b5 | ImagePreviewView 单击预览方向键切换出现 loading 转圈：原 `loadImage()` 每次都 `nsImage = nil` + 异步 `NSImage(contentsOf:)`，磁盘 IO 期间显示 ProgressView。修复：参照 QuickViewer ±1 预加载策略，新增 `ImageViewer/ImagePreviewViewModel.swift`（`prefetchCache: [Int: CGImage]` + `prefetchAdjacent()` + ±2 evict + `clearCache()`），命中缓存直接 set image 无 spinner；`onDisappear` / `onChange(of: images)` 调 `clearCache()` 防止旧 index 错配。**严格 scope**：仅替换 `ImagePreviewView` 内部加载路径，未触动入口、双击、Esc/方向键、focus、startIndex 重映射等任何现有交互 |
| 5d98f3d | ImagePreviewViewModel 预加载半径魔法数字提取常量（codex P1）：`prefetchRadius=1` / `cacheKeepRadius=2` 提到 `static let`，`prefetchAdjacent` 改用 `(-r...r)` 范围生成，`evictCacheIfNeeded` 用 `cacheKeepRadius` 计算 `keepRange` |
| 868271d | ImagePreviewViewModel cache-hit 路径补取消旧 imageLoadTask（codex P1）：上一张磁盘读未完成时若导航到已缓存的下一张，cache-hit 直接 return 不取消旧 task，旧 task 后到会用上一张图覆盖当前显示。修复：`load()` 入口统一先 cancel `imageLoadTask`，再分支处理 cache hit/miss |
| c7a1533 | ImagePreviewViewModel "每张仍转圈"修复（1a517b5 follow-up）：prefetchAdjacent 原本只在首张磁盘读完成后才启动，用户 <1s 切下一张时 prefetch 才刚开始排队 → 移到当前张磁盘读 Task 启动前并发触发；`Task.detached priority .background → .utility` 防 macOS QoS 节流跑不赢 `.userInitiated` 的当前张读取 |
| 4855e40 | ImagePreviewView 仍每张转圈（c7a1533 仍未解决，根因修复）：根因在 `ContentView.swift:131` 的 `.id(idx)`（commit 175e82a 修排序错位时加），方向键 → `selectedImageIndex` 变 → idx 变 → SwiftUI 销毁旧 ImagePreviewView 重建新视图，`@StateObject vm` 跟视图生命周期绑定也被销毁，prefetchCache 全部丢失，每张都 cache miss。修复（方案 A）：vm 提到 ContentView 用 `@StateObject private var previewVM` 持有，ImagePreviewView 改 `@ObservedObject var vm` 接收注入，cache 跨 view 重建持续；clearCache 触发权移交 ContentView 在 `onChange(of: selectedFolder/selectedImageIndex==nil/images)` 三处统一调，删除 ImagePreviewView 的 `.onDisappear { vm.clearCache() }` 和 `onChange(of: images)` 里的 clearCache（前者会在 `.id` 触发重建时被错误调用）。`.id(idx)` 保留不动，QuickViewer 不动 |
| 463633d | c112059 收尾清理时擅自把缩略图文件名 `Text(url.lastPathComponent)` 还原成 `Text(url.deletingPathExtension().lastPathComponent)`（去扩展名）—— 违反 scope 锁死原则（用户当时让"你定"未明确回复时不应擅自落地"默认值"）。改回 `lastPathComponent` 保留扩展名：含同名不同后缀文件夹（4.jpg / 4.png）时标签可直接区分，跟 Finder Cover Flow 行为一致。文件：Glance/FolderBrowser/ImageGridView.swift |
| c112059 | LazyVGrid 缩略图首次点击错位（含 4.jpg/4.png 同名不同后缀场景）：第 7 次根因修复，前 6 次（3c72730/4560625/0330d6b/cfd5d76/4579f1e/4f5efce）解决了状态层（@State / index / sort race / URL identity），但 hit-test 层 bug 依旧——log 证实 TAP url 与 PREVIEW url 完全一致，但视觉上点的 cell 标签写"4.jpg" 而 click 抓到 4.png。codex:rescue review 定位真因：LazyVGrid 首次 materialize 时旧 gesture recognizer 被 reuse 错绑（不是异步竞争）。修复（方案：统一身份系统）：(1) `ForEach(Array(images.enumerated()), id: \.element)` → `ForEach(images, id: \.self)`，去掉 tuple 包装减少身份层次；(2) 两个 `.onTapGesture` 从内层 ThumbnailCell 上移到外层 VStack（紧跟 `.id(url)`），让 gesture host 和 visual identity 同层；(3) 加 `.contentShape(Rectangle())` 显式声明命中区域。同时清掉 ScrollView `.id("\(sortKey)-\(direction)")`（codex 提醒多层 identity marker 会重新引入歧义，且实测对本次 bug 无效）。`.task(id: url)` + `thumbnail = nil` reset 保留作 cell 复用第二道保险。**待办**：macOS 双 onTapGesture(count:1+2) 在 lazy 容器有已知 edge case，独立挂号 followup（见 PENDING-USER-ACTIONS） |
| 44ba6ee | ImageGridView 双击 cell 后 highlight 不跟随到双击的 cell：用户先单击 A（highlight=A），再双击 B 进 QuickViewer，ESC 退出后 highlight 仍停在 A，应跟随到 B。根因：`.onTapGesture(count: 2)` 双击 handler 漏设 `highlightedURL = url`（SwiftUI 对 count:1+count:2 双 gesture 行为：识别为双击时只触发 count:2，不连带 single tap，所以双击路径需独立维护 highlight 状态）。修复：在 `.onTapGesture(count: 2)` 闭包开头补 `highlightedURL = url`，与 `.onTapGesture(count: 1)` 对齐 |
| 44ba6ee | 缩略图网格上下方向键步长错乱跨行：`columnCount()` 用 `NSApp.keyWindow?.contentView?.bounds.width` 估算列数，但 keyWindow.contentView 是整窗宽（包含侧边栏和 Inspector），grid 实际只占中间一段；多算了列数 → 上下方向键 step 偏大 → 一按就跨过实际 grid 一行，看似乱跳。修复：`gridContent` 包 `GeometryReader`，用 `geo.size.width` 反映 mainContent 实际可用宽度（不含 sidebar/inspector）；新 `computeColumnCount(width:)` 公式 `floor((W - 2·padding + spacing) / (cellWidth + spacing))` 与 SwiftUI `.adaptive(minimum:)` 列数算法一致。Inspector 切换 / 窗口缩放时 GeometryReader 自动重算 |
| 5b29600 | 缩略图 grid ESC 退预览后焦点 race（Y-1 + Y-2）：单击 cell A 进 ImagePreviewView → ESC 退回 grid → 按方向键随机两种现象，Y-1 完全无响应 / Y-2 反而又弹出 A 的下一张预览（且预览出现后方向键正常切预览图）。codex:rescue review 验证根因方向：ImagePreviewView 关闭瞬间 `.transition(.asymmetric)` 退场期内 view 仍存活、仍 active focus、仍响应 onKeyPress；同时 ImageGridView `.onAppear { isFocused = true }` 只首次出现触发，grid 一直在 ZStack 底层不会重触 → 焦点处于 race 状态：grid 抢回则 Y-1（按键已派发到 nobody），preview 残留则 Y-2（onKeyPress(.rightArrow) → navigate → 重写 selectedImageIndex 让 preview 重 mount）。codex 推荐 A+B 双侧防御方案：(A) `ImageGridView` 加 `.onChange(of: folderStore.selectedImageIndex) { _, new in if new == nil { isFocused = true } }` 解 Y-1；(B) `ImagePreviewView.onKeyPress(.escape)` 闭包先 `isFocused = false` 再 `onDismiss()` 缩短 Y-2 race window。Plan C（去 transition / if-else 互斥）代价过大（视觉过渡丢失 + grid 可能 remount），不采用。长期更正交方案是父持有 FocusState enum 统一仲裁，超出本次 scope |
| 59a9d86 | Y bug round 2：grid 失焦在 QuickViewer dismiss 路径上未覆盖。新复现链：单击 cell A → preview → ESC（grid 拿焦 ✓）→ Space → QuickViewer → ESC → grid 失焦，Space / 方向键全静默。根因：5b29600 的 `onChange(of: selectedImageIndex)` 只覆盖 ImagePreviewView dismiss 路径；QuickViewer 走 `quickViewerIndex` (ContentView @State)，grid 完全不监听。codex:rescue (gpt-5.4 high effort, gpt-5.5 因 subagent 内部 hardcoded fallback 自动降级) 进一步发现 5.4-medium 漏掉的关键盲点：`ContentView.onChange(of: folderStore.images)` 也会强制 `quickViewerIndex = nil`（切换文件夹时），完全绕过 QV 的 onDismiss 回调；trigger 必须挂在 `ContentView.onChange(of: quickViewerIndex)`（quickViewerIndex 状态出口的真源头）才能覆盖所有关闭路径。修复（5.4-high 7 条）：(1) ContentView 加 `gridFocusTrigger: UUID @State`；(2) 传给 ImageGridView；(3) QV onDismiss 简化、移除原 previewFocusTrigger 路由；(4) 新增 `.onChange(of: quickViewerIndex)` 仲裁：if selectedImageIndex != nil → previewFocusTrigger = UUID() else gridFocusTrigger = UUID()；(5) ImageGridView 加 `gridFocusTrigger` 参数 + `.onChange(of: gridFocusTrigger)` 拉回 isFocused，保留 selectedImageIndex onChange 作冗余兜底；(6) QuickViewerOverlay `handleDismissOrExitFullScreen()` 非全屏分支 onDismiss() 前加 `isFocused = false`（B-side 加固，必须不可选）；(7) ImagePreviewView 抽 `dismissPreview()` helper（`isFocused = false` + onDismiss），ESC handler + 关闭按钮统一走 helper。架构信号：第 2 次同类 focus race bug，已排入 Roadmap 待开发段（FocusState enum 父持有重构） |
| fb7f900 + 1e307ee | QuickViewer 底部 filmstrip 点击命中错位（c112059 同型 bug 在 filmstrip 路径漏修）：用户点 cell A，filmstrip 高亮 + 主图都跳到 cell B，可稳定复现，错位方向 + 位置随机。c112059 当时只覆盖 LazyVGrid（grid），filmstrip 是 LazyHStack 用了同样有问题的 pattern：`ForEach(Array(images.enumerated()), id: \.element)` + `.id(index)` 双层 identity 不一致 + closure 捕获 index 在 cell 复用时过期 → gesture recognizer 错绑。codex:rescue (gpt-5.5 high) 验证根因方向 + 5 处变更充分性，并补了两个我漏掉的：(a) `proxy.scrollTo` 2 处也用 index 要同步改 url；(b) `FilmstripCell .task` 缺 `id: url` reset/cancel guard。完整修复 mirror c112059：(1) `ForEach(images, id: \.self)`；(2) `.id(url)` 替 `.id(index)`；(3) `.contentShape(Rectangle())`；(4) onTapGesture 用 `firstIndex(of: url)` 实时查；(5) `isSelected` 用 url 比较；(6) `proxy.scrollTo` 2 处改用 url + indices.contains 守卫；(7) `FilmstripCell .task(id: url)` + `thumbnail = nil` reset + `Task.isCancelled` guard。CC 修了 codex 留下的小编译错（`var filmstrip: some View` body 加 let 后需 explicit return） |

---

## 待修复 Bug

| 状态 | 模块 | 问题描述 | 已知信息 |
|------|------|----------|----------|
| 间歇 / 待复现 | TrafficLightHide | 双击缩略图进入 QuickViewer 后，左上角 Traffic Lights 按钮异常显示（不应可见 / 或位置错位）；同时侧边栏右上的"收缩侧边栏"toolbar item 消失（这一条按 ContentView.swift:87 的 `.toolbar(quickViewerIndex != nil ? .hidden : .visible, for: .windowToolbar)` 是有意为之，但与 traffic lights 异常一起出现疑似关联）。证据：用户截图 `~/sync/ScreenShot_2026-05-04_223944_900.png`（grid 模式正常）+ `~/sync/ScreenShot_2026-05-04_224129_612.png`（进 QV 后 traffic lights 残留）。**复现状态**：用户同 session 内再尝试已无法稳定复现，疑似间歇性 race。**历史 fix**：commit `f00a584`（进 QV 隐藏 / 退出恢复）→ `a064033`（全屏中退 QV 后 traffic light 不恢复 fix）→ `45a61f1`（hideTrafficLights() 挂载位置修正）— 此 bug 已修过 3 次，可能仍有未覆盖的 race / 时序边界。**下次复现思路**：(1) 加 print 日志到 hideTrafficLights / showTrafficLights / NSWindowDelegate 回调；(2) 复现时记录精确链路（grid 单击/双击 / 是否经 preview / 是否全屏中 / NSWindow 状态）；(3) 对 NSWindow.standardWindowButton(.closeButton)?.isHidden 做断言式 dump |

## 待开发

| 阶段 | 模块 | Spec | 优先级 | 前置依赖 | 说明 |
|------|------|------|--------|----------|------|
| Refactor | Focus 架构父持有重构 | （待写）| 中 | 5b29600 / 59a9d86 ESC race fix | 三个分散 `@FocusState`（grid / preview / QuickViewer）在 dismiss 路径的 race 已修两次。codex high effort 强烈建议改父持有：`ContentView` 加 `@FocusState focusTarget: FocusTarget?` enum，子 view 通过 `.focused($parentFocus, equals: .grid/.preview/.quickViewer)` 绑定，由 ContentView 集中仲裁焦点。本次仍走 incremental trigger UUID 修补，但下次同类 bug 出现前必须做 |
| Followup ✓ 已闭环 | codex:rescue shared broker 不跟随 codex CLI 升级 | — | — | 2026-05-04 排查 | 现象：`codex:rescue` subagent 跑 5.4 而非配置的 gpt-5.5；ephemeral `codex exec` 又用 5.5。**根因**：Claude session 用 shared codex app-server 模式（broker socket），broker 进程启动时锁定当时 binary 路径 + 当时读取的 config，**不会**因后续 npm 升级 codex CLI 或 edit ~/.codex/config.toml 而自动重启。subagent 通过 broker 转发 → 吃老 binary/config。**修复**：`pkill -f "codex.*app-server"` 或 `kill <broker PID>`，下次 codex 调用自动启动新 broker（读新 binary + 新 config）。**确认机制**：companion script `codex-companion.mjs` + lib/codex.mjs 没有 model whitelist，问题不在它们；`codex app-server --help` 显示它接受 `-c key=value` config override，启动时确实读 `~/.codex/config.toml`。codex CLI banner（`codex exec` 启动时）是权威 model + effort 来源；codex 本身在对话中自报 "GPT-5 medium" 等是 LLM self-identify 训练偏差，**不可信**。**已沉淀至全局 ~/.claude/CLAUDE.md 跨项目教训段** |

---

## 开发流程基础设施（2026-04-23 ~ 2026-04-25 落地）

| 工具 | 位置 | 作用 | 关键 commit |
|------|------|------|-------------|
| pre-push codex review hook | `.githooks/pre-push`（`core.hooksPath=.githooks`）| `git push` 时 codex 自动审待推 `.swift + *.md` diff，发现 `[P1]` 阻塞，`[P2]` 警告。docs-only 自动跳过。绕过：`git push --no-verify` / `SKIP_CODEX_REVIEW=1` / commit msg 含 `[skip-codex]` `[wip]` | 3d04775（建）/ 7751b8d（修启动日志误报） |
| `/go` 五步收尾命令 | `.claude/commands/go.md` | 任务收尾必跑：verify 三段 → 文档同步 → PENDING → commit+push → 一段话汇报。Step 1 红→修→重跑最多 5 轮；scope 例外 `[docs-only]` 跳 Step 1 | ffe9618（三步初版）→ 0b3d349（升 5 步） |
| `verify.sh` 三段 oracle | `scripts/verify.sh` | Stage 1 静态规则（ms）+ Stage 2 `xcodebuild build -quiet`（CONFIGURATION_BUILD_DIR=./build）+ Stage 3 单测占位。`--with-codex` 可选全项目 codex 审查。完整 log 留 `.verify-logs/` | ffe9618 / af4f733（路径与 make run 统一）/ 5984323（Stage 2 build 成功后 sync 到 `~/sync/Glance.app`；同步改 Makefile build target，两条 build 路径行为一致；用户本地测试机通过 Syncthing 拉取）|
| PENDING durable 队列 | `specs/PENDING-USER-ACTIONS.md` | 不能自动验证的人工测试项入库累积；`/go` Step 3 追加，人工测完从 Pending 段剪到 Done 段保留历史 | ffe9618 |
| 汇报模板 | `.claude/commands/go.md` Step 5 | 编译行硬约束：`BUILD SUCCEEDED + 0 warnings + ./build/.app mtime + HEAD commit time`。CC 责任终点 = `./build/.app` 是 HEAD 产物（用户本地脚本拉取） | b9822ab / 0c3176d / ffd7ffd |

**工作流**（2026-04-23 用户澄清）：CC 在远程开发机写代码 + `verify.sh` / `make build` 编译到 `./build/`；用户在本地机通过脚本直接拉 `./build/Glance.app` 测试。CC 不教 `make run` / `Cmd+Q`，那是用户本地自动化的事。

**跨 session 持久规则**（写入 auto memory，下次 session 自动加载）：
- `feedback_build_before_handoff.md` — /go Step 5 编译行必须独立显眼（含 `./build/.app` mtime），禁止仅靠 verify "11 passed" 替代
- `feedback_verify_build_path_must_match_run.md` — verify.sh 必须 `CONFIGURATION_BUILD_DIR=./build` 与 Makefile 一致，不得用 `-derivedDataPath` 隔离
- `user_collaboration_style.md` — 协作偏好：新功能 / 设计选择 / bug 因果链不明朗 → 先方案后动手；明确 bug → 直接修

---

## 关键架构决策（新 session 必读）

1. **DesignSystem.swift**：所有 UI 常量的唯一来源，引用 `DS.*`，禁止硬编码。动画常量为 `DS.Anim.fast / normal / slow`（注意：旧名 `DS.Animation` 已废弃）。
2. **PBXFileSystemSynchronizedRootGroup**：`Glance/` 目录下新建 .swift 文件自动加入编译，无需改 xcodeproj。
3. **图片查看两级交互**：
   - 单击缩略图 → `folderStore.selectedImageIndex` → `ImagePreviewView`（内嵌预览，文件名通过 `.navigationTitle` 显示在系统 toolbar）
   - 双击缩略图 → 只设 `quickViewerIndex`，**不设** `selectedImageIndex`（避免底层渲染 ImagePreviewView）→ `QuickViewerOverlay`；关闭后回列表页
   - 双击内嵌预览图片 → `selectedImageIndex` 已有值，设 `quickViewerIndex` → `QuickViewerOverlay`；关闭后回预览页
   - **焦点恢复**：QuickViewerOverlay 为 overlay，关闭时 ImagePreviewView 的 `onAppear` 不再触发；通过 `ContentView.previewFocusTrigger`（UUID）信号驱动 `ImagePreviewView.onChange` 重新 `isFocused = true`
4. **QuickViewerOverlay 覆盖方式**：用 `.overlay` 挂在 `NavigationSplitView` 上（不用 ZStack），确保铺满整个内容区。
5. **三栏布局**：`ContentView` = NavigationSplitView（Sidebar） + HStack（Detail + Inspector）。Inspector 用 `⌘I` 切换，宽度 `DS.Inspector.width`（260pt）。Inspector 按钮在无图片选中时禁用；切换文件夹或取消选图时自动关闭 Inspector。
6. **颜色系统**：主背景 `DS.Color.appBackground`（#121217），网格区 `DS.Color.gridBackground`（#141419），光晕 `DS.Color.glowPrimary`（紫）/ `glowSecondary`（青绿）。`DS.Color.viewerBackground` 已废弃。
7. **树形侧边栏**：`FolderStore.rootFolders: [FolderNode]`（替代旧 `folders: [URL]`）。`discoverTree(at:)` 递归构建子文件夹树，`countImagesInTree(_:)` 统计各节点图片数。子文件夹继承父文件夹的 Security Scoped Bookmark，无需独立权限。
8. **loadThumbnail()**：定义在 `ImageGridView.swift`，internal 级别，`FilmstripCell` 复用。
9. **AppState**：全局 ObservableObject，持有 `NSWindow` 引用 + `isFullScreen` 状态，通过 `EnvironmentObject` 注入。
10. **构建**：项目根目录有 Makefile，用 `make build` / `make run`。
12. **侧边栏选中高亮**：使用 `List(selection:)` 绑定，完全依赖 macOS 系统渲染。聚焦时显示 Accent Color，失焦时显示灰色——这是 macOS 原生行为（Finder / Notes / 邮件均如此），用于传达键盘焦点所在，不做自定义覆盖。`listRowBackground` 选中行设为 `Color.clear`，让系统选中高亮独立渲染。
13. **AppearanceMode**：外观模式（system/light/dark）存在 `AppState.appearanceMode`，通过 `GlanceApp` 的 `preferredColorScheme` 驱动全局外观。`DS.Color.*` 背景/交互色（`appBackground` / `gridBackground` / `hoverOverlay` / `separatorColor`）为 `AdaptiveColor` 类型，实现 `ShapeStyle.resolve(in:)` 从 `EnvironmentValues` 读取 `colorScheme`——可正确响应 SwiftUI per-view `preferredColorScheme` 覆盖。`glowPrimary` / `glowSecondary` 保持 `SwiftUI.Color`（不需要自适应）。`QuickViewerOverlay` 保留 `.preferredColorScheme(.dark)`，其内部所有 `DS.Color.*` 始终解析为 dark 值。`FolderSidebarView` 移除了旧的 `.environment(\.colorScheme, .dark)`，背景改为 `DS.Color.appBackground` 自适应。`ImagePreviewView` 前景色使用 `Color.primary`（深色模式为白，浅色模式为黑）。
