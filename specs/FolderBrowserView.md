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
- 鼠标悬停高亮，点击触发 `folderStore.selectedImageIndex = index`
