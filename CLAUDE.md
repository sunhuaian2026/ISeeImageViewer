这是一个 macOS 本地看图 app，SwiftUI 开发，目标上架 App Store。
核心功能是本地文件夹浏览和图片查看。
需要遵守 App Sandbox 限制，使用 Security Scoped Bookmark 处理文件权限。

---

## 项目文件结构

```
ISeeImageViewer/
├── CLAUDE.md                        ← 本文件（开发规范 + 上下文）
├── Makefile                         ← make build / make run / make clean
├── ISeeImageViewer.xcodeproj/
├── specs/                           ← 所有模块规范文档
│   ├── UI.md                        ← UI 设计规范（唯一来源）
│   ├── Roadmap.md                   ← 总体进度与 TODO
│   ├── BookmarkManager.md
│   ├── FolderStore.md
│   ├── FolderBrowserView.md
│   ├── ImageViewerView.md
│   ├── UIRefresh.md                 ← ✅ 已完成
│   ├── SortFilter.md                ← ⏳ Phase 2 下一步
│   ├── KeyboardShortcuts.md         ← ⏳ Phase 2
│   ├── Inspector.md                 ← ⏳ Phase 3
│   └── FullScreen.md                ← ⏳ Phase 4
└── ISeeImageViewer/                 ← Swift 源码（PBXFileSystemSynchronizedRootGroup，新文件自动加入编译）
    ├── ISeeImageViewerApp.swift
    ├── ContentView.swift            ← 三栏布局（Sidebar + Detail + Inspector）
    ├── DesignSystem.swift           ← DS.Spacing / DS.Color / DS.Animation 等所有 UI 常量
    ├── InspectorPlaceholderView.swift
    ├── BookmarkManager.swift
    ├── FolderBrowser/
    │   ├── FolderStore.swift        ← 状态管理（文件夹、图片列表、排序）
    │   ├── FolderSidebarView.swift  ← 侧边栏（badge、右键菜单）
    │   └── ImageGridView.swift      ← 缩略图网格 + ThumbnailCell + loadThumbnail()
    └── ImageViewer/
        ├── ImageViewerViewModel.swift
        └── ImageViewerView.swift    ← 看图界面 + FilmstripCell + 自动隐藏控件
```

---

## 开发规范

- 所有模块开发前必须有对应的 specs/ 文件。
- **新开 session 第一步**：读取 CLAUDE.md + specs/Roadmap.md 恢复上下文。
- 开发环境为远程 Mac，无法使用 Xcode GUI。所有编译和验证使用命令行。
- 构建命令：`make build`（在 ISeeImageViewer/ 目录下）
- 运行命令：`make run`
- 清理命令：`make clean`

## UI 规范

- **所有 UI 常量必须引用 DesignSystem.swift（DS.*）**，禁止硬编码颜色、间距、动画。
- 详细规范见 specs/UI.md。
- 核心原则：内容优先、克制、原生、深色优先。
- 看图界面强制深色（`.preferredColorScheme(.dark)`），不加装饰性元素。
- 禁止在看图界面使用 `.spring` 动画，用 `DS.Animation.normal / fast`。

## 持久化规范

- 每次计划生成后，立刻将计划追加到对应的 specs/[模块名].md 的「实现步骤」章节。
- 每个模块完成后立刻 git commit，commit message 格式：「完成 [模块名]」。
- 每次 session 结束前，更新 specs/[模块名].md 里的「当前进度：第 X 步已完成」，并更新 specs/Roadmap.md。
- xcodeproj 使用 PBXFileSystemSynchronizedRootGroup，在 ISeeImageViewer/ 目录下新建 .swift 文件会自动被编译，无需手改 xcodeproj。

## 验证与 Review 规范

- 每个模块实现完成后，必须先执行 `make build`，确认零错误零警告再提交。
- 编译通过后，对照 specs/[模块名].md 逐条检查接口和边界条件是否都已实现。
- 发现与 spec 不符的地方，先修复再 commit，不允许带问题提交。
- 每次 commit 前做一次自我 review：检查有没有硬编码、未处理的错误、遗漏的边界条件。
