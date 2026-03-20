# ISeeImageViewer Roadmap

## 总体目标

打造一款 macOS 原生风格、界面精致的本地看图 app，上架 App Store。

---

## 当前进度（2026-03-20）

**所有模块已完成，待上架 App Store**

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
| FullScreen | FullScreen.md | 0abcae6 | NSWindow.toggleFullScreen，F 键切换，NSWindowDelegate 监听 |

---

## 待开发

| 阶段 | 模块 | Spec | 优先级 | 前置依赖 |
|------|------|------|--------|----------|
（无待开发模块）

---

## 关键架构决策（新 session 必读）

1. **DesignSystem.swift**：所有 UI 常量的唯一来源，引用 `DS.*`，禁止硬编码。
2. **PBXFileSystemSynchronizedRootGroup**：`ISeeImageViewer/` 目录下新建 .swift 文件自动加入编译，无需改 xcodeproj。
3. **三栏布局**：`ContentView` = NavigationSplitView（Sidebar） + HStack（Detail + Inspector）。Inspector 用 `⌘I` 切换，宽度 260pt。
4. **看图界面**：`DS.Color.viewerBackground`（#1A1A1A）纯深色，`preferredColorScheme(.dark)`，禁止 spring 动画。
5. **loadThumbnail()**：定义在 `ImageGridView.swift`，internal 级别，`FilmstripCell` 复用。
6. **构建**：项目根目录有 Makefile，用 `make build` / `make run`。

---

## 开发顺序说明

- Phase 2 两个模块互相独立，可在同一 session 内完成
- Phase 3 Inspector 依赖 Phase 1 三栏布局（已就位，右栏有 `InspectorPlaceholderView` 占位）
- Phase 4 全屏完全独立，最后做
