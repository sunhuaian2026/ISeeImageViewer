# ISeeImageViewer Roadmap

## 总体目标

打造一款 macOS 原生风格、界面精致的本地看图 app，上架 App Store。

## 已完成

| 模块 | Commit | 状态 |
|------|--------|------|
| BookmarkManager | d88baa0 | ✅ |
| FolderStore | d88baa0 | ✅ |
| FolderSidebarView + ImageGridView | d88baa0 / 9963fca | ✅ |
| ImageViewerView | d88baa0 / 9963fca | ✅ |

## 待开发（按优先级）

| 阶段 | 模块 | Spec 文件 | 优先级 |
|------|------|-----------|--------|
| Phase 1 | UI Refresh（混合方案 A+B+C） | specs/UIRefresh.md | P0 |
| Phase 2 | 图片排序 / 过滤 | specs/SortFilter.md | P1 |
| Phase 2 | 键盘快捷键完善 | specs/KeyboardShortcuts.md | P1 |
| Phase 3 | EXIF 元信息 Inspector 面板 | specs/Inspector.md | P2 |
| Phase 4 | 全屏模式 | specs/FullScreen.md | P2 |

## 开发顺序说明

1. **Phase 1 UI Refresh 优先**：三栏布局、动画、自动隐藏控件是后续所有功能的视觉基础
2. **Phase 2 并行**：排序/过滤和键盘快捷键互相独立，可同 session 完成
3. **Phase 3 Inspector**：依赖三栏布局（Phase 1 右栏），Phase 1 完成后开发
4. **Phase 4 全屏**：独立功能，排最后
