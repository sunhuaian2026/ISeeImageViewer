# CONTEXT — Glance · 一眼

> 本文件存放项目领域语言（术语表）+ 架构总览。
> **决策**写 `specs/Roadmap.md`「关键架构决策」段（不在此处沉淀）。
> **模块细节**看 `specs/<module>.md`。**进度**看 `specs/Roadmap.md`。**人工测试队列**看 `specs/PENDING-USER-ACTIONS.md`。

---

## 项目一句话

macOS 本地看图 app，SwiftUI 实现，沙盒 + Security Scoped Bookmark，针对单人本地素材浏览场景，深色优先、内容优先、零第三方依赖。

---

## 领域术语表

新术语首次出现先在此登记，再用于代码 / specs / commit message。命名冲突时本表为准。

### 状态与持久化

- **AppState** — 全局 UI 状态（`isFullScreen` / `appearanceMode`）。`@StateObject` 注入根 view。
- **FolderStore** — 文件夹/图片状态管理（`FolderNode` 树、当前图片列表、排序）。`@StateObject` 在 `GlanceApp`。
- **BookmarkManager** — Security Scoped Bookmark 持久化与解析层；处理沙盒文件权限授权与跨 session 恢复。
- **FolderNode** — 文件夹树节点（递归结构 + 展开/折叠态 + badge 数）。
- **Security Scoped Bookmark** — macOS 沙盒下持久化文件访问权限的唯一手段；解析时必须 `startAccessingSecurityScopedResource()` 配对 stop。

### 看图核心

- **Image Preview** — 单击缩略图进入的内嵌预览视图（`ImagePreviewView`）；轻量、跟随全局外观；双击触发 Quick Viewer。
- **Quick Viewer** — 双击进入的全窗口看图覆盖层（`QuickViewerOverlay`）；强制深色、提供完整缩放/导航/Filmstrip/Inspector 入口。
- **ZoomMode** — Quick Viewer 缩放模式枚举（fit / 100% / custom）；驱动 `ZoomScrollView` 行为。
- **Filmstrip** — Quick Viewer 底部缩略图条，横滑切图。
- **Inspector** — 图片信息侧栏（EXIF / 尺寸 / 文件元数据），可在 Quick Viewer 内调出。
- **Prefetch ±1** — 预览/Quick Viewer 当前索引相邻 ±1 图的预加载缓存策略，目的是方向键切换零延迟。

### UI 系统

- **DesignSystem (DS.*)** — 所有 UI 常量唯一来源（`DS.Spacing` / `DS.Color` / `DS.Anim`）；硬编码颜色 / 间距 / 动画一律拒绝。
- **Traffic Light Hide** — 全屏/沉浸模式下隐藏窗口左上红黄绿按钮的策略。

### 已知陷阱（曾踩过的坑，命名以方便引用）

- **`.id(idx)` 重建陷阱** — SwiftUI 的 `.id(x)` 修饰符会在 `x` 变化时销毁重建整个 subtree，连带销毁 `@StateObject`。任何跨 idx 切换需要持久的状态（cache / prefetch / 长任务）必须由父 view 持有 `@StateObject`、子 view 用 `@ObservedObject`。`ContentView` 对 `ImagePreviewView` 加过 `.id(idx)`，因此 `ImagePreviewViewModel` 由父持有。`QuickViewerOverlay` 没有 `.id`，子内 `@StateObject` OK。

---

## 架构总览

```
┌────────────────────────────────────────────────┐
│ GlanceApp（注入 BookmarkManager / FolderStore  │
│            / AppState 三个 @StateObject）       │
└────────────────────┬───────────────────────────┘
                     │
              ContentView  (NavigationSplitView)
              ├─ FolderSidebarView   (FolderNode 树 + 拖拽添加)
              ├─ ImageGridView       (缩略图网格 + ThumbnailCell)
              └─ Overlay 层
                  ├─ ImagePreviewView      (单击触发，跟随外观)
                  └─ QuickViewerOverlay    (双击触发，强制深色)
                      ├─ ZoomScrollView    (NSViewRepresentable)
                      ├─ Filmstrip
                      └─ ImageInspectorView (EXIF Form)
```

**层次划分**：
- **状态层**：AppState / FolderStore / BookmarkManager（三个 @StateObject，`GlanceApp` 注入）
- **View 层**：ContentView（split）+ Overlay（Image Preview / Quick Viewer）+ Sidebar / Grid / Inspector
- **桥接层**：`WindowAccessor`（NSViewRepresentable，拿 NSWindow + 装 NSWindowDelegate）/ `ZoomScrollView`（NSViewRepresentable，包 NSScrollView 处理滚轮+双击+拖拽）
- **持久化层**：Security Scoped Bookmark（文件权限）+ UserDefaults（外观模式 / 排序偏好等）

**编译 / 文件系统约定**：
- `Glance/` 目录用 `PBXFileSystemSynchronizedRootGroup`，新建 `.swift` 文件自动加入编译，无需手改 `xcodeproj`。
- 所有编译/运行/验证走命令行（Makefile + `scripts/verify.sh`），GUI Xcode 仅作 pbxproj 损坏救场用。

---

## 不在本文件管的

- **决策**（架构选型、不可逆操作记录、为什么这么做）→ `specs/Roadmap.md`「关键架构决策」段
- **进度**（哪些模块完成、Bug Fix 记录）→ `specs/Roadmap.md`
- **模块接口/实现细节** → `specs/<module>.md`
- **人工测试 backlog** → `specs/PENDING-USER-ACTIONS.md`
- **UI 规范** → `specs/UI.md`
