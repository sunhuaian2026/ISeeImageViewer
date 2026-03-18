# BookmarkManager Spec

## 职责

管理 Security Scoped Bookmark 的创建、持久化、解析与访问控制，屏蔽底层 bookmark 细节，为上层提供简洁的文件夹访问能力。

## 对外接口

```swift
class BookmarkManager {
    /// 为用户选择的文件夹创建 bookmark 并持久化
    func saveBookmark(for url: URL) throws

    /// 恢复所有已保存的 bookmark，返回可访问的 URL 列表
    func restoreBookmarks() -> [URL]

    /// 开始访问指定 URL（startAccessingSecurityScopedResource）
    /// 返回是否成功
    func startAccessing(_ url: URL) -> Bool

    /// 停止访问指定 URL（stopAccessingSecurityScopedResource）
    func stopAccessing(_ url: URL)

    /// 删除指定 URL 对应的 bookmark
    func removeBookmark(for url: URL)
}
```

## 数据存储

- 使用 `UserDefaults` 存储，key 为 `"savedBookmarks"`
- 存储格式：`[String: Data]`，key 为 URL 的 `absoluteString`，value 为 bookmark Data
- bookmark 创建时使用 `.withSecurityScope` + `.securityScopeAllowOnlyReadAccess`（只读场景）或不加后者（读写场景，按需决定）

## 边界条件

| 场景 | 处理方式 |
|------|----------|
| bookmark 已过期（文件夹被移动/删除） | `restoreBookmarks` 中标记为 stale，自动删除对应条目 |
| 重复保存同一 URL | 覆盖旧的 bookmark Data，不重复存储 |
| `startAccessing` 未调用就读取文件 | 上层负责在访问前调用，BookmarkManager 不强制检查 |
| App 退出时未调用 `stopAccessing` | 系统会自动释放，但应在 `onDisappear` / `applicationWillTerminate` 中显式调用 |
| UserDefaults 写入失败 | `saveBookmark` 抛出错误，由调用方处理 |
| 沙盒权限未包含 `com.apple.security.files.bookmarks.app-scope` | 运行时 crash，需在 entitlements 中提前配置 |

## Entitlements 要求

```xml
<key>com.apple.security.files.user-selected.read-only</key>
<true/>
<key>com.apple.security.files.bookmarks.app-scope</key>
<true/>
```

## 不在职责范围内

- 不负责触发 `NSOpenPanel` 让用户选择文件夹
- 不负责文件夹内容的枚举与图片加载
- 不缓存或管理 URL 的访问状态（是否正在访问由调用方跟踪）
