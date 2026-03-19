# SortFilter Spec

## 当前进度：第 0 步已完成（未开始）

---

## 目标

在 ImageGridView 中支持按名称、修改日期、文件大小排序，排序状态持久化。

---

## 接口

### SortOrder 枚举（新建 FolderStore.swift 内）

```swift
enum SortOrder: String, CaseIterable {
    case nameAsc    = "名称 ↑"
    case nameDesc   = "名称 ↓"
    case dateAsc    = "日期 ↑"
    case dateDesc   = "日期 ↓"
    case sizeAsc    = "大小 ↑"
    case sizeDesc   = "大小 ↓"
}
```

### FolderStore 变更

```swift
@Published var sortOrder: SortOrder = .nameAsc  // 默认名称升序，UserDefaults 持久化

// sortImages() 在 scanImages 完成后、images 赋值前调用
// 切换 sortOrder 时也触发 sortImages()，无需重新扫描磁盘
private func sortImages(_ urls: [URL]) -> [URL]
```

### ImageGridView 变更

- Toolbar 右侧加 `Menu` 按钮（`arrow.up.arrow.down`），展示 6 个排序选项
- 选中当前排序项时显示 checkmark

---

## 排序实现

| SortOrder | 排序依据 | 获取方式 |
|-----------|----------|----------|
| nameAsc/Desc | `lastPathComponent` | `localizedStandardCompare` |
| dateAsc/Desc | 文件修改日期 | `URLResourceValues.contentModificationDate` |
| sizeAsc/Desc | 文件字节数 | `URLResourceValues.fileSize` |

- 日期/大小通过 `URL.resourceValues(forKeys:)` 批量获取，在 `Task.detached` 中执行
- 获取失败时该文件排到末尾

---

## 持久化

```swift
// UserDefaults key: "sortOrder"
// 存储 SortOrder.rawValue（String）
// loadSavedFolders 时恢复
```

---

## 边界条件

| 场景 | 处理 |
|------|------|
| 文件无法读取修改日期/大小 | 排到末尾，不 crash |
| 切换文件夹后排序设置保留 | sortOrder 是全局状态，不随文件夹重置 |
| images 为空时切换排序 | 无操作，images 保持空数组 |

---

## 实现步骤

1. 定义 `SortOrder` 枚举，加到 FolderStore.swift
2. FolderStore 新增 `sortOrder` published 属性，UserDefaults 读写
3. 实现 `sortImages(_ urls: [URL]) -> [URL]`，覆盖 6 种排序
4. `scanImages` 完成后调用 `sortImages`
5. `sortOrder` didSet 时对当前 `images` 重新排序（不重扫）
6. ImageGridView toolbar 加排序 Menu
7. 编译验证
8. git commit「完成 SortFilter」
