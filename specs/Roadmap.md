# Glance（原 ISeeImageViewer）Roadmap

## 总体目标

打造一款 macOS 原生风格、界面精致的本地看图 app。

---

## 当前进度（2026-05-09）

**V2 M1 Slice A → B → D → G 累积 ship（V2.0-beta1/2/3/4）**

- **V2 M1 Slice A（V2.0-beta1）**：IndexStore (sqlite3) + 单 folder scan + "全部最近" 智能文件夹 + Sidebar IA 改造 + cross-folder grid 完整对齐 V1
- **V2 M1 Slice B（V2.0-beta2，2026-05-09 ship + tag）**：时间分段 chip sticky header（5 段算法 + LazyVGrid pinnedViews + Capsule chip + thickMaterial + strokeBorder hairline）+ 第 2 内置 SF「本周新增」+ 键盘 (sectionIdx, row, col) 导航算法
- **V2 M1 Slice D（V2.0-beta3，2026-05-09 ship + tag）**：hide toggle 右键菜单（root + 子目录两层 + 稀疏 explicit 状态继承 walk SQL）+ Inspector 来源 path 段 + "在 Finder 中显示"按钮
- **V2 M1 Slice G（V2.0-beta4，2026-05-09 ship + tag）**：删 root 清理（FK CASCADE）+ FSEvents 增量监听（每 root 一 stream，ItemCreated/Removed/Modified/Renamed 实时同步 IndexStore）
- **V1 v1.0**：已公开发布（GitHub Release + DMG + 仓库 public，2026-05-08 commit `0c9f699`）
- 工程化基建：`/go` 五步 / `verify.sh` 三段 oracle / `build/Glance.app` 自动 sync `~/sync/` / pre-push codex hook / build 版本号注入 + BuildInfo sidecar
- 下一步主线：Slice H 内容去重 SHA256 + cheap-first 粗筛（V2.0-beta5）
- 远期 Refactor：Focus 架构父持有重构（详见待开发段）

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
| BuildVersionInfo | — | 38adfd4 | build 版本号注入 + BuildInfo.txt sidecar，取代不可靠 mtime 当跨机判断真值。Makefile + verify.sh 两条 build 路径同步通过 `xcodebuild ... CURRENT_PROJECT_VERSION="<commit>[-d].<MMDD-HHMM>"` 写入 Info.plist `CFBundleVersion`；同时输出 `Glance.app.BuildInfo.txt` sidecar（commit / dirty / version / commit_time / commit_msg / built_at / host 七字段）。-d 后缀标记 working tree 有未 commit 改动避免误读 |
| AboutPanel | — | 8f927d1 | 完整收口于 6f56072（toast/复制配套）。自定义"关于一眼"窗口（替换标准 NSAboutPanel）。原因：标准面板 NSHumanReadableCopyright 字段不可点击，无法挂复制 handler。新建 `Glance/About/AboutView.swift`：AppIcon 96px / 名称 / 动态版本号 / 两行可点击 contact（`© 2026 孙红军 · 16414766@qq.com` / `小红书 382336617`），点击复制全文到剪贴板 + 1.5s toast。GlanceApp 加 `CommandGroup(replacing: .appInfo)` + `Window("about")` scene。Text + onTapGesture 替代 Button 避免 macOS focus ring 残留（09c418c 修），补 `.accessibilityAddTraits(.isButton)` 保 a11y。DS.About 段（windowWidth/appIconSize/toastMaxWidth/toastDurationSeconds）+ DS.Color.secondaryText alias 到 SwiftUI .secondary |

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
| 09c418c | AboutView contact 行点击后残留 macOS focus ring：用户截图显示点击"© 2026 孙红军 · 16414766@qq.com"行后该行周围出现 accent color 细描边。根因：macOS `Button` 是 focusable 元素，被点击 / Tab 移焦后 system 自动画 keyboard focus ring；`.buttonStyle(.plain)` 只去 button 背景，focus ring 是单独 overlay 不受影响。修复：Text + `.onTapGesture` + `.contentShape(Rectangle())` 替代 Button —— Text 不进入 focus chain 无 ring；补 `.accessibilityAddTraits(.isButton)` 让 screen reader 仍识别"按钮"语义不退化 a11y |
| 8f927d1 + 6f56072 | 自定义"关于一眼"窗口（替换标准 NSAboutPanel）：标准面板的 NSHumanReadableCopyright 字段不可点击，不能挂复制 handler；改用 SwiftUI 自定义 view + Window scene + CommandGroup(replacing: .appInfo) 实现两行 contact 文本（`© 2026 孙红军 · 16414766@qq.com` / `小红书 382336617`）支持点击复制全文到剪贴板 + 1.5s toast Capsule 提示。新建 `Glance/About/AboutView.swift`；GlanceApp 加 `.commands` + `Window("about")` scene；`@Environment(\.openWindow)` 打开。9bc7c0e 修 P1 magic number / DS.* 引用：加 DS.About 段（windowWidth/appIconSize/toastMaxWidth/toastDurationSeconds）+ DS.Color.secondaryText alias 到 SwiftUI .secondary；showToast 改用 Task.sleep(for: .seconds()) 绕开 nanoseconds 字面 |
| fb7f900 + 1e307ee | QuickViewer 底部 filmstrip 点击命中错位（c112059 同型 bug 在 filmstrip 路径漏修）：用户点 cell A，filmstrip 高亮 + 主图都跳到 cell B，可稳定复现，错位方向 + 位置随机。c112059 当时只覆盖 LazyVGrid（grid），filmstrip 是 LazyHStack 用了同样有问题的 pattern：`ForEach(Array(images.enumerated()), id: \.element)` + `.id(index)` 双层 identity 不一致 + closure 捕获 index 在 cell 复用时过期 → gesture recognizer 错绑。codex:rescue (gpt-5.5 high) 验证根因方向 + 5 处变更充分性，并补了两个我漏掉的：(a) `proxy.scrollTo` 2 处也用 index 要同步改 url；(b) `FilmstripCell .task` 缺 `id: url` reset/cancel guard。完整修复 mirror c112059：(1) `ForEach(images, id: \.self)`；(2) `.id(url)` 替 `.id(index)`；(3) `.contentShape(Rectangle())`；(4) onTapGesture 用 `firstIndex(of: url)` 实时查；(5) `isSelected` 用 url 比较；(6) `proxy.scrollTo` 2 处改用 url + indices.contains 守卫；(7) `FilmstripCell .task(id: url)` + `thumbnail = nil` reset + `Task.isCancelled` guard。CC 修了 codex 留下的小编译错（`var filmstrip: some View` body 加 let 后需 explicit return） |
| 2b858cf | 跟随系统外观模式不生效：用户在「跟随系统 / 强制深 / 强制浅」三选一菜单切到「跟随系统」后视图不重置，仍卡在之前强制色。根因：SwiftUI `.preferredColorScheme(nil)` 在 macOS 上**无法撤销**之前设过的 `.light/.dark` 强制值（已知 limitation） — 视图层级保留旧 colorScheme。修复：改用 AppKit 标准 API `NSApp.appearance` 直接控 NSAppearance（system → nil / light → .aqua / dark → .darkAqua），在 `AppState.appearanceMode.didSet` 调 `applyAppearance()`，init 末尾调一次保证启动模式生效。`GlanceApp.swift` 中的 `.preferredColorScheme(...)` modifier 删除。`QuickViewerOverlay.preferredColorScheme(.dark)` 不变（view 局部覆盖跟 NSApp.appearance 不冲突）|
| dcabffc | light 模式侧边栏 vs 内容区对比方向反了：内容区 `gridBackground` = #EBEBF0 比侧边栏 `appBackground` = #F2F2F7 **更暗**，跟 dark 模式（内容区 #141419 稍亮于侧边栏 #121217）方向相反，也跟 macOS 系统 app（Finder/Notes/Mail）light 模式视觉标准（侧边栏 vibrant 灰 + 内容区白）冲突。修：`DS.Color.gridBackground.light` #EBEBF0 → `Color.white`（#FFFFFF），让内容区永远是焦点。dark 模式不动 |
| e2e0d21 | 关于窗口位置不跟随主窗口居中（方案 1 失败）：挪动主窗口后打开关于面板，关于窗口出现在屏幕中心或上次记住位置，没相对当前主窗口居中。系统标准 NSAboutPanel 默认就跟随主窗口居中（免费），但 8f927d1 改用自定义 SwiftUI `Window("about")` 后失去该行为。**方案 1 (commit e2e0d21，已被 20fa509 重写)**：`AboutView.onAppear` + `DispatchQueue.main.async` + `setFrameOrigin`。**实测有 A→B 视觉跳跃**：window 已显示在默认位置 A 后下一帧才被移到 B，用户能看见跳跃。根因：SwiftUI Window scene 不暴露"显示前定位"hook |
| 20fa509 | 关于窗口位置（方案 2 真解）：改用纯 AppKit `AboutWindowController` 单例 + `NSHostingView(AboutView())` 替代 SwiftUI `Window("about")` scene。`show()` 函数顺序：① 创建/复用 NSWindow（`isReleasedWhenClosed = false`，关闭后保留实例）② `setFrameOrigin` 居中到主窗口 ③ `makeKeyAndOrderFront(nil)` —— 显示前已定位完，零跳跃。`GlanceApp.swift` 删 `Window("关于一眼", id: "about")` scene + `.windowResizability`；`AboutMenuButton` 不再 `@Environment(\.openWindow)`，改调 `AboutWindowController.shared.show()`。`AboutView.swift` 删原 onAppear 居中逻辑（不再需要） |
| 79fcfdf | F 键全屏只在 QuickViewer 中有效，grid 和 preview 模式按 F 无响应（v1.0 distribution smoke test 发现的老 spec/实现 gap，从 commit `0abcae6` FullScreen 模块初始就如此）。`AppState.md:62` spec 写"用户按 F 键"但模糊未指定 view，按字面是全局；实际只 `QuickViewerOverlay.swift:146` 挂了 `onKeyPress(.init("f"))` handler，`ImageGridView` / `ImagePreviewView` 都漏挂。**修法**：(1) `Glance/FolderBrowser/ImageGridView.swift` 加 `@EnvironmentObject var appState: AppState` + 在现有 `.onKeyPress(.space)` 旁加 `.onKeyPress(.init("f"), phases: .down) { _ in appState.toggleFullScreen(); return .handled }`；(2) `Glance/ImageViewer/ImagePreviewView.swift` 同上 inject + 加 F handler。spec 同步：`AppState.md:62` 改为"用户在 grid / preview / QuickViewer 任一界面按 F 键"明确全局。风险低：F 键不冲突现有 grid/preview 其他 onKeyPress（grid: space/方向键，preview: escape/space/方向键），`appState.toggleFullScreen()` 调用模式跟 QV 一致 |
| 02a36dc | Bug 4 扩展 — QV 方向键 / nav button / filmstrip 切图后 ESC 退出 grid highlight + preview 都不跟到 Z（用户期望对齐 Finder Quick Look + macOS Photos 标准）。**3 条路径**：(1) grid 双击 cell A → QV → 方向键 Z → ESC → grid highlight 期望 = Z；(2) grid 单击 A → preview → 双击 → QV → 方向键 Z → ESC → preview 期望 = Z；(3) 续 (2) 再 ESC → grid highlight 期望 = Z。**修法风险高的关键**：commit 6da903c 修过"双击 cell 进 QV 后退出回 grid 不进 preview"，靠 onDoubleClick 设 selectedImageIndex = nil；如果 QV 方向键直接写 selectedImageIndex 路径 1 会反向引发 6da903c 回归（退 QV 后 selectedImageIndex != nil → 进 preview）。**根因 + 修法**（codex:rescue gpt-5.5 high Approach A）：用入口来源 enum + QV index 变化回调，让 dismiss 路由按 provenance 走，不依赖 selectedImageIndex 是否 nil 当哨兵。改动：(1) `Glance/ContentView.swift` 加 `private enum QuickViewerEntry { case grid, preview }` + `@State quickViewerEntry: QuickViewerEntry?` + `onDoubleClick` 设 `.grid` + preview `onQuickView` 设 `.preview` + `.onChange(of: quickViewerIndex)` 仲裁改 switch entry 路由（.grid → 清 selectedImageIndex + gridFocusTrigger，.preview → previewFocusTrigger）+ QV `onIndexChange: { folderStore.selectedImageIndex = newIdx }` + 收紧 preview 渲染条件 `if let idx = selectedImageIndex, quickViewerIndex == nil`（codex 标盲点：.id(idx) 让 preview 在 selectedImageIndex 变化时整体重建，QV 期间不渲染避免后台 mount/loadImage）；(2) `Glance/QuickViewer/QuickViewerOverlay.swift` 加 `let onIndexChange: (Int) -> Void` 参数 + `.onChange(of: viewModel.currentIndex) { _, newValue in onIndexChange(newValue) }` 一处统一覆盖 nav button (goBack/goForward) + filmstrip tap (goTo) + 方向键三种 QV 内导航路径（codex 标的盲点 1，避免补 key handler 漏渠道） |
| <pending> | Bug 4 grid highlight 不跟 preview 方向键导航（UX gap，对齐 Finder Cover Flow / Photos.app）：用户单击 grid cell 1.png → preview → 方向键 ←→ 浏览到 5.png → ESC 退回 grid → grid 紫色高亮仍停在 1.png（应跟到 5.png）。**Roadmap 原描述不准**：原说 "175e82a 刻意解耦 currentIndex 跟外部 selectedImageIndex，方向键不写回"，**实际 ImagePreviewView.navigate(by:) L147-152 已写回 selectedImageIndex**。codex:rescue gpt-5.5 high 拍 + audit 5 个历史 bug 全无回归。**真根因**：`ImageGridView.swift:158-160` `.onChange(of: folderStore.selectedImageIndex)` 闭包**只**处理 nil 分支拉焦点，没有 non-nil 分支同步 highlightedURL。**修法**：扩展该闭包加 non-nil 分支 `else if let idx = newValue, folderStore.images.indices.contains(idx) { highlightedURL = folderStore.images[idx] }`，单文件 3 行。**风险评估**：codex 验证 5 个历史 commit 全无回归 — 175e82a (ImagePreviewView startIndex 重置 + .id(idx) 不动) / b67ab3c (URL identity 一致) / 44ba6ee (双击路径 onDoubleClick 清 nil 走旧分支不触发新逻辑) / 5b29600 + 59a9d86 (焦点 race nil 分支不变)。排序场景：applySortKey 先清 selectedImageIndex 再排，onChange(of: images) 也清 highlightedURL，新分支无机会跟到错位置。双写无害：单击 cell `.onTapGesture(count:1)` 已写 highlightedURL = url，新 onChange 闭包再写一次结果同 URL |
| 3cdb991 | 浅色模式下 QuickViewer 强制深色 ESC 退出后 dark colorScheme 渗透到底层（用户截图 `~/sync/g1.png` Path A / `~/sync/g2.png` Path B），失焦自愈。**Path A**（grid → 直接双击 cell → QV → ESC）：sidebar 变深灰，detail 列保持浅色。**Path B**（grid → 单击 → preview → 双击 → QV → ESC）：整个 app 全深色（sidebar + preview + 文件名 toolbar）。**老 bug**：用户 git checkout 086ade2 build 复现，跟当前 c0c833a `.toolbarBackground` 改动无关，浅色模式测试覆盖少所以一直没暴露。**根因**（codex:rescue gpt-5.5 high 拍）：`QuickViewerOverlay.swift:95` `.preferredColorScheme(.dark)` 是 **presentation-scoped** 偏好，写到 NSHostingView/NSWindow.contentView appearance 链 —— 不是纯本地子树 environment。QV dismiss 时 SwiftUI 撤销 colorScheme env 有滞后，底层 view 已被重绘。Path B preview 全深因为 QV 关闭瞬间 `previewFocusTrigger` 触发 ImagePreviewView 刷新，那一瞬 colorScheme env 还是 dark → AdaptiveColor 返 dark 值。**我之前推 "AdaptiveColor 重读 NSWindow.appearance" 错了**：AdaptiveColor 实际从 SwiftUI colorScheme env 读，不读 NSWindow.appearance。**修法**：单文件单行 `Glance/QuickViewer/QuickViewerOverlay.swift:95` `.preferredColorScheme(.dark)` → `.environment(\.colorScheme, .dark)`。`.environment` 是本地子树 SwiftUI environment，不动 NSHostingView/NSWindow appearance 链 —— QV dismiss 时无 presentation 偏好滞后撤销。QV 内部全用显式 SwiftUI 颜色无 AppKit material 故视觉等价。codex 标盲点：未来 QV 引入需要 AppKit dark appearance 的 NSVisualEffectView material 时方案不够，需补 AppKit 层 appearance 保存/恢复。当前无此问题 |
| c0c833a | 首次进 ImagePreviewView 顶部出现一条浅灰横向 toolbar 底色，跟下方 preview 紫黑色 (`appBackground` #121217) 明显断层（用户截图 `~/sync/f4.png` bug / `~/sync/f5.png` 正常）。**触发条件**：启动 app → 单击 cell 进 preview → f4 状态；双击进 QuickViewer → ESC 退出 → 再单击 cell 进 preview → 永久变 f5 状态（融合到 NSWindow title bar 深色，无断层）。文件名 + ⓘ Inspector + 外观切换按钮位置不变（detail 列左 / 右），只是 toolbar chrome 形态切换。失焦/聚焦不触发，排除 macOS focus state quirk。**前 1 次修法 e39fbbf 装到实机零变化**（关于面板 commit hash 已对齐）：codex:rescue 第一轮拍 AppKit `NSWindow.toolbarStyle = .unified` 走错层 — 浅灰横条不是 toolbarStyle (unified/expanded 布局枚举) 导致，是 SwiftUI window toolbar **background material 绘制层**，AppKit 改 `toolbarStyle` 跟视觉绘制完全不同层。**真根因**（codex:rescue 第二轮 gpt-5.5 high resume 同 thread 拍）：浅灰横条 = SwiftUI `NavigationSplitView` 默认绘制的 `.windowToolbar` background material；`ContentView.swift:97` `.toolbar(quickViewerIndex != nil ? .hidden : .visible, for: .windowToolbar)` 在 QV 进出时通过 SwiftUI 同一 toolbar visibility 栈 invalidate 了 background 绘制 → 永久变 fused（意外副作用 = 用户期望状态）。**修法**：(1) `Glance/ContentView.swift` 紧贴 L97 加 `.toolbarBackground(.hidden, for: .windowToolbar)`（macOS 13+ SwiftUI API，部署目标 14 满足）—— 直接控制 SwiftUI 这一绘制层，跟 QV hide/visible 走同一栈；(2) `Glance/FullScreen/WindowAccessor.swift` 回滚 e39fbbf 加的两处 `window.toolbarStyle = .unified`（已验证无效，留着会污染 codebase）|
| 086ade2 | Inspector 旁边粉色长条 + 整个 app 被一道粉色细框框住 + 失焦消失聚焦出现（同根因，初次诊断 61029fa+a27e496+01d1fca 把方向搞错为 SwiftUI Divider 没修对）：真根因是 SwiftUI `.focusable()` 默认渲染 system accent color focus ring，用户系统 accent color = 粉色。证据链：(1) 颜色匹配 accent color；(2) macOS 标准行为 window 失焦时 focus indicator 自动褪色 → 解释失焦/聚焦切换；(3) ImagePreviewView body 用 `appBackground.ignoresSafeArea()` 让 ZStack 跨 safe area，focus ring 沿实际边界画 → 解释整个 app 被细粉框框住；(4) 关 Inspector 后 ImagePreviewView 右缘到达窗口最右侧被边框盖住，开 Inspector 后右缘暴露在 mainContent / Inspector 之间 → 解释"Inspector 旁边那条最粗最显眼"。codex:rescue (gpt-5.5 high) 验证根因方向 + 修法 API + scope 充分性，标出原假设盲点（关 Inspector 不是 ring "消失" 而是被 layout 切掉）。修：3 处 `.focusable()` 后插入 `.focusEffectDisabled()`（macOS 14+ API，禁用视觉 ring 但保留 focus 调度，onKeyPress 仍工作） — `ImagePreviewView.swift:111` / `ImageGridView.swift:151` / `QuickViewerOverlay.swift:96`。FolderSidebarView 用 `List(selection:)` 不是 `.focusable()`，本次不动 |
| 61029fa | Inspector 开关时多一道粉色竖线 + 关闭后延迟消失（Bug 2/3 同根因合并修，**初次诊断方向搞错**，已被上一行真根因修法取代；本条留作历史，不再生效）。完整失败修法系列：61029fa 主 + a27e496 magic number fixup + 01d1fca docs 对齐：`ContentView.swift:35` 独立 `Divider()` 没加 `.transition`，跟 Inspector 的 `.move(.trailing)+.opacity` 不同步——开 Inspector 时 Divider 默认 `.opacity` 直接 fade in 到最终位置但 Inspector 还在窗外滑入，视觉上"提前到位"；关 Inspector 时 Inspector `.move` 滑出后 Divider fade out 残留。粉色推测为 SwiftUI Divider 内部 system separator color 在 dark 模式下叠加 vibrancy/accent 偏冷紫调，修同步问题后视觉 artifact 应大幅缓解（动画窗内才可见）。修：(1) ContentView.swift 删 L35 `Divider()`；(2) ImageInspectorView.swift body 末尾加 `.overlay(alignment: .leading) { Rectangle().fill(DS.Color.separatorColor).frame(width: DS.Inspector.separatorWidth) }`（DS.Inspector.separatorWidth = 0.5，HiDPI 下对应 1 物理像素）——边线绑定到 Inspector 视图本身，自动跟随同一 transition 同步出入，从语义上"分隔线 = Inspector 视觉边界"。配套：Roadmap L44 AboutPanel hash `8f927d1 + 6f56072` 改为 `8f927d1`，把 `6f56072` 信息挪入说明，让 verify.sh stage 1 hash 格式检查通过 |
| ab1fe89 | dark 模式底色跟 Finder 等系统 app 不合群（暗 60% + 偏冷蓝紫）— **partial fix**：删 hardcoded background 让系统 sidebar material 接管后实测**仍有渐变**（顶部 row 区域 vibrancy + 下半空白深黑色 windowBackground 覆盖）。codex:rescue 给的 NSVisualEffectView 桥方案落地后引发**关于居中回归**（具体因果链未定）+ 视觉仍不一致，已 revert。**待 v1.0.1 重新审**（可能需要 audit ZStack vs NavigationSplitView column 行为）。**当前 ab1fe89 状态**：ImagePreviewView/QuickViewer 仍用 appBackground 紫深色（设计语言保留）；FolderSidebarView 顶部紫色 RadialGradient glow 保留+ 失焦无响应（Finder/Mail/Notes 失焦后侧边栏会自动褪色，Glance 不变）。根因：(1) `appBackground/gridBackground` 用了硬编码 hex (#121217 / #141419) 替代 system semantic color；(2) 选了偏冷蓝紫（B 通道高于 R/G）；(3) FolderSidebarView 用 `.listStyle(.sidebar)` 后又用 `.background(DS.Color.appBackground)` 把 SwiftUI 自动派发的 NSVisualEffectView material `.sidebar` 完全覆盖掉，listRowBackground 未选中行又被 `appBackground` 二次覆盖。修：删 4 处 hardcoded background —— (1) `FolderSidebarView.swift:38` 删 `.background(appBackground)`；(2) `FolderSidebarView.swift` listRowBackground 简化为 `Color.clear`（清 `isSelected` 死变量）；(3) `ImageGridView.swift:146` 删 `.background(gridBackground)`；(4) `ImageGridView.swift:27` empty state `gridBackground` → `Color.clear`。让 NavigationSplitView + listStyle(.sidebar) 默认行为接管：sidebar 自动 NSVisualEffectView material `.sidebar` + state `.followsWindowActiveState`（失焦自动褪色，跟 Finder 一致），dark/light 自动切，跨 OS 版本稳定。`appBackground/gridBackground` 定义保留（QuickViewer / ImagePreviewView 仍引用，QuickViewer 强制 dark 是设计选择不动）|
| 60a2de2 | Slice B-α follow-up — 3 个用户首测 bug：(1) sticky header 在 dark mode 呈现"大块黑横条"：背景 `DS.Color.gridBackground` 不透明黑（#141419）改 `.regularMaterial` 半透明毛玻璃；字号 `.headline` → `.subheadline.weight(.semibold)`；padding 收紧（codex review Q3 验证 + Bug 1）。(2) ↑↓ 跨段乱跳（plan-time 决策 4 判断错的纠偏）：原 flat queryResult ± colCount 步长在 sectioned grid 下不对应"视觉一行"（section header 占视觉一行 + 每段 col=0 重置）；重写 `moveHighlight` 为 `(sectionIdx, rowInSection, col)` 模型 + `MoveDirection` enum：←→ 仍 flat ±1（A 方案，跨段自然连续，行为继承 V1）/ ↑↓ 段内同 col 上下 / 段边界跳邻段对应 col / col 超过目标行末 clamp / nil/stale highlightedID 显式 down→第一项 up→末项 / 第一段第一行 ↑ / 末段末行 ↓ 原地。新增 `locate(_:in:)` helper 定位 (sectionIdx, indexInSection)。(3) sticky header 区域点击穿透到下方 cell：SwiftUI `.background(Color)` 不消费 hit-test，加 `.contentShape(Rectangle()).onTapGesture {}` 显式吃 tap。架构：sections 提到 body 顶部一次算（codex Q5.1），render LazyVGrid + ↑↓ nav 共用同一快照，避免跨午夜 render/nav 双源不一致。修法走 codex:rescue 独立 review 后落地（路径 2，决策全 A）|
| c5b048a | Slice B-α follow-up #2 — sticky header"横条"视觉第三轮修法（前两次都失败）：用户两次反馈"黑横条/横条体验差"，60a2de2 用 `.regularMaterial` 半透明仍是"全宽横条"——根因不是 background 颜色/材质，是 SwiftUI LazyVGrid Section header **全宽 row 的 layout 属性本身**，改 background 永远改不掉。修法（用户提议 + codex:rescue 5 项 review 通过：Q1 行高 ✓ / Q3 material+Capsule ✓ / Q4 idiom ✓ / Q5 无 LazyVGrid 不兼容 ✓ / Q2 ⚠ pinned hit-test 待实测）：(1) 文字+padding 包进 `Capsule` 用 `.background(.regularMaterial, in: Capsule())` 形成 chip 实体；(2) row 自身去 background（透明），sticky 时 chip 之外区域 cell 直接透过显示；(3) 去掉 60a2de2 加的 `.contentShape(Rectangle()).onTapGesture {}`（透明 row 不需要 + 反而会阻止 chip 之外区域点 cell）。视觉效果：sticky 时左上角浮一个小 capsule（"今天 · 3 张"），其余 row 区域完全透明。修法 sub-scope 严格：仅 SmartFolderGridView.swift sectionHeader 函数体 + 顶部 doc comment；moveHighlight + locate + LazyVGrid pinnedViews + 所有交互逻辑不动 |
| _本 commit_ | Slice B-α follow-up #3 — chip 在 light cell 上对比度不够（Round 3 sticky chip 形态本身 OK，但 `.regularMaterial` 在 light env 自适应偏白，跟 light cell 撞色边界融）：升 `.thickMaterial` + 加 1pt `Capsule().strokeBorder(.primary.opacity(0.12), lineWidth: 0.5)` 给 chip 永远可见边界。模式参考 macOS Calendar.app / Mail.app sidebar items hairline。修法 surface 极小（仅 sectionHeader 函数体 +3 行 .overlay），不走 codex:rescue（chip 形态主体 c5b048a 已过 review，本次仅 SwiftUI 标准 modifier 微调） |
| 4f318b5 | Slice D.1 P1 真 bug：`upsertSubfolderHide` 的 `ON CONFLICT (parent_root_id, relative_path)` 没匹配 schema 的 *partial* unique idx `idx_folders_subpath ... WHERE parent_root_id IS NOT NULL`，SQLite 拒绝 prepare → 子目录 hide 永远不持久（右键 toggle 等于 no-op，状态不进数据库）。修：ON CONFLICT 后加 `WHERE parent_root_id IS NOT NULL` 子句对齐 partial idx 谓词。同 commit 顺手修 P2：`FolderSidebarView.rootURL(for:)` 嵌套 root 场景（/parent + /parent/child 同时管理）first prefix 匹配错路由 → 改 max(by:) 取最长前缀；Roadmap 当前进度段从 2026-05-08 Slice A 同步到 2026-05-09 Slice B ship + D.1 进行中 |
| _本 commit_ | Slice G.4 P1 fix（codex 抓 Slice G ship commit `8df97af` 2 项 policy 违反，functional 无影响）：(1) `FSEventsWatcher.swift` 一文件双类型违反（FSEvent + FSEventsWatcher）→ 拆出 `FSEvent.swift` 独立文件；(2) `latency: 1.0` 魔法字面量 → 抽 `FSEventsWatcher.defaultLatency` static let 常量。**Tag 历史保留**：tag `v2.0-beta4` 仍指向 `8df97af`（含已知 policy 违反 + functional ship）；本 commit 标 `[skip-codex]` 让 push range 跳过 codex 复审（2 项 P1 已修），后续 review 流程不再被同 P1 重复阻塞 |

---

## 待修复 Bug

| 状态 | 模块 | 问题描述 | 已知信息 |
|------|------|----------|----------|
| 间歇 / 待复现 | TrafficLightHide | 双击缩略图进入 QuickViewer 后，左上角 Traffic Lights 按钮异常显示（不应可见 / 或位置错位）；同时侧边栏右上的"收缩侧边栏"toolbar item 消失（这一条按 ContentView.swift:87 的 `.toolbar(quickViewerIndex != nil ? .hidden : .visible, for: .windowToolbar)` 是有意为之，但与 traffic lights 异常一起出现疑似关联）。证据：用户截图 `~/sync/ScreenShot_2026-05-04_223944_900.png`（grid 模式正常）+ `~/sync/ScreenShot_2026-05-04_224129_612.png`（进 QV 后 traffic lights 残留）。**复现状态**：用户同 session 内再尝试已无法稳定复现，疑似间歇性 race。**历史 fix**：commit `f00a584`（进 QV 隐藏 / 退出恢复）→ `a064033`（全屏中退 QV 后 traffic light 不恢复 fix）→ `45a61f1`（hideTrafficLights() 挂载位置修正）— 此 bug 已修过 3 次，可能仍有未覆盖的 race / 时序边界。**下次复现思路**：(1) 加 print 日志到 hideTrafficLights / showTrafficLights / NSWindowDelegate 回调；(2) 复现时记录精确链路（grid 单击/双击 / 是否经 preview / 是否全屏中 / NSWindow 状态）；(3) 对 NSWindow.standardWindowButton(.closeButton)?.isHidden 做断言式 dump |

## 待开发

| 阶段 | 模块 | Spec | 优先级 | 前置依赖 | 说明 |
|------|------|------|--------|----------|------|
| Refactor | Focus 架构父持有重构 | （待写）| 中 | 5b29600 / 59a9d86 ESC race fix | 三个分散 `@FocusState`（grid / preview / QuickViewer）在 dismiss 路径的 race 已修两次。codex high effort 强烈建议改父持有：`ContentView` 加 `@FocusState focusTarget: FocusTarget?` enum，子 view 通过 `.focused($parentFocus, equals: .grid/.preview/.quickViewer)` 绑定，由 ContentView 集中仲裁焦点。本次仍走 incremental trigger UUID 修补，但下次同类 bug 出现前必须做 |

---

## 开发流程基础设施（2026-04-23 ~ 2026-04-25 落地）

| 工具 | 位置 | 作用 | 关键 commit |
|------|------|------|-------------|
| pre-push codex review hook | `.githooks/pre-push`（`core.hooksPath=.githooks`）| `git push` 时 codex 自动审待推 `.swift + *.md` diff，发现 `[P1]` 阻塞，`[P2]` 警告。docs-only 自动跳过。绕过：`git push --no-verify` / `SKIP_CODEX_REVIEW=1` / commit msg 含 `[skip-codex]` `[wip]` | 3d04775（建）/ 7751b8d（修启动日志误报） |
| `/go` 五步收尾命令 | `.claude/commands/go.md` | 任务收尾必跑：verify 三段 → 文档同步 → PENDING → commit+push → 一段话汇报。Step 1 红→修→重跑最多 5 轮；scope 例外 `[docs-only]` 跳 Step 1 | ffe9618（三步初版）→ 0b3d349（升 5 步） |
| `verify.sh` 三段 oracle | `scripts/verify.sh` | Stage 1 静态规则（ms）+ Stage 2 `xcodebuild build -quiet`（CONFIGURATION_BUILD_DIR=./build）+ Stage 3 单测占位。`--with-codex` 可选全项目 codex 审查。完整 log 留 `.verify-logs/` | ffe9618 / af4f733（路径与 make run 统一）/ 5984323（Stage 2 build 成功后 sync 到 `~/sync/Glance.app`；同步改 Makefile build target，两条 build 路径行为一致；用户本地测试机通过 Syncthing 拉取）/ 38adfd4（build 版本号注入 `CURRENT_PROJECT_VERSION=<commit>[-d].<MMDD-HHMM>` + sidecar `Glance.app.BuildInfo.txt`，关于面板显示 commit hash 取代不可靠 mtime）|
| PENDING durable 队列 | `specs/PENDING-USER-ACTIONS.md` | 不能自动验证的人工测试项入库累积；`/go` Step 3 追加，人工测完从 Pending 段剪到 Done 段保留历史 | ffe9618 |
| 汇报模板 | `.claude/commands/go.md` Step 5 | 编译行硬约束：`BUILD SUCCEEDED + 0 warnings + ./build/.app mtime + HEAD commit time`。CC 责任终点 = `./build/.app` 是 HEAD 产物（用户本地脚本拉取） | b9822ab / 0c3176d / ffd7ffd |

**工作流**（2026-04-23 用户澄清）：CC 在远程开发机写代码 + `verify.sh` / `make build` 编译到 `./build/`；用户在本地机通过脚本直接拉 `./build/Glance.app` 测试。CC 不教 `make run` / `Cmd+Q`，那是用户本地自动化的事。

**跨 session 持久规则**（写入 auto memory，下次 session 自动加载）：
- `feedback_build_before_handoff.md` — /go Step 5 编译行必须独立显眼（含 `./build/.app` mtime），禁止仅靠 verify "11 passed" 替代
- `feedback_verify_build_path_must_match_run.md` — verify.sh 必须 `CONFIGURATION_BUILD_DIR=./build` 与 Makefile 一致，不得用 `-derivedDataPath` 隔离
- `user_collaboration_style.md` — 协作偏好：新功能 / 设计选择 / bug 因果链不明朗 → 先方案后动手；明确 bug → 直接修

---

## Distribution（公开分发打包，2026-05-05 落地）

V1 走 **Developer ID 签名 + Notarization + DMG**（不上 Mac App Store），公开分发到 GitHub Releases。

**身份与配置**

| 项 | 值 | 备注 |
|---|---|---|
| Apple Developer Program | Hongjun Sun（个人）| 续订到 2027/05/05，年费 ¥688 |
| Team ID | `8KW8Z92GRA` | pbxproj `DEVELOPMENT_TEAM` 字段 |
| 签名 identity | `Developer ID Application: Hongjun Sun (8KW8Z92GRA)` | 装在 Mac mini 登录 keychain；私钥 .p12 备份在家里 MacStudio + 冷备份 |
| Bundle ID | `com.sunhongjun.glance` | 不变 |
| 部署目标 | macOS 14.0（Sonoma）| 26.2 → 14.0 降级，覆盖 ~85% 用户 |
| Marketing 版本 | `1.0.0` | 用户可见（关于面板 / DMG 文件名 / GitHub release tag） |
| Build 版本 | `<commit short>[-d].<MMDD-HHMM>` | 给开发者看，CFBundleVersion 字段，发布版仍带 -d 标记表示有未 commit 改动 |
| Hardened Runtime | `ENABLE_HARDENED_RUNTIME=YES` | 仅 release 脚本注入，不写到 pbxproj（Debug build 不受影响） |
| Entitlements | sandbox + user-selected read-only + bookmarks app-scope | 不需要 hardened runtime 额外 entitlements |

**入口**

```bash
make release        # 完整流程（含公证，5-15 分钟）
make release-dry    # 跳过公证（SKIP_NOTARIZE=1，本地干跑验证签名 + DMG，不耗 Apple quota）
```

**链路**（`scripts/release.sh`）

```
xcodebuild archive (Release + Hardened Runtime + manual signing + Developer ID Application)
  → exportArchive (scripts/ExportOptions.plist, method=developer-id, manual signing)
  → codesign --verify --deep --strict 验证
  → create-dmg (volname="Glance 1.0.0", drag-to-Applications layout)
  → xcrun notarytool submit --wait --keychain-profile glance-notary
  → xcrun stapler staple
  → spctl --assess Gatekeeper 验证
  → dist/Glance-1.0.0.dmg + SHA256
```

**首次跑前一次性配置 notarytool**（用户做）：

```bash
# App-specific password 在 https://appleid.apple.com/account/manage 「登录与安全 → App 专用密码」生成
xcrun notarytool store-credentials "glance-notary" \
  --apple-id 16414766@qq.com \
  --team-id 8KW8Z92GRA \
  --password <App-specific password>
```

凭据存入 login keychain，后续 `make release` 自动读，无需再输密码。

**分发渠道**：GitHub Releases（**仓库改 public 后**，DMG 上传 release，README 加下载按钮 + SHA256）

**已完成**

- `38adfd4` BuildVersionInfo（commit hash + sidecar）
- `bd25fd0` 关于面板 Copyright 注入（孙红军 / 16414766@qq.com / 小红书 382336617）
- `8f927d1 + 6f56072 + 09c418c` 自定义关于面板（点击复制 + toast）
- pbxproj 部署目标 26.2 → 14.0 / MARKETING_VERSION 1.0 → 1.0.0 / 加 DEVELOPMENT_TEAM
- `Makefile` 加 `release` / `release-dry` target
- `scripts/release.sh` + `scripts/ExportOptions.plist`
- `.gitignore` 加 `dist/`
- create-dmg via `brew install create-dmg`
- **2026-05-07 session 收口**：notarytool keychain profile 已重存 (5/5 配过但 5/7 ACL 丢失) / 部署目标降级 7 路径 smoke test 全过 / `make release` 真跑成功 (`504c102` 回填 release notes 元数据；公证 Submission ID `cb7db74c-afbb-4e12-98a5-912ca15eefff` Accepted / staple worked / universal binary 三处验证 x86_64+arm64) / `dist/Glance-1.0.0.dmg` 含本 session 6 fix + 真公证 + staple，可发布

**待办（Pending 用户操作 — 全是不可逆）**

- [ ] **DMG 干净 Mac Gatekeeper 实测**（推荐发出去前最后兜底）：把 `dist/Glance-1.0.0.dmg` 拷到一台**不是签名机**的 Mac → 双击挂载 → 拖 .app 到 Applications → 双击启动 → 期望直接打开不弹任何 Gatekeeper 警告
- [ ] **GitHub 仓库 visibility 改 public**（不可逆）：`gh repo edit sunhuaian2026/ISeeImageViewer --visibility public --accept-visibility-change-consequences` 或 GitHub 网页 Settings → Danger Zone
- [ ] **创建 v1.0.0 GitHub Release**（公开可见，不可逆）：`gh release create v1.0.0 dist/Glance-1.0.0.dmg --title "Glance 1.0.0 · 一眼" --notes-file docs/release-notes/v1.0.0.md`
- [ ] 小红书引流到 Release 下载链接（市场推广，可任何时候做）
- [ ] (可选 v1.0.1 cleanup) GitHub 仓库改名 ISeeImageViewer → Glance（GitHub 自动留旧路径 redirect）
- [ ] (可选 v1.0.1 cleanup) `release.sh` L191 `du -h` 取的是 disk usage 而非文件大小，输出 misleading（本次 3.4M vs 实际 2.4 MB），改用 `stat -f %z` 或类似按 byte 格式化

---

## 关键架构决策（新 session 必读）

1. **DesignSystem.swift**：所有 UI 常量的唯一来源，引用 `DS.*`，禁止硬编码。动画常量为 `DS.Anim.fast / normal / slow`（注意：旧名 `DS.Animation` 已废弃）。
2. **PBXFileSystemSynchronizedRootGroup**：`Glance/` 目录下新建 .swift 文件自动加入编译，无需改 xcodeproj。
3. **图片查看两级交互 + QV 入口仲裁**：
   - 单击缩略图 → `folderStore.selectedImageIndex` 被设 → mainContent ZStack 渲染 `ImagePreviewView`（文件名通过 `ImageGridView.navigationTitle` 按 `selectedImageIndex` 动态决定显示在系统 toolbar，不在 `ImagePreviewView` 自身设）
   - 双击缩略图 → onDoubleClick 显式清 `selectedImageIndex = nil` + 设 `quickViewerEntry = .grid` + `quickViewerIndex = idx` → `QuickViewerOverlay` 渲染；关闭后按 entry 路由回 grid（保 `6da903c` 行为不进 preview）
   - 双击内嵌预览图片 → preview onQuickView 设 `quickViewerEntry = .preview` + `quickViewerIndex = idx` → `QuickViewerOverlay` 渲染；关闭后按 entry 路由回 preview，preview 通过 `.id(idx)` 重建显示 QV 浏览到的最后一张图
   - **QV 内方向键 / nav button / filmstrip tap** → `viewModel.currentIndex` 变 → `QuickViewerOverlay` 一处 `onChange(of: viewModel.currentIndex)` 上报 ContentView → 写 `selectedImageIndex` → ImageGridView `onChange(of: selectedImageIndex)` non-nil 分支自动同步 `highlightedURL` → ESC 退 QV 后 grid highlight (`.grid` 入口) / preview (`.preview` 入口) 都跟到当前位置（对齐 Finder Quick Look + Photos.app）
   - **入口来源 enum**：`private enum QuickViewerEntry { case grid, preview }` + `@State quickViewerEntry: QuickViewerEntry?`，dismiss 仲裁按 provenance 路由（`switch quickViewerEntry`），不依赖 `selectedImageIndex` 是否 nil 当哨兵 — 不破坏 `6da903c` 修过的"双击 cell 进 QV 后退出回 grid"
   - **mainContent 渲染条件收紧**：`if let idx = selectedImageIndex, quickViewerIndex == nil { ImagePreviewView(...) }` — QV 期间不渲染 preview，避免 `.id(idx)` 让 preview 在 QV 内方向键改 selectedImageIndex 时整体重建/loadImage
   - **焦点恢复**：QuickViewerOverlay 为 overlay 不会 trigger onAppear；通过 `ContentView.previewFocusTrigger` / `gridFocusTrigger`（UUID）信号驱动子 view onChange 重新 `isFocused = true`，按 `quickViewerEntry` 仲裁路由
4. **QuickViewerOverlay 覆盖方式**：用 `.overlay` 挂在 `NavigationSplitView` 上（不用 ZStack），确保铺满整个内容区。
5. **三栏布局**：`ContentView` = NavigationSplitView（Sidebar） + HStack（Detail + Inspector）。Inspector 用 `⌘I` 切换，宽度 `DS.Inspector.width`（260pt）。Inspector 按钮在无图片选中时禁用；切换文件夹或取消选图时自动关闭 Inspector。
6. **颜色系统**：光晕 `DS.Color.glowPrimary`（紫）/ `glowSecondary`（青绿）。`DS.Color.appBackground` (#121217) / `gridBackground` (#141419) 自 2026-05-06 起 **仅 QuickViewer / ImagePreviewView 引用**（QuickViewer 强制 dark 是设计选择，preview 内嵌底色保留）。FolderSidebarView + ImageGridView **不再** 用这两个值 —— 改让 NavigationSplitView + `listStyle(.sidebar)` 默认行为接管：sidebar 自动 NSVisualEffectView material `.sidebar` + state `.followsWindowActiveState`（失焦自动褪色，跟 Finder/Mail/Notes 一致），内容区用 NavigationSplitView 默认 NSColor.windowBackgroundColor / controlBackgroundColor（dark/light system semantic 派发）。`DS.Color.viewerBackground` 已废弃。
7. **树形侧边栏**：`FolderStore.rootFolders: [FolderNode]`（替代旧 `folders: [URL]`）。`discoverTree(at:)` 递归构建子文件夹树，`countImagesInTree(_:)` 统计各节点图片数。子文件夹继承父文件夹的 Security Scoped Bookmark，无需独立权限。
8. **loadThumbnail()**：定义在 `ImageGridView.swift`，internal 级别，`FilmstripCell` 复用。
9. **AppState**：全局 ObservableObject，持有 `NSWindow` 引用 + `isFullScreen` 状态，通过 `EnvironmentObject` 注入。
10. **构建**：项目根目录有 Makefile，用 `make build` / `make run`。
12. **侧边栏选中高亮**：使用 `List(selection:)` 绑定，完全依赖 macOS 系统渲染。聚焦时显示 Accent Color，失焦时显示灰色——这是 macOS 原生行为（Finder / Notes / 邮件均如此），用于传达键盘焦点所在，不做自定义覆盖。`listRowBackground` 选中行设为 `Color.clear`，让系统选中高亮独立渲染。
13. **AppearanceMode**：外观模式（system/light/dark）存在 `AppState.appearanceMode`，通过 `GlanceApp` 的 `preferredColorScheme` 驱动全局外观。`DS.Color.*` 背景/交互色（`appBackground` / `gridBackground` / `hoverOverlay` / `separatorColor`）为 `AdaptiveColor` 类型，实现 `ShapeStyle.resolve(in:)` 从 `EnvironmentValues` 读取 `colorScheme`——可正确响应 SwiftUI per-view `preferredColorScheme` 覆盖。`glowPrimary` / `glowSecondary` 保持 `SwiftUI.Color`（不需要自适应）。`QuickViewerOverlay` 保留 `.preferredColorScheme(.dark)`，其内部所有 `DS.Color.*` 始终解析为 dark 值。`FolderSidebarView` 移除了旧的 `.environment(\.colorScheme, .dark)`，背景改为 `DS.Color.appBackground` 自适应。`ImagePreviewView` 前景色使用 `Color.primary`（深色模式为白，浅色模式为黑）。

---

### V2 决策（2026-05-06 grill-with-docs 收尾沉淀）

V2 引入跨文件夹聚合（智能文件夹）+ 找回（搜索 + 类似图）。下面 10 条是 V2 设计阶段经过 brainstorming + grill 走完后筛过 "hard-to-reverse + surprising-without-context + real-trade-off" 三标准的决策。术语见 `CONTEXT.md`「跨文件夹聚合」段。

14. **D1 智能文件夹 = rule-based ONLY**：smart folder 永远是 query 结果，不存储 manual membership（不允许"用户拖图进收藏夹"）。Why: "不抢库"哲学红线——一旦引入"V2 自有的图组织数据"，用户卸载 V2 这些信息会丢，跟 Eagle / Photos lock-in 同质。How to apply: M4 用户自定义 smart folder 仍是规则形态，不开"添加图到 collection"接口；未来如有"打标记"诉求，引导用 macOS Finder Tags（OS 级 xattr）而非 V2 内部 DB。

15. **D2 受管文件夹默认全递归 + per-folder hide 剪枝**：V1 已加 root folder 自动纳入智能文件夹扫描范围（半显式）；扫描默认全递归所有子目录；任意 root 或子目录右键可 toggle "在智能文件夹中隐藏"，hide 状态可继承（hide root 默认 hide 整棵树，子目录可单独 unhide 取消继承）。Why: "仅 root 层"在 `类别/年份/` `项目/版本/` 这类常见嵌套素材组织下基本不可用；"glob 黑名单"对普通用户认知门槛过高。How to apply: IndexStore schema 含 `hide_in_smart_view: Bool` 字段（per FolderNode）；扫描时递归过滤；新加 root folder 默认 `hide=false`。

16. **D3 内容去重 = SHA256 + cheap-first 粗筛**：智能文件夹 grid 同字节图只显示一次。先按 `(file_size, format)` 粗筛 → 仅对 size 碰撞的子集算 SHA256（绝大多数图 size 唯一不算哈希）。代表项 = birth time 较早的副本，其他副本在 Inspector 副本段列出。Why: A 不去重首屏被重复图占位（普通用户首屏第一印象差），B/C 误判风险高（同名 size 截图碰撞 / inode 不区分 cp 副本），D 哈希在 cheap-first 优化下成本可控（1 万张图首次索引仅几秒~十几秒额外开销）。How to apply: **只影响 smart folder 呈现**，不影响磁盘真相；用户从 V1 进具体 folder 看仍能看到所有副本。Q4 找回时可加 `duplicates:true` 过滤器（M3 power feature）。

17. **D4 时间分段 5 段自然语言 + 严格午夜对齐**：智能文件夹 grid 时间分段固定 5 段（今天 / 昨天 / 本周 / 本月 / 更早），用 `Calendar.startOfDay` 严格对齐午夜；时区用 device local，不做 UTC 归一化。Why: 段数稳定 5 段不随时间增长（vs 月份分段无限增长，sidebar 滚动疲劳）；"本周/本月" 自动包含更新两段后剩余的图，无 overlap；可预测 > 智能（滚动 24h / 5h 缓冲会引入"为啥这张图不在'今天'了"的隐藏逻辑）。How to apply: V2 spec 定义 `TimeBucket` 枚举 + 边界算法；M3 加"按拍摄时间"smart folder 时单独走 EXIF DateTimeOriginal，不与本规则冲突。

18. **D5 跨 folder 来源标识 = hover tooltip（image viewer convention）**：智能文件夹 grid cell 跟 V1 cell **完全等同**，无来源角标 / 永久标签。鼠标 hover 显示 tooltip = 完整 relative path；点进 Quick Viewer 后 Inspector 永久显示绝对 path + "Show in Finder"按钮。Why: image 是视觉本体（缩略图本身就是身份），不像 note 依赖 folder context；Photos / Eagle / Lightroom 行业 convention 一致 hide-from-cell（Apple Notes 路线机械搬过来不适用）；保持 V1 视觉密度。How to apply: V2 不做"smart folder cell 加 folder name 行" / "缩略图角标 emoji" 类视觉装饰；以信息密度优先 + 行业 convention 优先。

19. **D6 规则引擎 = Spotlight-like AND/OR 平铺**：smart folder 规则支持 `字段 OP 值` 条件 + AND/OR 二层平铺组合（无嵌套，无 NOT）。Why: 内置 smart folder（"截图" / "大图"）需要 OR（如 `filename CONTAINS "Screenshot" OR path STARTS_WITH ~/Desktop`），仅 AND 表达不了；嵌套 GUI 编辑器（NSPredicate-shape）对普通用户认知门槛陡，普通用户已熟悉 Spotlight / Finder 智能文件夹的"任一/全部"切换 UI。NOT 在 GUI 上反直觉（"看不是 PNG 的图"普通用户更习惯说"看 JPEG / HEIC / RAW"）。How to apply: 规则 JSON 格式 day-1 设计成兼容嵌套（`{op: AND, children: [...]}` 树形结构），未来扩展 GUI 可吃嵌套时数据无需迁移。

20. **D7 IndexStore = forward-looking schema + 增量 ALTER TABLE 迁移**：M1 一次性 ship M1-M3 已知字段（M1 用 birth_time / file_size / format / filename / relative_path / folder_id / dimensions / content_sha256 / dedup_canonical；M2 加 feature_print / revision / supports_feature_print；M3 加 exif_capture_date 等）。存 `~/Library/Application Support/Glance/index.sqlite`。Schema 版本变化走 ALTER TABLE ADD COLUMN（老数据 NULL，后台 lazy 补）；迁移失败 fallback full re-index。Vision feature print revision 单独追踪：macOS 升级 revision 不匹配仅 re-index 该列。Why: 反复 ALTER TABLE 比一次 forward-looking 风险低；feature print 的 revision 解耦让 macOS 升级不污染其他字段。How to apply: M1 schema 设计阶段考虑 M2-M3 字段；migration 测试覆盖三个场景（v1→v2 增字段 / Vision revision 变 / migration 失败 fallback）。

21. **D8 搜索 / 类似图结果 = ephemeral 视图**：⌘F 搜索结果 + Quick Viewer "找类似" 结果**不**作为持久 entry 进 sidebar，仅切换主 grid 显示；ESC / 切换 sidebar entry / 关闭 Quick Viewer 即取消。提供"保存为智能文件夹"按钮（M3+，把当前搜索条件转成自定义 smart folder 持久化）。Why: sidebar 累积搜索历史会成为噪音（用户每次 ⌘F 都长一条 entry）；ephemeral 模式跟用户对"搜索是临时操作"的直觉一致。How to apply: 搜索/相似图 UI 用同一 `EphemeralResultView` 组件（统一返回路径与状态管理）；"保存为" 按钮 M1/M2 不上 M3 才上。

22. **D9 V2 timeline = 13-15 周 + 每 milestone 跟一个 minor 版本**：M1 4-5 周 / M2 3 周 / M3 3-4 周 / M4 2-2.5 周（M4 optional）。每 milestone 完成跟一个 minor 版本发布（M1 → V2.0-beta1，M2 → V2.1，M3 → V2.2，M4 → V2.3），不等全部 M1-M4 完成才发 V2 大版本。每个 milestone 是端到端 vertical slice（端到端可跑 + 用户可感知 + 独立可 ship）。Why: 横切式拆分把集成 bug 全推到末尾爆雷；vertical slice 让风险前置 + 用户每片都有可感知收益 + 反馈密度比 3 个月一次大版本高得多。How to apply: 写 implementation plan 时每个 milestone 验证三标准（可跑 / 可感知 / 可 ship）；不达标的切片要重组。

23. **D10 V2 scope freeze（18 项 explicit "不做"清单）**：culling 工作流 / tag 标签系统 / color palette / 自然语言搜索（CLIP）/ "已读未读" seen-state / 跨设备同步 / 导入到自有库 / 编辑调色旋转写回 / NSPredicate 嵌套规则 / NOT operator / glob 黑名单 / 视频动图 LivePhoto 索引 / iCloud Drive placeholder + 网络盘 + 外接设备 / OCR 文本搜索 / Photos Memories 智能相册推荐 / Favorites 收藏 Star ratings / 多 library 切换 / EXIF metadata 写回——共 18 项 V2 范围外。Why: 每项都有 brainstorming + grill 阶段的明确 trade-off 推演（详见 V2 spec 不做段）；scope freeze 是单人项目按时 ship 的核心保障。How to apply: 收到"V2 能不能加 X"诉求时先查这 18 条；命中即拒（refer 到此条），不命中再走"加新 feature 决策流程"。

---

## V2 进度

### M1 - 跨文件夹聚合 MVP（4-5 周）

| Slice | 状态 | Ship as | 完成日期 | 关键 commit |
|---|---|---|---|---|
| **A** ⭐ thin cross-folder MVP | ✅ 完成 | V2.0-beta1 | 2026-05-08 | 见下方表格 |
| B 时间分段 sticky header（5 段 chip）+ "本周新增" SF + hover tooltip | ✅ 完成 | V2.0-beta2 | 2026-05-09 | 见下方 Slice B 表 |
| D hide toggle 右键菜单（root + 子目录 + 状态继承）+ Inspector source path | ✅ 完成 | V2.0-beta3 | 2026-05-09 | 见下方 Slice D 表 |
| G FSEvents 增量监听 + 删 root folder 清理 | ✅ 完成 | V2.0-beta4 | 2026-05-09 | 见下方 Slice G 表 |
| H 内容去重 SHA256 + cheap-first 粗筛 | ⏳ 未开始 | V2.0-beta5 | — | — |
| I 首次索引进度 UI + 错误处理 + SmartFolderStore enum-state 重构 | ⏳ 未开始 | V2.0 RC + GA | — | — |

### Slice A 完成详细（19 task）

**完成 commit 列表**（按时序，对应 plan task 编号）：

| Task | Goal | Commit |
|---|---|---|
| A.1 | IndexDatabase sqlite3 thin wrapper | `01f2b4b` |
| A.2 | IndexStoreSchema v1 forward-looking | `d7ad2b0` |
| A.3 | IndexStore high-level entry + auto-migrate | `de802b7` |
| A.4 | ManagedFolder + folders 表 CRUD | `be9f9fe` |
| A.5 | IndexedImage + images 表 CRUD + CompiledSmartFolderQuery | `8a08327` |
| A.6 | ImageMetadataReader（URL → birth_time/size/format/dimensions）| `fb085ba` |
| A.7 | FolderScanner（递归扫描 + 写入 IndexStore）| `5ce3b2a` |
| A.8 | SmartFolder + Predicate/Atom/Op/Value structs | `c681e9a` |
| A.9 | SmartFolderQueryBuilder（Predicate → SQL）| `f47b2a1` |
| A.10 | SmartFolderEngine（compile + execute）| `c47ae25` |
| A.11 | BuiltInSmartFolders（"全部最近"）| `603383b` |
| A.12 | SmartFolderStore @MainActor + 项目级 nonisolated retrofit | `c6e600f` |
| **merge** | merge main → v2/dev（V1 bug fix 21 commits 拉进来）| `86b2a24` |
| - | verify.sh allow-list 加 SQLite3（macOS 系统 framework）| `1fc32d9` |
| - | M1 plan A.13/A.17 reality check 重跑（merge 后修订 V1 现状假设）| `c5d73a8` |
| A.13 | GlanceApp 注入 IndexStoreHolder | `b49feb7` |
| A.14 | FolderStoreIndexBridge（订阅 rootFolders + 注册 + scan）| `1600a99` |
| A.15 | SmartFolderListView（sidebar 智能文件夹 UI）| `536b0fe` |
| A.16 | SmartFolderGridView（cross-folder grid + V1 loadThumbnail 复用）| `6449552` |
| A.17 | ContentView 改造（sidebar VStack + V2 wire-up + EnvironmentObject 双注入）| `879078f` |
| A.17 P3 | codex review 修法（Preview env 注入 + stale query guard）| `557bb39` |
| A.18 P0 | insertImageIfAbsent SELECT-first（让 constraint violation 真实 surface 取代 OR IGNORE 静默吞）| `f83cc9b` |
| A.18 P0 | root bookmark 替代 per-child bookmark（macOS sandbox 不允许给 enumerator 子文件创建 .withSecurityScope bookmark）| `7ef8d81` |
| A.18 follow-up | V2 grid 加最小交互（单击预览 / 双击 QuickViewer）| `a9b3ac2` |
| A.18 follow-up | V2 grid 加 navigationTitle / highlight + v2Urls 替代 folderStore.images | `26c457a` |
| A.18 P0 | QV transition insertion 改 .identity 消除 baseGrid 暴露（codex:rescue 真根因 fix，前 2 次诊断错）| `553c0f6` |
| A.18 follow-up | V2 grid 加 keyboard 支持（mirror V1 ImageGridView：focus / arrow / space / F）| `9ea131e` |
| A.18 P1 | inspectorURL V2 mode 用 v2Urls 替代 folderStore.images（v2Urls 拆分后 Inspector 显空）| `2dd7c1b` |
| A.18 follow-up | V2 cell 视觉对齐 V1 ThumbnailCell（方形 + scaledToFill + hover scale + HiDPI）| `6da2689` |
| A.19 | Slice A 收尾 + Roadmap + PENDING + 完整 commit | （本次）|

### Slice A 关键技术决策（实施过程沉淀）

**1. P0 P0：bookmark sandbox 限制**
sandbox app 不允许给 enumerator 出来的子 URL 创建 `.withSecurityScope` bookmark（子 URL 仅通过 active 父 scope 隐式访问）。结果：FolderScanner 不能给每个 image 单独存 bookmark，全部 image row 共享所属 root 的 bookmark；读图时 resolve(rootBookmark) → startAccessing → root.appendingPathComponent(relative_path) 重建子 URL。`IndexedImage.urlBookmark` 字段语义从"image 自己的 bookmark"变成"image 所在 root 的 bookmark"，字段名 Slice I rename 候选。

**2. INSERT OR IGNORE 不能给 schema 用**
SQLite OR IGNORE 吞掉所有 constraint violation（NOT NULL / FK / CHECK / UNIQUE），不只是 UNIQUE 冲突。诊断错误时混淆"行不存在"vs"行被 IGNORE"。修法：SELECT-first → INSERT (no IGNORE) 让真实错误 surface + 错误消息加 record dump（folder_id / relative_path / filename / format / file_size / bookmark_size）。

**3. V1/V2 双源耦合 trade-off**
ImagePreviewView / QuickViewerOverlay / Inspector 在 V2 mode 用 ContentView 本地 `@State v2Urls`，V1 mode 用 `folderStore.images`，避开 V1 排序保护逻辑（onChange of images → 关 QV）误关 V2 QV。Slice I 重构候选：让这些 view 不直接依赖 folderStore.images，完全走显式参数。

**4. SwiftUI transition 时序导致视觉闪烁**
QuickViewer 用 `.transition(.opacity)` fade in 跟 preview 同时退场，中间时间窗口 baseGrid 透过两层半透明暴露。修法：QV insertion 改 `.identity`（即时出现）+ removal 保留 `.opacity`（fade out）。codex:rescue 独立 trace 发现的根因，前 2 次自诊断走偏教训：bug 修 ≥2 次必须 codex:rescue review。

**5. V2 grid 视觉/交互完整 mirror V1 ImageGridView**
A.18 实测发现 plan A.16 把 V2 cell 标"无交互"导致用户测不下去，且 V2 cell aspectRatio.fit + 矩形不规则视觉割裂感强。修法：单击/双击 + navigationTitle + highlight + keyboard + scaledToFill 方形 + hover scale + HiDPI 像素，全部 mirror V1 ThumbnailCell pattern；共享 `folderStore.thumbnailSize` 让 V1 toolbar slider 同步控制 V2 cell 大小。

### Slice A 累积模型（V2.0-beta1 deliverables）

- 1 个内置 SmartFolder："全部最近"（rule：managed=true AND hidden=false AND dedupCanonicalOrNull=true，order: birth_time desc）
- 1 个 cross-folder grid view（SmartFolderGridView）+ 1 个 sidebar UI（SmartFolderListView）
- IndexStore 持久化：~/Library/Containers/com.sunhongjun.glance/Data/Library/Application Support/Glance/index.sqlite
- folders 表 + images 表（v1 schema 含 M1+M2+M3 forward-looking 字段）+ 5 个 index
- FolderScanner 单次递归扫描（无 FSEvents 增量，Slice G 才上）
- V1/V2 selection 互斥 + V2 keyboard 完整支持 + Inspector 共享路径
- **不含**：时间分段 sticky header（B）/ hide toggle 菜单（D）/ FSEvents（G）/ dedup（H）/ 进度 UI（I）

### Slice B 进度（合并 B + C + E，ship → V2.0-beta2）

| Sub | Goal | 状态 | Commit |
|---|---|---|---|
| B-α | TimeBucket（5 段算法）+ SmartFolderGridView LazyVGrid sectioned + sticky pinnedViews + chip section header（Capsule + thickMaterial + strokeBorder） | ✅ 完成 | `25d6a94`（主体）；4 轮 follow-up：`60a2de2` 黑横条 / `bd4cfa7` ↑↓+hit-test+P1 / `c5b048a` chip 形态破横条 / `ef08f72` chip 对比强化 + DS.SectionHeader |
| B-β | BuiltInSmartFolders 加 thisWeekAdded（规则：managed AND !hidden AND dedupCanonical AND birth_time BETWEEN_DURATION ['-7d','now']）+ sidebar 自动出现 | ✅ 完成 | `7e2893a` |
| B-γ | /go 五步收尾 + Roadmap ✅ + tag V2.0-beta2 | ✅ 完成 | `cf43e04` |

### Slice D 进度（合并 D + F，ship → V2.0-beta3）

| Sub | Goal | 状态 | Commit |
|---|---|---|---|
| D.1 | hide toggle 端到端：IndexStore CRUD（setRootHidden / upsertSubfolderHide / effectiveHidden / folderIdForRootPath）+ SmartFolderQueryBuilder `.hidden` walk SQL（path-length DESC 取最具体 explicit）+ FolderSidebarView contextMenu（root + 子目录两层动态 label）+ ContentView 桥（V1 URL → IndexStore 坐标） | ✅ 完成 | `a39a6c5`（主体）+ `4f318b5`（P1+P2 fix：ON CONFLICT WHERE 子句 + 嵌套 root 最长前缀 + Roadmap 当前进度同步）+ `6d8d234`（Bug Fix 段同步） |
| D.2 | Inspector 来源 path 段 + Show in Finder 按钮 | ✅ 完成 | `a576198`（主体）+ `e073001`（Inspector.md spec 同步） |
| D.3 | /go 五步 + Roadmap ✅ + tag V2.0-beta3 | ✅ 完成 | `94eb6fb` |

### Slice G 进度（FSEvents 增量监听 + 删 root 清理，ship → V2.0-beta4）

| Sub | Goal | 状态 | Commit |
|---|---|---|---|
| G.1 | 删 root 清理：IndexStore.deleteRoot（FK CASCADE 连删 images + subfolder hide rows）+ FolderStoreIndexBridge.sync 加 remove diff | ✅ 完成 | _本 commit_ |
| G.2 | FSEventsWatcher Swift wrapper（CoreServices FSEventStreamCreate）+ 每 root 一个 stream lifecycle + ItemCreated → insertImageIfAbsent | ✅ 完成 | _本 commit_ |
| G.3 | FSEvents Removed → deleteImage / Modified → updateImageMetadata / Renamed → 按 file exists 拆 delete + insert | ✅ 完成 | _本 commit_ |
| G.4 | /go 五步 + Roadmap ✅ + tag V2.0-beta4 | ✅ 完成 | _本 commit_ |

**Slice G 关键决策**（4 项 plan-time 拍板，全 OK）：
- FSEvents stream lifecycle：每 root 一个 stream（删 root 单独 invalidate）
- callback 线程模型：watcherQueue 派发 → Task @MainActor → IndexStore serial queue → onIndexChanged → SmartFolderStore.refreshSelected
- modify 处理粒度：仅 metadata UPDATE（content_sha256 / dedup_canonical 是 Slice H 字段保留 NULL）
- rename 行为：delete old + insert new（不追踪 inode dedup，Slice H SHA256 后副本检测自动 link）

**Slice D 关键决策**（4 项细节执行时拍板，全 OK）：
- 稀疏 explicit 模型：folders 表只对显式设过 hide 的目录存 row（root 行 register 时已存）；未 explicit 的目录读 default 0
- toggle 二态语义：toggle hide/unhide 切换，row 始终保留；无第三态"重置为继承"
- subfolder lazy insert：首次右键子目录 toggle → IndexStore upsertSubfolderHide 写入新 row（ON CONFLICT update）
- menu label 动态文案：当前 effective hidden → "在智能文件夹中显示" / 否则 "在智能文件夹中隐藏"

**Slice B-α 关键决策**（执行时拍板，全 A）：
- bucket 归属计算：客户端单遍 group（O(n)，queryResult 已 birth DESC）
- sticky 实现：`LazyVGrid(pinnedViews: [.sectionHeaders])` 原生
- 空段处理：完全隐藏（today/yesterday/thisWeek/thisMonth/earlier 动态 0-5 段）
- 跨 bucket 键盘导航：保留 colCount-based flat queryResult 算法不动（视觉分组不影响 ↑↓ 步长）
- "本周新增"边界：`-7d/now` 滑窗（spec 已定，与 D4 自然周"本周"段双轨语义清晰）

