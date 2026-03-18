# FolderStore Spec

## 职责

`FolderStore` 是文件夹浏览模块的状态管理层，负责：
- 管理已添加的文件夹列表（配合 BookmarkManager 持久化）
- 管理当前选中文件夹及其图片列表
- 管理图片查看器的当前索引

## 接口

```swift
@MainActor
class FolderStore: ObservableObject {
    @Published var folders: [URL]           // 已添加的文件夹列表
    @Published var selectedFolder: URL?     // 当前选中的文件夹
    @Published var images: [URL]            // 当前文件夹内的图片（已过滤+排序）
    @Published var selectedImageIndex: Int? // nil=显示网格，有值=进入查看器
    @Published var isLoadingImages: Bool    // 图片扫描进行中

    init(bookmarkManager: BookmarkManager)

    func loadSavedFolders()      // App 启动时恢复已保存的 bookmark
    func addFolder()             // NSOpenPanel 选择并保存文件夹
    func removeFolder(_ url: URL)
    func selectFolder(_ url: URL)
}
```

## 支持的图片格式

`jpg`, `jpeg`, `png`, `heic`, `heif`, `gif`, `webp`, `tiff`

## 文件扫描

- 使用 `FileManager.contentsOfDirectory` 枚举目录
- 过滤：只保留扩展名在白名单内的文件
- 排序：`localizedStandardCompare`（自然排序，如 img1, img2, img10）
- 扫描在后台线程执行（`Task.detached`），结果回主线程更新

## 权限管理

- 每个 URL 在添加时调用 `BookmarkManager.startAccessing`
- 从 bookmark 恢复时同样调用 `startAccessing`
- `removeFolder` 时调用 `stopAccessing + removeBookmark`

## 状态流

```
App 启动 → loadSavedFolders() → folders 更新
点击 "+" → addFolder() → NSOpenPanel → saveBookmark + startAccessing → folders 更新 → selectFolder
点击文件夹 → selectFolder() → images = [] → scanImages(async) → images 更新
点击缩略图 → selectedImageIndex = index → 显示 ImageViewerView
ESC / 关闭查看器 → selectedImageIndex = nil → 显示 ImageGridView
```
