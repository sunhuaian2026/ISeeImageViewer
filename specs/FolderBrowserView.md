# FolderBrowserView Spec

## 布局

`ContentView` 使用 `NavigationSplitView`：
- **Sidebar**：`FolderSidebarView` — 文件夹列表
- **Detail**：
  - 有 `selectedImageIndex` → 显示 `ImageViewerView`
  - 无 → 显示 `ImageGridView`

## FolderSidebarView

- `List` 展示 `folderStore.folders`，单选高亮
- 每行显示 `folder.lastPathComponent` + 文件夹图标
- Toolbar 上方 "+" 按钮：调用 `folderStore.addFolder()`
- 右键菜单：`移除文件夹` → `folderStore.removeFolder(url)`
- 点击文件夹行 → `folderStore.selectFolder(url)`

## ImageGridView

- 无 selectedFolder：`ContentUnavailableView`
- 加载中：`ProgressView`
- 空文件夹：`ContentUnavailableView`
- 有图片：`LazyVGrid(columns: .adaptive(minimum: 160, maximum: 200))`

### ThumbnailCell

- 150×150 pt 固定尺寸
- 异步加载：`CGImageSourceCreateThumbnailAtIndex`（最大 200px，嵌入缩略图优先）
- 加载中显示 `ProgressView` + 灰色背景
- `.task` 修饰符异步加载，view 销毁时自动取消
- 鼠标悬停高亮，**双击**触发 `folderStore.selectedImageIndex = index`

## 当前实现状态（截至 2026-03-19）

- ✅ FolderSidebarView：List 级 contextMenu「添加文件夹…」
- ✅ FolderSidebarView：行级 contextMenu「在 Finder 中显示 / 移除文件夹」
- ✅ ImageGridView 空状态：contextMenu「添加文件夹…」（Color.primary.opacity(0.001) 修复）
- ✅ 双击缩略图进入查看器（已从单击改为双击）
- ❌ 文件夹 badge（待 UIRefresh Phase 1）
- ❌ 排序控件（待 SortFilter Phase 2）
- ❌ 缩略图 180×180 + 文件名（待 UIRefresh Phase 1）

## 拖拽添加文件夹（Finder → Sidebar）

用户从 Finder 拖拽一个或多个文件夹到 `FolderSidebarView` 区域，等同于点击工具栏 "+" 后选择该文件夹。

### Drop Target
`FolderSidebarView` 的 `ZStack` 整块（侧边栏所有视觉区域，含光晕和 List）。右侧内容区（ImageGridView / ImagePreviewView）不响应。

### Payload 过滤
- 拖入 payload 使用 SwiftUI `.dropDestination(for: URL.self)` 接收
- 仅 `url.hasDirectoryPath == true` 的条目进入 FolderStore；非目录（文件、指向文件的符号链接）静默忽略，不报错、不反馈失败动画
- 返回 `true` 接受 drop（即使最终过滤后为空），保持 Finder 动画一致

### 视觉反馈
`@State var isDropTargeted` 绑定到 `.dropDestination` 的 `isTargeted:` 回调。为 true 时在 ZStack 上 overlay 一个紫色描边矩形：

| 属性 | DS 常量 | 值 |
|---|---|---|
| 颜色 | `DS.Color.glowPrimary.opacity(DS.Sidebar.dropBorderOpacity)` | 紫 × 0.45 |
| 线宽 | `DS.Sidebar.dropBorderWidth` | 2pt |
| 圆角 | `DS.Sidebar.dropBorderCornerRadius` | 10pt |
| 内边距 | `DS.Sidebar.dropBorderPadding` | 4pt |
| 淡入/淡出 | `DS.Anim.fast` | 0.15s easeInOut |

### FolderStore 入口
- `addFolder()` —— NSOpenPanel 入口（Toolbar "+" 按钮、contextMenu 调）
- `addFolder(from url: URL, autoSelect: Bool = true)` —— 单 URL 入口（拖拽或程序调用）
  - `hasDirectoryPath` 必须 true，否则静默返回
  - 已存在于 `rootFolders` 则视 `autoSelect` 决定是否跳到选中
  - 新文件夹走完整流程：`BookmarkManager.saveBookmark` → `startAccessing` → `discoverTree` → `rootFolders.append + sort` → `countImagesInTree` → 可选 `selectFolder`
- `addFolders(from urls: [URL])` —— 批量入口（拖拽多文件夹）
  - 过滤出 `hasDirectoryPath == true` 的条目
  - 0 个：return；1 个：auto-select 的 `addFolder(from:)`；≥2 个：循环 `autoSelect: false`，保留当前选择避免焦点跳
- `FolderSidebarView.dropDestination` 的回调统一走 `addFolders(from:)`

### Security Scope
Finder 拖入 sandboxed app 的 URL 自带用户授权，可直接调用 `url.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess])` 持久化。复用 `BookmarkManager.saveBookmark`，路径与 panel 选择完全一致。

### 不做
- 拖拽到 ImageGridView 内容区：无响应（范围选择 A）
- 空状态 welcome 页的大 drop zone：暂不做（可后续 enhancement）
- 拖拽文件（非文件夹）打开单张图片：不在本功能范围
