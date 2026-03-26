# ISeeImageViewer Roadmap

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
| TBD | 排序后缩略图显示错误：`ForEach` 用 `id: \.element`（URL）但 VStack 上的 `.id(index)` 覆盖了视图身份为位置索引；排序后 SwiftUI 复用同位置视图，`@State thumbnail` 残留旧图；改为 `.id(url)` + `scrollTo(folderStore.images[next])` 修复 |

---

## 待修复 Bug

| 状态 | 模块 | 问题描述 | 已知信息 |
|------|------|----------|----------|

## 待开发

| 阶段 | 模块 | Spec | 优先级 | 前置依赖 |
|------|------|------|--------|----------|
（无）

---

## 关键架构决策（新 session 必读）

1. **DesignSystem.swift**：所有 UI 常量的唯一来源，引用 `DS.*`，禁止硬编码。动画常量为 `DS.Anim.fast / normal / slow`（注意：旧名 `DS.Animation` 已废弃）。
2. **PBXFileSystemSynchronizedRootGroup**：`ISeeImageViewer/` 目录下新建 .swift 文件自动加入编译，无需改 xcodeproj。
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
13. **AppearanceMode**：外观模式（system/light/dark）存在 `AppState.appearanceMode`，通过 `ISeeImageViewerApp` 的 `preferredColorScheme` 驱动全局外观。`DS.Color.*` 背景/交互色（`appBackground` / `gridBackground` / `hoverOverlay` / `separatorColor`）为 `AdaptiveColor` 类型，实现 `ShapeStyle.resolve(in:)` 从 `EnvironmentValues` 读取 `colorScheme`——可正确响应 SwiftUI per-view `preferredColorScheme` 覆盖。`glowPrimary` / `glowSecondary` 保持 `SwiftUI.Color`（不需要自适应）。`QuickViewerOverlay` 保留 `.preferredColorScheme(.dark)`，其内部所有 `DS.Color.*` 始终解析为 dark 值。`FolderSidebarView` 移除了旧的 `.environment(\.colorScheme, .dark)`，背景改为 `DS.Color.appBackground` 自适应。`ImagePreviewView` 前景色使用 `Color.primary`（深色模式为白，浅色模式为黑）。
