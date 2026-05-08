# Glance V2 M1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Plan strategy**: This document covers M1 ship-able by slice. **Slice A** (foundational thin MVP) is detailed at full task / step / code level. **Slices B-I** are outlined with goal + deliverable + estimate; each will get a dedicated detailed plan written before that slice starts (so plan stays grounded in lessons from previously-shipped slices). This matches D9 per-milestone ship + tracer-bullet decomposition.
>
> **Spec reference**: `specs/v2/2026-05-06-v2-design.md`
> **Decision references**: `specs/Roadmap.md`「关键架构决策」段 D1-D10
> **Term references**: `CONTEXT.md`「跨文件夹聚合」段

**Goal:** Ship Glance V2 M1 (跨文件夹浏览 MVP) by delivering 9 vertical slices over 4-5 weeks, each independently ship-able as a minor version.

**Architecture:** New layer of cross-folder index (SQLite-backed `IndexStore`) + rule-driven `SmartFolderEngine` + sidebar IA改造 to layer 智能文件夹 above V1 folder tree. Reuses V1 `BookmarkManager` for sandbox file access; reuses V1 `ImageGridView` cell rendering (DRY).

**Tech Stack:** Swift 5.9+ / SwiftUI / async-await / sqlite3 C API (`import SQLite3`, no third-party) / FSEvents (`CoreServices`) / ImageIO (CGImageSource for metadata) / Vision (M2 only, not Slice A) / Combine 禁用。

---

## M1 Slice Roadmap

| Slice | Goal | Estimate | Ship as |
|---|---|---|---|
| **A** ⭐ (this plan) | Thin cross-folder MVP: IndexStore foundation + scan + "全部最近" smart folder + Sidebar IA + grid | 9-13 天（codex review 后从 7-10 天上调）| V2.0-beta1（第一次 ship-able V2） |
| B | 时间分段 sticky header（5 段固定）+ "本周新增"（merged C）+ hover tooltip（merged E）| 3 天 | V2.0-beta2 |
| D | hide toggle 右键菜单（root + 子目录 + 状态继承）+ Inspector 来源 path（merged F）| 2 天 | V2.0-beta3 |
| G | FSEvents 增量监听 + 删 root folder 清理 | 2-3 天 | V2.0-beta4 |
| H | 内容去重（SHA256 + cheap-first 粗筛）| 2 天 | V2.0-beta5 |
| I | 首次索引进度 UI + 错误处理 + SmartFolderStore enum-state 重构 | 1.5 天 | V2.0 RC + GA |

**Total:** ~19-23 工作日 ≈ **4-5 周**（落在 D9 锁定的 4-5 周范围内，codex review 后 critical/high 修复 + idempotent + dedup 调整 +2-3 天）。

**M1 Deliverables 累积说明**（codex review 后澄清）：M1 完成 = Slice A-I 全部 ship 后的累积状态，**不是** Slice A 单独完成 M1。具体：
- Slice A ship 后 = V2.0-beta1（thin MVP，包含 1 个内置 SF "全部最近"，**无**时间分段、**无**hover tooltip、**无**dedup）
- Slice B ship 后 = V2.0-beta2（加时间分段 + "本周新增" + hover tooltip）
- Slice H ship 后 = V2.0-beta5（加内容去重，符合 D3 决策——M1 累积包含 dedup）
- Slice I ship 后 = V2.0 RC + GA（M1 完成）

每 slice 完成跑 `/go`（5 步 verify + 文档同步 + PENDING + commit + push + 汇报）。

---

## File Structure (Slice A)

新增：

```
Glance/
└── IndexStore/                       ← 新模块：跨文件夹索引层
    ├── IndexDatabase.swift           ← 底层 sqlite3 C API 包装（open/close/exec/prepare/bind/step）
    ├── IndexStoreSchema.swift        ← Schema 定义 + version + migrations
    ├── IndexStore.swift              ← 高层入口（owns IndexDatabase + 提供 typed CRUD）
    ├── IndexedImage.swift            ← Image record struct + Codable
    ├── ManagedFolder.swift           ← Folder record struct + Codable
    ├── ImageMetadataReader.swift     ← URL → birth_time/size/format/dimensions
    └── FolderScanner.swift           ← 递归扫描 + 元数据提取 + IndexStore 写入
└── SmartFolder/                      ← 新模块：智能文件夹规则与查询
    ├── SmartFolder.swift             ← SmartFolder struct（id/name/rule/sortBy）
    ├── SmartFolderRule.swift         ← Predicate enum（AND/OR/ATOM）+ Atom struct
    ├── SmartFolderQueryBuilder.swift ← Predicate → SQL WHERE + params
    ├── SmartFolderEngine.swift       ← 执行查询返回 [IndexedImage]
    ├── BuiltInSmartFolders.swift     ← 全部最近 hard-coded 实例
    └── SmartFolderStore.swift        ← ObservableObject UI 状态（选中 SF + 查询结果）
└── FolderBrowser/
    └── SmartFolderListView.swift     ← 新文件：sidebar 智能文件夹区 UI
```

修改：

```
Glance/
├── GlanceApp.swift                   ← 注入 IndexStore + SmartFolderStore @StateObject
├── ContentView.swift                 ← Sidebar 改造（智能文件夹区 + 分隔线 + V1 tree 共存）
└── FolderBrowser/
    └── FolderStore.swift             ← 加 IndexStore 同步钩子（rootFolders 变更 → 写入 folders 表 + 触发扫描）
```

不动：

- `Glance.entitlements`（Application Support 写权限默认有）
- `BookmarkManager.swift`（V2 复用 V1 行为）
- 其他 V1 模块（`QuickViewer/` `Inspector/` `FullScreen/` `About/` `DesignSystem.swift`）

---

## Slice A: Thin Cross-Folder MVP（详细）

**Slice A 用户感知价值**：启动 V2 → 默认选中 ⚙️ "全部最近" → grid 显示所有 V1 已加 root folder 跨文件夹的图按 birth time 倒序展示。这一刻 V1 → V2 跃迁在视觉上完成。

**Slice A 不包含**（移到后续 slice）：
- 时间分段 sticky header（→ Slice B）
- "本周新增"（→ Slice B+C 合并）
- hide toggle 右键菜单（→ Slice D）
- Hover tooltip（→ Slice E 合并入 D）
- Inspector source path（→ Slice F 合并入 D）
- FSEvents 增量（→ Slice G；Slice A 仅做"应用启动时一次性扫描"）
- 内容去重（→ Slice H；Slice A 副本会重复显示）
- 首次索引进度 UI（→ Slice I；Slice A 进度仅日志输出）

**Slice A 估时**：~9-13 工作日（约 70-100 小时，单人；codex review 后从 7-10 天上调）。

### Task A.1: 创建 IndexStore 目录结构 + IndexDatabase sqlite3 包装

**Files:**
- Create: `Glance/IndexStore/IndexDatabase.swift`

**Goal:** 拿到能 open / close / exec SQL 的 thin wrapper（不引入第三方 SQLite 库）。

**Steps:**

- [ ] **Step 1**: 用 Finder 或 `mkdir` 在 `Glance/` 下建 `IndexStore/` 目录。无需手改 `xcodeproj`（PBXFileSystemSynchronizedRootGroup 自动加入）。

```bash
mkdir -p Glance/IndexStore Glance/SmartFolder
```

- [ ] **Step 2**: 创建 `Glance/IndexStore/IndexDatabase.swift`。

```swift
import Foundation
import SQLite3

enum IndexDatabaseError: Error {
    case openFailed(message: String)
    case execFailed(sql: String, message: String)
    case prepareFailed(sql: String, message: String)
    case stepFailed(message: String)
    case bindFailed(index: Int, message: String)
}

/// Thin wrapper around sqlite3 C API. All ops on caller's queue
/// (caller must serialize access via dispatch queue or actor).
final class IndexDatabase {

    private var db: OpaquePointer?

    init(at fileURL: URL) throws {
        var ptr: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        let openResult = sqlite3_open_v2(fileURL.path, &ptr, flags, nil)
        guard openResult == SQLITE_OK else {
            let msg = ptr.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            sqlite3_close(ptr)
            throw IndexDatabaseError.openFailed(message: msg)
        }
        self.db = ptr
        try execute("PRAGMA foreign_keys = ON;")
        try execute("PRAGMA journal_mode = WAL;")
    }

    deinit {
        if let db {
            sqlite3_close_v2(db)
        }
    }

    /// Run a single SQL statement (no result rows).
    func execute(_ sql: String) throws {
        var error: UnsafeMutablePointer<Int8>?
        let result = sqlite3_exec(db, sql, nil, nil, &error)
        if result != SQLITE_OK {
            let msg = error.map { String(cString: $0) } ?? "unknown"
            sqlite3_free(error)
            throw IndexDatabaseError.execFailed(sql: sql, message: msg)
        }
    }

    /// Prepare a statement; caller binds + steps + finalizes.
    func prepare(_ sql: String) throws -> OpaquePointer {
        var stmt: OpaquePointer?
        let result = sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        guard result == SQLITE_OK, let stmt else {
            let msg = String(cString: sqlite3_errmsg(db))
            throw IndexDatabaseError.prepareFailed(sql: sql, message: msg)
        }
        return stmt
    }

    func lastErrorMessage() -> String {
        guard let db else { return "(no db)" }
        return String(cString: sqlite3_errmsg(db))
    }
}
```

- [ ] **Step 3**: `make build` 验证编译通过。

```bash
make build
```

Expected: BUILD SUCCEEDED — 0 errors, 0 code warnings.

- [ ] **Step 4**: Commit (intermediate, `[wip]` skips codex).

```bash
git add Glance/IndexStore/IndexDatabase.swift
git commit -m "Slice A.1: IndexDatabase sqlite3 thin wrapper [wip]"
```

---

### Task A.2: Schema versioning + migration 系统

**Files:**
- Create: `Glance/IndexStore/IndexStoreSchema.swift`

**Goal:** 在 IndexDatabase 上层加版本号 + 顺序迁移（每个版本一个 SQL block）。Forward-looking schema（D7）一次到位。

**Steps:**

- [ ] **Step 1**: 创建 `Glance/IndexStore/IndexStoreSchema.swift`。

```swift
import Foundation

/// Schema version applied incrementally. M1 ships v1 with all M1+M2+M3 columns
/// (M2/M3 columns NULLable until populated). Future versions add columns via
/// ALTER TABLE in a new migration block.
enum IndexStoreSchema {

    static let currentVersion: Int = 1

    /// Apply migrations from `current` (db's PRAGMA user_version) up to currentVersion.
    static func migrate(_ db: IndexDatabase, currentDbVersion: Int) throws {
        if currentDbVersion < 1 {
            try applyV1(db)
        }
        // Future: if currentDbVersion < 2 { try applyV2(db) }, etc.
        try db.execute("PRAGMA user_version = \(currentVersion);")
    }

    static func readDbVersion(_ db: IndexDatabase) throws -> Int {
        let stmt = try db.prepare("PRAGMA user_version;")
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int(stmt, 0))
    }

    // MARK: V1 (M1+M2+M3 forward-looking)

    private static func applyV1(_ db: IndexDatabase) throws {
        // folders 表：稀疏存储 root + explicitly-set subfolder。
        // parent_root_id NULLable —— root 行 NULL（自身就是 root，无父）；
        // subfolder 行非 NULL（指向所属 root）。FK NULL 不触发约束（SQLite 标准行为）。
        // 这避免了"root 自链 insert 时 parent_root_id=0 触发 FK fail"的死锁。
        // root_path：root 行的标准化绝对路径（去重 unique 用），subfolder 行 NULL。
        try db.execute("""
            CREATE TABLE folders (
                id                  INTEGER PRIMARY KEY AUTOINCREMENT,
                root_url_bookmark   BLOB,                                -- 仅 root 行非 NULL
                root_path           TEXT,                                -- 仅 root 行非 NULL（标准化绝对路径，幂等用）
                relative_path       TEXT NOT NULL DEFAULT '',            -- '' 即 root
                parent_root_id      INTEGER,                             -- root 行 NULL；subfolder 行 → 所属 root
                hide_in_smart_view  INTEGER NOT NULL DEFAULT 0,
                FOREIGN KEY (parent_root_id) REFERENCES folders(id) ON DELETE CASCADE
            );
        """)
        try db.execute("CREATE UNIQUE INDEX idx_folders_root_path ON folders(root_path) WHERE root_path IS NOT NULL;")
        try db.execute("CREATE UNIQUE INDEX idx_folders_subpath ON folders(parent_root_id, relative_path) WHERE parent_root_id IS NOT NULL;")
        try db.execute("CREATE INDEX idx_folders_parent ON folders(parent_root_id);")

        // images 表：UNIQUE(folder_id, relative_path) 让 INSERT OR IGNORE 幂等。
        // content_sha256 / dedup_canonical M1 nullable，Slice H 启用。
        try db.execute("""
            CREATE TABLE images (
                id                       INTEGER PRIMARY KEY AUTOINCREMENT,
                url_bookmark             BLOB NOT NULL,
                birth_time               REAL NOT NULL,
                file_size                INTEGER NOT NULL,
                format                   TEXT NOT NULL,
                filename                 TEXT NOT NULL,
                relative_path            TEXT NOT NULL,
                folder_id                INTEGER NOT NULL,
                dimensions_width         INTEGER,
                dimensions_height        INTEGER,
                content_sha256           TEXT,                            -- M1 nullable（Slice H 用）
                dedup_canonical          INTEGER,                          -- M1 nullable（Slice H 用）
                feature_print            BLOB,                             -- M2
                feature_print_revision   INTEGER,                          -- M2
                supports_feature_print   INTEGER NOT NULL DEFAULT 1,       -- M2
                exif_capture_date        REAL,                             -- M3
                FOREIGN KEY (folder_id) REFERENCES folders(id) ON DELETE CASCADE,
                UNIQUE(folder_id, relative_path)
            );
        """)
        try db.execute("CREATE INDEX idx_images_birth ON images(birth_time DESC);")
        try db.execute("CREATE INDEX idx_images_folder ON images(folder_id);")
        try db.execute("CREATE INDEX idx_images_dedup ON images(content_sha256) WHERE content_sha256 IS NOT NULL;")
    }
}
```

> **关键修正**（codex review 发现）：
> 1. `parent_root_id` 改 NULLable——root 行用 NULL（自身就是 root，无父），消除了"root 自链 insert 时 parent_root_id=0 但 id=0 不存在导致 FK fail" 的死锁
> 2. 加 `root_path` 字段 + UNIQUE INDEX 让 `registerRoot` 幂等（重启不重复 register）
> 3. images 表加 `UNIQUE(folder_id, relative_path)` 让 FolderScanner 用 `INSERT OR IGNORE` 幂等（重扫不重复插入）

- [ ] **Step 2**: `make build` 验证。

- [ ] **Step 3**: Commit.

```bash
git add Glance/IndexStore/IndexStoreSchema.swift
git commit -m "Slice A.2: IndexStoreSchema v1 forward-looking [wip]"
```

---

### Task A.3: IndexStore 高层入口 + 启动初始化

**Files:**
- Create: `Glance/IndexStore/IndexStore.swift`

**Goal:** 提供"应用层就拿一个 IndexStore 实例就够"的入口；负责打开 DB、跑 migration、提供后续 task 用的 typed API。

**Steps:**

- [ ] **Step 1**: 创建 `Glance/IndexStore/IndexStore.swift`。

```swift
import Foundation

/// High-level IndexStore. Owns IndexDatabase + serializes access via internal queue.
/// Subsequent tasks add typed CRUD methods (Image / ManagedFolder).
final class IndexStore {

    private let db: IndexDatabase
    private let queue: DispatchQueue
    let storageURL: URL

    /// Opens or creates the IndexStore at the canonical path:
    /// `~/Library/Application Support/Glance/index.sqlite`. Runs pending migrations.
    init() throws {
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let glanceDir = appSupport.appendingPathComponent("Glance", isDirectory: true)
        try FileManager.default.createDirectory(at: glanceDir, withIntermediateDirectories: true)
        let url = glanceDir.appendingPathComponent("index.sqlite")
        self.storageURL = url
        self.db = try IndexDatabase(at: url)
        self.queue = DispatchQueue(label: "com.sunhongjun.glance.indexstore", qos: .utility)

        try queue.sync {
            let current = try IndexStoreSchema.readDbVersion(db)
            try IndexStoreSchema.migrate(db, currentDbVersion: current)
        }
    }

    /// Run a synchronous block on the IndexStore queue.
    func sync<T>(_ block: (IndexDatabase) throws -> T) throws -> T {
        try queue.sync {
            try block(db)
        }
    }
}
```

- [ ] **Step 2**: `make build` 验证。

- [ ] **Step 3**: Commit.

```bash
git add Glance/IndexStore/IndexStore.swift
git commit -m "Slice A.3: IndexStore high-level entry + auto-migrate [wip]"
```

---

### Task A.4: ManagedFolder struct + folders 表 CRUD

**Files:**
- Create: `Glance/IndexStore/ManagedFolder.swift`

**Goal:** Typed insert/fetch for managed folders（root + 稀疏 subfolder rows for explicit hide state）。

**Steps:**

- [ ] **Step 1**: 创建 `Glance/IndexStore/ManagedFolder.swift`。

```swift
import Foundation
import SQLite3

struct ManagedFolder: Identifiable, Equatable {
    let id: Int64
    let rootBookmark: Data?              // non-nil only for root rows
    let relativePath: String              // "" for root
    let parentRootId: Int64?              // root 行 NULL（自身就是 root），subfolder 行 → 所属 root id
    let hideInSmartView: Bool

    var isRoot: Bool { relativePath.isEmpty && rootBookmark != nil }
}

extension IndexStore {

    /// Register a root managed folder; **幂等**：同一 path 重复调用返回已有 id，不新建行。
    /// `path` = rootURL.standardizedFileURL.path，作为 unique 键。
    /// caller（FolderStoreIndexBridge）传 path + bookmark，bookmark 在重启可能 stale 但 path 稳定。
    func registerRoot(path: String, bookmark: Data) throws -> Int64 {
        try sync { db in
            // 先查 root_path 是否已存在
            let selStmt = try db.prepare("SELECT id FROM folders WHERE root_path = ? LIMIT 1;")
            defer { sqlite3_finalize(selStmt) }
            sqlite3_bind_text(selStmt, 1, (path as NSString).utf8String, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            if sqlite3_step(selStmt) == SQLITE_ROW {
                return sqlite3_column_int64(selStmt, 0)  // 已注册，复用
            }

            // 新 root：parent_root_id = NULL（root 行无父），FK 不触发
            let insStmt = try db.prepare("""
                INSERT INTO folders (root_url_bookmark, root_path, relative_path, parent_root_id, hide_in_smart_view)
                VALUES (?, ?, '', NULL, 0)
                RETURNING id;
            """)
            defer { sqlite3_finalize(insStmt) }

            let bytes = bookmark as NSData
            sqlite3_bind_blob(insStmt, 1, bytes.bytes, Int32(bytes.length), unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_text(insStmt, 2, (path as NSString).utf8String, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))

            guard sqlite3_step(insStmt) == SQLITE_ROW else {
                throw IndexDatabaseError.stepFailed(message: db.lastErrorMessage())
            }
            return sqlite3_column_int64(insStmt, 0)
        }
    }

    /// Fetch all root managed folders.
    func fetchRoots() throws -> [ManagedFolder] {
        try sync { db in
            let stmt = try db.prepare("""
                SELECT id, root_url_bookmark, relative_path, parent_root_id, hide_in_smart_view
                FROM folders
                WHERE root_url_bookmark IS NOT NULL
                ORDER BY id ASC;
            """)
            defer { sqlite3_finalize(stmt) }

            var results: [ManagedFolder] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = sqlite3_column_int64(stmt, 0)
                let blobLen = sqlite3_column_bytes(stmt, 1)
                let blobPtr = sqlite3_column_blob(stmt, 1)
                let bookmark = blobPtr.map { Data(bytes: $0, count: Int(blobLen)) }
                let relPath = String(cString: sqlite3_column_text(stmt, 2))
                // root 行 parent_root_id 为 NULL；用 sqlite3_column_type 判断
                let parentId: Int64?
                if sqlite3_column_type(stmt, 3) == SQLITE_NULL {
                    parentId = nil
                } else {
                    parentId = sqlite3_column_int64(stmt, 3)
                }
                let hide = sqlite3_column_int(stmt, 4) != 0

                results.append(ManagedFolder(
                    id: id,
                    rootBookmark: bookmark,
                    relativePath: relPath,
                    parentRootId: parentId,
                    hideInSmartView: hide
                ))
            }
            return results
        }
    }
}
```

- [ ] **Step 2**: `make build` 验证。

- [ ] **Step 3**: Commit.

```bash
git add Glance/IndexStore/ManagedFolder.swift
git commit -m "Slice A.4: ManagedFolder struct + folders table CRUD [wip]"
```

---

### Task A.5: IndexedImage struct + images 表 CRUD

**Files:**
- Create: `Glance/IndexStore/IndexedImage.swift`

**Goal:** Typed insert/fetchAll for indexed images。M1 仅用 birth_time/size/format/filename/path/dimensions/folder_id 字段；其他 forward-looking 字段保留 NULL/default。

**Steps:**

- [ ] **Step 1**: 创建 `Glance/IndexStore/IndexedImage.swift`。

```swift
import Foundation
import SQLite3

struct IndexedImage: Identifiable, Equatable {
    let id: Int64
    let urlBookmark: Data
    let birthTime: Date
    let fileSize: Int64
    let format: String
    let filename: String
    let relativePath: String
    let folderId: Int64
    let dimensionsWidth: Int?
    let dimensionsHeight: Int?
}

struct ImageInsertRecord {
    let urlBookmark: Data
    let birthTime: Date
    let fileSize: Int64
    let format: String
    let filename: String
    let relativePath: String
    let folderId: Int64
    let dimensionsWidth: Int?
    let dimensionsHeight: Int?
}

extension IndexStore {

    /// 幂等 insert：UNIQUE(folder_id, relative_path) + INSERT OR IGNORE。
    /// 重复 (folder_id, relative_path) 静默跳过，返回已存在 row id。
    func insertImageIfAbsent(_ record: ImageInsertRecord) throws -> Int64 {
        try sync { db in
            let stmt = try db.prepare("""
                INSERT OR IGNORE INTO images
                (url_bookmark, birth_time, file_size, format, filename, relative_path,
                 folder_id, dimensions_width, dimensions_height, supports_feature_print)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 1);
            """)
            defer { sqlite3_finalize(stmt) }

            let bookmarkBytes = record.urlBookmark as NSData
            try checkBind(sqlite3_bind_blob(stmt, 1, bookmarkBytes.bytes, Int32(bookmarkBytes.length), unsafeBitCast(-1, to: sqlite3_destructor_type.self)), index: 1, db: db)
            try checkBind(sqlite3_bind_double(stmt, 2, record.birthTime.timeIntervalSince1970), index: 2, db: db)
            try checkBind(sqlite3_bind_int64(stmt, 3, record.fileSize), index: 3, db: db)
            try checkBind(sqlite3_bind_text(stmt, 4, (record.format as NSString).utf8String, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self)), index: 4, db: db)
            try checkBind(sqlite3_bind_text(stmt, 5, (record.filename as NSString).utf8String, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self)), index: 5, db: db)
            try checkBind(sqlite3_bind_text(stmt, 6, (record.relativePath as NSString).utf8String, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self)), index: 6, db: db)
            try checkBind(sqlite3_bind_int64(stmt, 7, record.folderId), index: 7, db: db)
            if let w = record.dimensionsWidth {
                try checkBind(sqlite3_bind_int(stmt, 8, Int32(w)), index: 8, db: db)
            } else {
                try checkBind(sqlite3_bind_null(stmt, 8), index: 8, db: db)
            }
            if let h = record.dimensionsHeight {
                try checkBind(sqlite3_bind_int(stmt, 9, Int32(h)), index: 9, db: db)
            } else {
                try checkBind(sqlite3_bind_null(stmt, 9), index: 9, db: db)
            }

            let stepResult = sqlite3_step(stmt)
            guard stepResult == SQLITE_DONE else {
                throw IndexDatabaseError.stepFailed(message: "insertImage step \(stepResult): \(db.lastErrorMessage())")
            }

            // INSERT OR IGNORE：插入成功 → last_insert_rowid 为新 id；冲突跳过 → 查现有 id
            let changes = Int(sqlite3_changes(db.handle))
            if changes > 0 {
                return sqlite3_last_insert_rowid(db.handle)
            }
            // 冲突：查已有
            let q = try db.prepare("SELECT id FROM images WHERE folder_id = ? AND relative_path = ? LIMIT 1;")
            defer { sqlite3_finalize(q) }
            sqlite3_bind_int64(q, 1, record.folderId)
            sqlite3_bind_text(q, 2, (record.relativePath as NSString).utf8String, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            guard sqlite3_step(q) == SQLITE_ROW else {
                throw IndexDatabaseError.stepFailed(message: "insertImage post-IGNORE lookup: \(db.lastErrorMessage())")
            }
            return sqlite3_column_int64(q, 0)
        }
    }

    /// 受 SQL injection 保护的 fetch：仅接 SmartFolderQueryBuilder 编译产物。
    /// `CompiledSmartFolderQuery` 的 whereClause / orderBy 字符串由 builder 内部生成，
    /// 仅含已知 column name 和 placeholder（?），用户输入永远走 parameters 绑定。
    func fetch(_ compiled: CompiledSmartFolderQuery, limit: Int? = nil) throws -> [IndexedImage] {
        try sync { db in
            var sql = "SELECT id, url_bookmark, birth_time, file_size, format, filename, relative_path, folder_id, dimensions_width, dimensions_height FROM images"
            if !compiled.whereClause.isEmpty {
                sql += " WHERE \(compiled.whereClause)"
            }
            if !compiled.orderBy.isEmpty {
                sql += " ORDER BY \(compiled.orderBy)"
            }
            if let limit {
                sql += " LIMIT \(limit)"
            }
            sql += ";"

            let stmt = try db.prepare(sql)
            defer { sqlite3_finalize(stmt) }

            for (idx, param) in compiled.parameters.enumerated() {
                let pos = Int32(idx + 1)
                let bindResult: Int32
                switch param {
                case let v as Int64: bindResult = sqlite3_bind_int64(stmt, pos, v)
                case let v as Int: bindResult = sqlite3_bind_int64(stmt, pos, Int64(v))
                case let v as Double: bindResult = sqlite3_bind_double(stmt, pos, v)
                case let v as String: bindResult = sqlite3_bind_text(stmt, pos, (v as NSString).utf8String, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                case let v as Bool: bindResult = sqlite3_bind_int(stmt, pos, v ? 1 : 0)
                default:
                    throw IndexDatabaseError.bindFailed(index: idx, message: "unsupported parameter type \(type(of: param))")
                }
                if bindResult != SQLITE_OK {
                    throw IndexDatabaseError.bindFailed(index: idx, message: "bind result \(bindResult): \(db.lastErrorMessage())")
                }
            }

            var results: [IndexedImage] = []
            while true {
                let stepResult = sqlite3_step(stmt)
                if stepResult == SQLITE_DONE { break }
                if stepResult != SQLITE_ROW {
                    throw IndexDatabaseError.stepFailed(message: "fetch step \(stepResult): \(db.lastErrorMessage())")
                }
                let id = sqlite3_column_int64(stmt, 0)
                let blobLen = sqlite3_column_bytes(stmt, 1)
                let blobPtr = sqlite3_column_blob(stmt, 1)
                let bookmark = blobPtr.map { Data(bytes: $0, count: Int(blobLen)) } ?? Data()
                let birth = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 2))
                let size = sqlite3_column_int64(stmt, 3)
                let format = String(cString: sqlite3_column_text(stmt, 4))
                let filename = String(cString: sqlite3_column_text(stmt, 5))
                let relPath = String(cString: sqlite3_column_text(stmt, 6))
                let folderId = sqlite3_column_int64(stmt, 7)
                let w = sqlite3_column_type(stmt, 8) == SQLITE_NULL ? nil : Optional(Int(sqlite3_column_int(stmt, 8)))
                let h = sqlite3_column_type(stmt, 9) == SQLITE_NULL ? nil : Optional(Int(sqlite3_column_int(stmt, 9)))

                results.append(IndexedImage(
                    id: id, urlBookmark: bookmark, birthTime: birth, fileSize: size,
                    format: format, filename: filename, relativePath: relPath,
                    folderId: folderId, dimensionsWidth: w, dimensionsHeight: h
                ))
            }
            return results
        }
    }

    private func checkBind(_ result: Int32, index: Int, db: IndexDatabase) throws {
        if result != SQLITE_OK {
            throw IndexDatabaseError.bindFailed(index: index, message: "bind result \(result): \(db.lastErrorMessage())")
        }
    }
}
```

> **关键修正**（codex review 发现）：
> 1. `insertImage` → `insertImageIfAbsent`：用 `INSERT OR IGNORE` 配合 schema UNIQUE，幂等
> 2. `fetchImages(whereClause:)` → `fetch(_ compiled: CompiledSmartFolderQuery)`：API 层面强制只接 builder 产物，**消除外部 raw string 注入 vector**
> 3. 所有 `sqlite3_bind_*` 检查返回码（之前忽略）；step loop 检查 `SQLITE_DONE` 终止 vs `SQLITE_ERROR/BUSY` 抛错
> 4. IndexDatabase 需要新增 `var handle: OpaquePointer?` 暴露给 sqlite3_changes / sqlite3_last_insert_rowid—— A.1 task step 2 需更新（见 step 4 below）

- [ ] **Step 1.5（A.1 配套修正）**：回到 A.1 创建的 `IndexDatabase.swift`，把 private 的 `db: OpaquePointer?` 改成 internal `var handle: OpaquePointer? { db }` 或直接 internal。这样 IndexStore extension 才能调 `sqlite3_changes(db.handle)` / `sqlite3_last_insert_rowid(db.handle)`。

```swift
final class IndexDatabase {
    private(set) var handle: OpaquePointer?    // ← 改 internal，让 IndexStore 可访问
    // ... rest unchanged ...
}
```

并把 init 内 `self.db = ptr` 改为 `self.handle = ptr`，所有内部 `db` 引用改 `handle`。

- [ ] **Step 2**: `make build` 验证。

- [ ] **Step 3**: Commit.

```bash
git add Glance/IndexStore/IndexedImage.swift
git commit -m "Slice A.5: IndexedImage struct + images table CRUD [wip]"
```

---

### Task A.6: ImageMetadataReader（URL → birth_time/size/format/dimensions）

**Files:**
- Create: `Glance/IndexStore/ImageMetadataReader.swift`

**Goal:** 给一个文件 URL 抽取索引所需的元数据，使用纯 macOS API（FileManager + ImageIO），跳过非图像文件。

**Steps:**

- [ ] **Step 1**: 创建 `Glance/IndexStore/ImageMetadataReader.swift`。

```swift
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct ImageMetadata {
    let birthTime: Date           // file birth time (创建/到达本机的时间)
    let fileSize: Int64
    let format: String            // "PNG" / "JPEG" / "HEIC" / etc.
    let filename: String
    let dimensionsWidth: Int?
    let dimensionsHeight: Int?
}

enum ImageMetadataReader {

    /// Read metadata for a single file. Returns nil if the file is not an image
    /// (UTType not conforming to .image), is unreadable, or birth time missing.
    static func read(at url: URL) -> ImageMetadata? {
        let fm = FileManager.default
        guard let attrs = try? fm.attributesOfItem(atPath: url.path) else { return nil }

        // Birth time: macOS exposes via NSFileSystemFileNumber alternative; use creationDate.
        guard let creation = attrs[.creationDate] as? Date else { return nil }
        let size = (attrs[.size] as? NSNumber)?.int64Value ?? 0

        // Format check via UTType.
        guard let utType = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType,
              utType.conforms(to: .image) else {
            return nil
        }
        let format = formatLabel(for: utType)

        // Dimensions via ImageIO without decoding pixels.
        var width: Int?
        var height: Int?
        if let src = CGImageSourceCreateWithURL(url as CFURL, nil),
           let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any] {
            width = props[kCGImagePropertyPixelWidth] as? Int
            height = props[kCGImagePropertyPixelHeight] as? Int
        }

        return ImageMetadata(
            birthTime: creation,
            fileSize: size,
            format: format,
            filename: url.lastPathComponent,
            dimensionsWidth: width,
            dimensionsHeight: height
        )
    }

    private static func formatLabel(for utType: UTType) -> String {
        // Map common UTType to short label. Default to preferredFilenameExtension upper.
        if utType.conforms(to: .png) { return "PNG" }
        if utType.conforms(to: .jpeg) { return "JPEG" }
        if utType.conforms(to: .heic) { return "HEIC" }
        if utType.conforms(to: .tiff) { return "TIFF" }
        if utType.conforms(to: .gif) { return "GIF" }
        if utType.conforms(to: .webP) { return "WebP" }
        if utType.conforms(to: .bmp) { return "BMP" }
        if utType.conforms(to: .rawImage) { return "RAW" }
        return utType.preferredFilenameExtension?.uppercased() ?? "IMAGE"
    }
}
```

- [ ] **Step 2**: `make build` 验证。

- [ ] **Step 3**: Commit.

```bash
git add Glance/IndexStore/ImageMetadataReader.swift
git commit -m "Slice A.6: ImageMetadataReader (URL → ImageMetadata) [wip]"
```

---

### Task A.7: FolderScanner（递归扫描 + 写入 IndexStore）

**Files:**
- Create: `Glance/IndexStore/FolderScanner.swift`

**Goal:** 给一个 root URL 和已注册的 folder_id，递归扫描所有图像文件，依次写入 IndexStore。同步执行（异步包装在 caller，方便测试）。

**Steps:**

- [ ] **Step 1**: 创建 `Glance/IndexStore/FolderScanner.swift`。

```swift
import Foundation

struct ScanProgress {
    let totalScanned: Int
    let totalIndexed: Int
    let lastIndexed: URL?
}

final class FolderScanner {

    let store: IndexStore

    init(store: IndexStore) {
        self.store = store
    }

    /// Recursively scan a root URL and insert image records into IndexStore.
    /// `onProgress` is called every 50 files (best-effort).
    /// Caller must have started accessing the security-scoped resource if needed.
    func scan(
        rootURL: URL,
        folderId: Int64,
        onProgress: ((ScanProgress) -> Void)? = nil
    ) throws {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.isRegularFileKey, .isHiddenKey, .contentTypeKey]
        guard let enumerator = fm.enumerator(
            at: rootURL,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            throw IndexDatabaseError.execFailed(sql: "FolderScanner.enumerator", message: "could not enumerate \(rootURL.path)")
        }

        var totalScanned = 0
        var totalIndexed = 0
        var lastIndexed: URL?

        for case let fileURL as URL in enumerator {
            totalScanned += 1
            guard let values = try? fileURL.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true else { continue }

            guard let metadata = ImageMetadataReader.read(at: fileURL) else { continue }

            let relPath = relativePath(of: fileURL, under: rootURL)
            let bookmark = (try? fileURL.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )) ?? Data()

            let record = ImageInsertRecord(
                urlBookmark: bookmark,
                birthTime: metadata.birthTime,
                fileSize: metadata.fileSize,
                format: metadata.format,
                filename: metadata.filename,
                relativePath: relPath,
                folderId: folderId,
                dimensionsWidth: metadata.dimensionsWidth,
                dimensionsHeight: metadata.dimensionsHeight
            )
            _ = try store.insertImageIfAbsent(record)   // 幂等：UNIQUE(folder_id, relative_path) + INSERT OR IGNORE
            totalIndexed += 1
            lastIndexed = fileURL

            if totalScanned % 50 == 0 {
                onProgress?(ScanProgress(totalScanned: totalScanned, totalIndexed: totalIndexed, lastIndexed: lastIndexed))
            }
        }
        onProgress?(ScanProgress(totalScanned: totalScanned, totalIndexed: totalIndexed, lastIndexed: lastIndexed))
    }

    private func relativePath(of file: URL, under root: URL) -> String {
        let filePath = file.standardizedFileURL.path
        let rootPath = root.standardizedFileURL.path
        if filePath.hasPrefix(rootPath) {
            return String(filePath.dropFirst(rootPath.count).drop(while: { $0 == "/" }))
        }
        return file.lastPathComponent
    }
}
```

- [ ] **Step 2**: `make build` 验证。

- [ ] **Step 3**: Commit.

```bash
git add Glance/IndexStore/FolderScanner.swift
git commit -m "Slice A.7: FolderScanner (recursive scan + insert) [wip]"
```

---

### Task A.8: SmartFolder + Rule data structures

**Files:**
- Create: `Glance/SmartFolder/SmartFolderRule.swift`
- Create: `Glance/SmartFolder/SmartFolder.swift`

**Goal:** 定义 rule JSON 的 Codable struct（D6 Spotlight-like AND/OR 平铺，但 JSON 格式预留嵌套兼容 D7）+ SmartFolder struct。

**Steps:**

- [ ] **Step 1**: 创建 `Glance/SmartFolder/SmartFolderRule.swift`。

```swift
import Foundation

/// JSON-backed rule predicate. Tree shape (forward-compatible with future nesting),
/// but D6 V2 GUI only produces 2-layer AND/OR + atom leaves.
indirect enum SmartFolderPredicate: Codable, Equatable {
    case and([SmartFolderPredicate])
    case or([SmartFolderPredicate])
    case atom(SmartFolderAtom)

    private enum CodingKeys: String, CodingKey { case op, children, field, value }
    private enum OpTag: String, Codable { case AND, OR, ATOM }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .and(let xs):
            try c.encode(OpTag.AND, forKey: .op)
            try c.encode(xs, forKey: .children)
        case .or(let xs):
            try c.encode(OpTag.OR, forKey: .op)
            try c.encode(xs, forKey: .children)
        case .atom(let a):
            try c.encode(OpTag.ATOM, forKey: .op)
            try c.encode(a, forKey: .value)
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let op = try c.decode(OpTag.self, forKey: .op)
        switch op {
        case .AND:
            let xs = try c.decode([SmartFolderPredicate].self, forKey: .children)
            self = .and(xs)
        case .OR:
            let xs = try c.decode([SmartFolderPredicate].self, forKey: .children)
            self = .or(xs)
        case .ATOM:
            let a = try c.decode(SmartFolderAtom.self, forKey: .value)
            self = .atom(a)
        }
    }
}

struct SmartFolderAtom: Codable, Equatable {
    let field: SmartFolderField
    let op: SmartFolderOp
    let value: SmartFolderValue
}

/// D6 验证（Spotlight-like AND/OR 限制）：M1 只对**用户自定义** predicate 应用，
/// 内置 SmartFolder（M1 全部 + M3 部分）由开发者编写信任跳过。M4 用户规则编辑器
/// 必须调 `validateD6UserRule()` 才能保存。
///
/// 当前 strict 定义：max 3 层（root 1 + 中间 OR/AND group 1 + atom 1），
/// 配合 alternation（AND 内不能直接嵌 AND；OR 内不能直接嵌 OR）。
/// 依据：Spotlight / Finder 智能文件夹 UI 的"任一/全部"切换 + 单层"组"嵌入。
enum SmartFolderRuleError: Error {
    case unsupportedNesting(reason: String)
    case unsupportedOperator(String)
}

extension SmartFolderPredicate {
    /// 仅 M4 用户规则编辑器调；M1 内置 predicates 不调。
    func validateD6UserRule() throws {
        try validate(parent: nil, depth: 0, maxDepth: 3)
    }

    private func validate(parent: NodeOp?, depth: Int, maxDepth: Int) throws {
        if depth >= maxDepth {
            if case .atom = self { return }
            throw SmartFolderRuleError.unsupportedNesting(reason: "D6 max \(maxDepth) 层；超过仅允许 atom 叶节点")
        }
        switch self {
        case .atom:
            return
        case .and(let xs):
            if parent == .and {
                throw SmartFolderRuleError.unsupportedNesting(reason: "D6 alternation：AND 不能直接嵌 AND（合并到外层）")
            }
            for child in xs { try child.validate(parent: .and, depth: depth + 1, maxDepth: maxDepth) }
        case .or(let xs):
            if parent == .or {
                throw SmartFolderRuleError.unsupportedNesting(reason: "D6 alternation：OR 不能直接嵌 OR（合并到外层）")
            }
            for child in xs { try child.validate(parent: .or, depth: depth + 1, maxDepth: maxDepth) }
        }
    }

    private enum NodeOp { case and, or }
}

/// 字段 raw value **必须**对应 IndexStore 真实 column name（snake_case）。
/// virtual 字段（managed / hidden / dedupCanonicalOrNull）不在 DB schema，由 QueryBuilder 翻译成具体 SQL。
enum SmartFolderField: String, Codable {
    // virtual fields：QueryBuilder 内部 emitAtom 中翻译成具体 SQL 表达
    case managed
    case hidden
    case dedupCanonicalOrNull = "dedup_canonical_or_null"
    // 真实 DB columns（raw value = column name，避免 camelCase/snake_case 漂移）
    case format
    case filename
    case relativePath = "relative_path"
    case fileSize = "file_size"
    case birthTime = "birth_time"
    case dimensionsWidth = "dimensions_width"
    case dimensionsHeight = "dimensions_height"
}

enum SmartFolderOp: String, Codable {
    case eq = "="
    case ne = "!="
    case contains = "CONTAINS"
    case startsWith = "STARTS_WITH"
    case greaterThan = ">"
    case lessThan = "<"
    case betweenDuration = "BETWEEN_DURATION"  // value: relative time range like ["-7d", "now"]
    case inSet = "IN"
}

enum SmartFolderValue: Codable, Equatable {
    case bool(Bool)
    case int(Int64)
    case double(Double)
    case string(String)
    case stringArray([String])
    case relativeTimeRange(start: String, end: String)  // e.g. ("-7d", "now")

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .bool(let v): try c.encode(v)
        case .int(let v): try c.encode(v)
        case .double(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        case .stringArray(let v): try c.encode(v)
        case .relativeTimeRange(let s, let e): try c.encode(["start": s, "end": e])
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let v = try? c.decode(Bool.self) { self = .bool(v); return }
        if let v = try? c.decode(Int64.self) { self = .int(v); return }
        if let v = try? c.decode(Double.self) { self = .double(v); return }
        if let v = try? c.decode([String: String].self), let s = v["start"], let e = v["end"] {
            self = .relativeTimeRange(start: s, end: e); return
        }
        if let v = try? c.decode([String].self) { self = .stringArray(v); return }
        if let v = try? c.decode(String.self) { self = .string(v); return }
        throw DecodingError.typeMismatch(SmartFolderValue.self, .init(codingPath: c.codingPath, debugDescription: "unknown value type"))
    }
}
```

- [ ] **Step 2**: 创建 `Glance/SmartFolder/SmartFolder.swift`。

```swift
import Foundation

struct SmartFolder: Identifiable, Equatable {
    let id: String                           // stable id (built-ins use slug like "all-recent")
    let displayName: String                  // "全部最近"
    let predicate: SmartFolderPredicate
    let sortBy: SmartFolderSortKey
    let sortDescending: Bool
    let isBuiltIn: Bool

    static func == (lhs: SmartFolder, rhs: SmartFolder) -> Bool {
        lhs.id == rhs.id
    }
}

enum SmartFolderSortKey: String {
    case birthTime = "birth_time"
    case filename
    case fileSize = "file_size"
}
```

- [ ] **Step 3**: `make build` 验证。

- [ ] **Step 4**: Commit.

```bash
git add Glance/SmartFolder/SmartFolderRule.swift Glance/SmartFolder/SmartFolder.swift
git commit -m "Slice A.8: SmartFolder + Predicate/Atom/Op/Value structs [wip]"
```

---

### Task A.9: SmartFolderQueryBuilder（Predicate → SQL WHERE）

**Files:**
- Create: `Glance/SmartFolder/SmartFolderQueryBuilder.swift`

**Goal:** 把 Predicate 树翻译成 `CompiledSmartFolderQuery (whereClause, parameters, orderBy)`，喂给 `IndexStore.fetch(_ compiled:)`（A.5 改造后的注入安全 API）。

**Steps:**

- [ ] **Step 1**: 创建 `Glance/SmartFolder/SmartFolderQueryBuilder.swift`。

```swift
import Foundation

enum SmartFolderQueryError: Error {
    case unsupportedFieldOpCombo(field: SmartFolderField, op: SmartFolderOp)
    case typeMismatch(field: SmartFolderField, value: SmartFolderValue)
}

struct CompiledSmartFolderQuery {
    let whereClause: String
    let parameters: [Any]
    let orderBy: String
}

enum SmartFolderQueryBuilder {

    static func compile(_ folder: SmartFolder, now: Date = Date()) throws -> CompiledSmartFolderQuery {
        var params: [Any] = []
        let whereSQL = try emit(folder.predicate, params: &params, now: now)
        let orderSQL = "\(folder.sortBy.rawValue) \(folder.sortDescending ? "DESC" : "ASC")"
        return CompiledSmartFolderQuery(whereClause: whereSQL, parameters: params, orderBy: orderSQL)
    }

    private static func emit(_ p: SmartFolderPredicate, params: inout [Any], now: Date) throws -> String {
        switch p {
        case .and(let xs):
            let parts = try xs.map { try emit($0, params: &params, now: now) }
            return "(" + parts.joined(separator: " AND ") + ")"
        case .or(let xs):
            let parts = try xs.map { try emit($0, params: &params, now: now) }
            return "(" + parts.joined(separator: " OR ") + ")"
        case .atom(let atom):
            return try emitAtom(atom, params: &params, now: now)
        }
    }

    private static func emitAtom(_ a: SmartFolderAtom, params: inout [Any], now: Date) throws -> String {
        // Special virtual fields not in DB schema
        switch a.field {
        case .managed:
            // managed=true means folder exists & not hidden (Slice A: all roots managed)
            // For Slice A we don't filter — every indexed image is in some managed root.
            return "1"
        case .hidden:
            // hidden=false means image's folder hide state is false (Slice A: no subfolder hides)
            return "0 = 0"  // placeholder; Slice D wires real check
        case .dedupCanonicalOrNull:
            return "(dedup_canonical IS NULL OR dedup_canonical = 1)"
        case .filename, .relativePath, .format:
            return try emitStringAtom(a, column: a.field.rawValue, params: &params)
        case .fileSize, .dimensionsWidth, .dimensionsHeight:
            return try emitIntAtom(a, column: a.field.rawValue, params: &params)
        case .birthTime:
            return try emitTimeAtom(a, column: "birth_time", params: &params, now: now)
        }
    }

    private static func emitStringAtom(_ a: SmartFolderAtom, column: String, params: inout [Any]) throws -> String {
        switch a.op {
        case .eq:
            guard case .string(let v) = a.value else { throw SmartFolderQueryError.typeMismatch(field: a.field, value: a.value) }
            params.append(v)
            return "\(column) = ?"
        case .ne:
            guard case .string(let v) = a.value else { throw SmartFolderQueryError.typeMismatch(field: a.field, value: a.value) }
            params.append(v)
            return "\(column) != ?"
        case .contains:
            guard case .string(let v) = a.value else { throw SmartFolderQueryError.typeMismatch(field: a.field, value: a.value) }
            params.append("%\(v)%")
            return "\(column) LIKE ?"
        case .startsWith:
            guard case .string(let v) = a.value else { throw SmartFolderQueryError.typeMismatch(field: a.field, value: a.value) }
            params.append("\(v)%")
            return "\(column) LIKE ?"
        case .inSet:
            guard case .stringArray(let xs) = a.value else { throw SmartFolderQueryError.typeMismatch(field: a.field, value: a.value) }
            let placeholders = xs.map { _ in "?" }.joined(separator: ",")
            params.append(contentsOf: xs as [Any])
            return "\(column) IN (\(placeholders))"
        default:
            throw SmartFolderQueryError.unsupportedFieldOpCombo(field: a.field, op: a.op)
        }
    }

    private static func emitIntAtom(_ a: SmartFolderAtom, column: String, params: inout [Any]) throws -> String {
        guard case .int(let v) = a.value else { throw SmartFolderQueryError.typeMismatch(field: a.field, value: a.value) }
        switch a.op {
        case .greaterThan: params.append(v); return "\(column) > ?"
        case .lessThan: params.append(v); return "\(column) < ?"
        case .eq: params.append(v); return "\(column) = ?"
        case .ne: params.append(v); return "\(column) != ?"
        default: throw SmartFolderQueryError.unsupportedFieldOpCombo(field: a.field, op: a.op)
        }
    }

    private static func emitTimeAtom(_ a: SmartFolderAtom, column: String, params: inout [Any], now: Date) throws -> String {
        switch a.op {
        case .betweenDuration:
            guard case .relativeTimeRange(let s, let e) = a.value else {
                throw SmartFolderQueryError.typeMismatch(field: a.field, value: a.value)
            }
            let startTs = resolveRelativeTime(s, now: now)
            let endTs = resolveRelativeTime(e, now: now)
            params.append(startTs)
            params.append(endTs)
            return "(\(column) >= ? AND \(column) <= ?)"
        case .greaterThan:
            guard case .double(let v) = a.value else { throw SmartFolderQueryError.typeMismatch(field: a.field, value: a.value) }
            params.append(v); return "\(column) > ?"
        case .lessThan:
            guard case .double(let v) = a.value else { throw SmartFolderQueryError.typeMismatch(field: a.field, value: a.value) }
            params.append(v); return "\(column) < ?"
        default:
            throw SmartFolderQueryError.unsupportedFieldOpCombo(field: a.field, op: a.op)
        }
    }

    private static func resolveRelativeTime(_ token: String, now: Date) -> Double {
        if token == "now" { return now.timeIntervalSince1970 }
        // Format like "-7d", "-30d", "+1d"
        if let last = token.last, last == "d",
           let n = Int(token.dropLast()) {
            return now.addingTimeInterval(TimeInterval(n) * 86400).timeIntervalSince1970
        }
        // Fallback: try ISO 8601
        let fmt = ISO8601DateFormatter()
        if let d = fmt.date(from: token) {
            return d.timeIntervalSince1970
        }
        return now.timeIntervalSince1970
    }
}
```

- [ ] **Step 2**: `make build` 验证。

- [ ] **Step 3**: Commit.

```bash
git add Glance/SmartFolder/SmartFolderQueryBuilder.swift
git commit -m "Slice A.9: SmartFolderQueryBuilder (Predicate → SQL) [wip]"
```

---

### Task A.10: SmartFolderEngine（执行查询返回 [IndexedImage]）

**Files:**
- Create: `Glance/SmartFolder/SmartFolderEngine.swift`

**Goal:** 串联 builder + IndexStore：给一个 SmartFolder 返回 [IndexedImage]。

**Steps:**

- [ ] **Step 1**: 创建 `Glance/SmartFolder/SmartFolderEngine.swift`。

```swift
import Foundation

final class SmartFolderEngine {

    let store: IndexStore

    init(store: IndexStore) {
        self.store = store
    }

    func execute(_ folder: SmartFolder, now: Date = Date(), limit: Int? = nil) throws -> [IndexedImage] {
        let compiled = try SmartFolderQueryBuilder.compile(folder, now: now)
        return try store.fetch(compiled, limit: limit)
    }
}
```

- [ ] **Step 2**: `make build` 验证。

- [ ] **Step 3**: Commit.

```bash
git add Glance/SmartFolder/SmartFolderEngine.swift
git commit -m "Slice A.10: SmartFolderEngine (compile + execute) [wip]"
```

---

### Task A.11: BuiltInSmartFolders（"全部最近" hard-coded）

**Files:**
- Create: `Glance/SmartFolder/BuiltInSmartFolders.swift`

**Goal:** 把 Slice A 的唯一 built-in smart folder "全部最近" 定义住。

**Steps:**

- [ ] **Step 1**: 创建 `Glance/SmartFolder/BuiltInSmartFolders.swift`。

```swift
import Foundation

enum BuiltInSmartFolders {

    /// All built-ins in display order. Slice A: 1 only. Slice B+C will add "本周新增".
    static let all: [SmartFolder] = [allRecent]

    static let allRecent: SmartFolder = SmartFolder(
        id: "all-recent",
        displayName: "全部最近",
        predicate: .and([
            .atom(.init(field: .managed, op: .eq, value: .bool(true))),
            .atom(.init(field: .hidden, op: .eq, value: .bool(false))),
            .atom(.init(field: .dedupCanonicalOrNull, op: .eq, value: .bool(true)))
        ]),
        sortBy: .birthTime,
        sortDescending: true,
        isBuiltIn: true
    )
}
```

- [ ] **Step 2**: `make build` 验证。

- [ ] **Step 3**: Commit.

```bash
git add Glance/SmartFolder/BuiltInSmartFolders.swift
git commit -m "Slice A.11: BuiltInSmartFolders (全部最近 only) [wip]"
```

---

### Task A.12: SmartFolderStore（ObservableObject UI 状态）

**Files:**
- Create: `Glance/SmartFolder/SmartFolderStore.swift`

**Goal:** 桥接 SmartFolderEngine 和 SwiftUI——选中一个 smart folder → 触发查询 → 发布 `[IndexedImage]`。

**Steps:**

- [ ] **Step 1**: 创建 `Glance/SmartFolder/SmartFolderStore.swift`。

```swift
import Foundation
import SwiftUI

@MainActor
final class SmartFolderStore: ObservableObject {

    @Published var availableSmartFolders: [SmartFolder] = BuiltInSmartFolders.all
    @Published var selected: SmartFolder?
    @Published var queryResult: [IndexedImage] = []
    @Published var isQuerying: Bool = false
    @Published var lastError: String?

    let engine: SmartFolderEngine

    init(engine: SmartFolderEngine) {
        self.engine = engine
    }

    /// Select a smart folder and refresh its query result.
    func select(_ folder: SmartFolder?) async {
        selected = folder
        await refreshSelected()
    }

    /// Re-execute the currently-selected smart folder query.
    func refreshSelected() async {
        guard let folder = selected else {
            queryResult = []
            return
        }
        isQuerying = true
        lastError = nil
        defer { isQuerying = false }

        do {
            let result = try await Task.detached(priority: .userInitiated) {
                try self.engine.execute(folder)
            }.value
            queryResult = result
        } catch {
            lastError = "\(error)"
            queryResult = []
        }
    }
}
```

- [ ] **Step 2**: `make build` 验证。

- [ ] **Step 3**: Commit.

```bash
git add Glance/SmartFolder/SmartFolderStore.swift
git commit -m "Slice A.12: SmartFolderStore @MainActor ObservableObject [wip]"
```

---

### Task A.13: GlanceApp 注入 IndexStoreHolder

**Files:**
- Modify: `Glance/GlanceApp.swift`
- Create: `Glance/IndexStore/IndexStoreHolder.swift`

**Goal:** 在 V1 现有 `GlanceApp` 的 `init()` block 模式下扩展，加 `IndexStoreHolder` @StateObject 作为 IndexStore 异步初始化的 holder。**保留 V1 全部现有状态**：`bookmarkManager` / `folderStore(bookmarkManager:)` / `appState` / `@NSApplicationDelegateAdaptor(AppDelegate)` / `commands { CommandGroup(replacing: .appInfo) { AboutMenuButton() } }` / `.onAppear { folderStore.loadSavedFolders() }`。

**V1 已不在 GlanceApp 内的项**（plan 早期版本提及，V1 已重构出去，A.13 不动）：
- 关于窗口：V1 改为 `AboutWindowController.shared.show()`（AppKit）取代原 SwiftUI `Window("关于一眼", id: "about")` scene（commit 20fa509，修关于面板首次显示位置跳跃）
- 外观模式：V1 改为 `NSApp.appearance` via `WindowAccessor` 取代 `.preferredColorScheme(...)` modifier（commit 2b858cf，修跟随系统外观不生效）

V1 真实 `init()` 形态（已 Read 验证）：

```swift
init() {
    let bm = BookmarkManager()
    _bookmarkManager = StateObject(wrappedValue: bm)
    _folderStore = StateObject(wrappedValue: FolderStore(bookmarkManager: bm))
}
```

`FolderStore.init` 必须传 `bookmarkManager: BookmarkManager`，**不存在默认 init**。

**Steps:**

- [ ] **Step 1**: 创建 `Glance/IndexStore/IndexStoreHolder.swift`——异步包装可能 throw 的 IndexStore 初始化。

```swift
import Foundation
import SwiftUI

@MainActor
final class IndexStoreHolder: ObservableObject {
    @Published var store: IndexStore?
    @Published var initError: String?
    /// Boolean 跟随 store 是否非 nil。让 ContentView 用 `.onChange(of: isReady)` 观察
    /// （Bool 是 Equatable，IndexStore class 不是），避免 SwiftUI .onChange 编译错。
    @Published var isReady: Bool = false

    init() {
        Task { await self.bootstrap() }
    }

    private func bootstrap() async {
        do {
            let s = try IndexStore()
            self.store = s
            self.isReady = true
        } catch {
            self.initError = "\(error)"
            print("[IndexStoreHolder] init failed: \(error)")
        }
    }
}
```

- [ ] **Step 2**: 修改 `Glance/GlanceApp.swift`，在 V1 现有 init block 末尾加 IndexStoreHolder 初始化。最终 GlanceApp struct 形态（**仅在 V1 基础上加 3 行**，其他保持原样）：

```swift
@main
struct GlanceApp: App {
    @StateObject private var bookmarkManager: BookmarkManager
    @StateObject private var folderStore: FolderStore
    @StateObject private var appState = AppState()
    @StateObject private var indexStoreHolder: IndexStoreHolder    // ← V2 新增

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        let bm = BookmarkManager()
        _bookmarkManager = StateObject(wrappedValue: bm)
        _folderStore = StateObject(wrappedValue: FolderStore(bookmarkManager: bm))
        _indexStoreHolder = StateObject(wrappedValue: IndexStoreHolder())  // ← V2 新增
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(bookmarkManager)
                .environmentObject(folderStore)
                .environmentObject(appState)
                .environmentObject(indexStoreHolder)               // ← V2 新增
                .onAppear {
                    folderStore.loadSavedFolders()
                }
        }
        .defaultSize(width: 1280, height: 800)
        .commands {
            // V1 重构：用 AppKit AboutWindowController 取代 SwiftUI Window scene（commit 20fa509）
            CommandGroup(replacing: .appInfo) {
                AboutMenuButton()
            }
        }
    }
}
```

**注意**：
- `AboutMenuButton` / `AppDelegate` / `AboutWindowController.shared.show()` 调用链是 V1 现有，A.13 不动
- 无 `Window("关于一眼")` scene（V1 已删，关于窗口走 AppKit 层）
- 无 `.preferredColorScheme(...)` modifier（V1 改用 `NSApp.appearance` via `WindowAccessor`，commit 2b858cf）
- 不引入 placeholder pattern——`SmartFolderStore` 创建推迟到 ContentView（task A.17）使用 `@StateObject` placeholder + attach 模式，那时 `IndexStoreHolder.store` 已 ready

- [ ] **Step 3**: `make build` 验证。

- [ ] **Step 4**: Commit。

```bash
git add Glance/GlanceApp.swift Glance/IndexStore/IndexStoreHolder.swift
git commit -m "Slice A.13: GlanceApp 注入 IndexStoreHolder [wip]"
```

---

### Task A.14: FolderStore → IndexStore bridge（注册 root + 触发首次扫描）

**Files:**
- Create: `Glance/IndexStore/FolderStoreIndexBridge.swift`
- **不修改** `Glance/FolderBrowser/FolderStore.swift`（V1 已有 `@Published var rootFolders: [FolderNode]`，bridge 直接观察）

**Goal:** 当 `folderStore.rootFolders` 数组变化（V1 已有 `addFolder(from:)` / `removeFolder(_:)` 的产出）→ bridge 注册新 root 到 IndexStore + 启动 FolderScanner 异步扫描。**最小侵入**：bridge 由 ContentView 在 IndexStore ready 后创建，订阅 `folderStore.$rootFolders` 变化（用 SwiftUI `.onChange` 而非 Combine sink，符合 CLAUDE.md "禁止 Combine" 规则）。FolderStore 本身 0 改动。

**关键 V1 事实**（已 Read 验证）：
- `FolderStore.rootFolders: [FolderNode]` 是 `@Published`，`FolderNode` 含 `url: URL`
- V1 `addFolder(from:autoSelect:)` 已 `bookmarkManager.startAccessing(url)` + 异步 `discoverTree`，bridge 拿到 url 时 security-scoped access 已开启
- `FolderStore.removeFolder(_:)` 已 `stopAccessing` + `removeBookmark`，bridge 收到 rootFolders 减少 diff 时跟随删除

**Steps:**

- [ ] **Step 1**: 创建 `Glance/IndexStore/FolderStoreIndexBridge.swift`。

```swift
import Foundation
import SwiftUI

@MainActor
final class FolderStoreIndexBridge: ObservableObject {

    let indexStore: IndexStore
    /// Track which root URLs we've already registered (by standardized path)
    /// to avoid duplicate registration / rescan.
    private var registeredPaths: Set<String> = []

    init(indexStore: IndexStore) {
        self.indexStore = indexStore
    }

    /// Diff incoming rootFolders vs registered set; register/scan new ones.
    /// Removed folders are NOT cleaned up in Slice A (Slice G FSEvents will revisit).
    /// Caller (ContentView) invokes whenever folderStore.rootFolders changes.
    func sync(with rootFolders: [FolderNode]) async {
        let incomingPaths = Set(rootFolders.map { $0.url.standardizedFileURL.path })
        let newRoots = rootFolders.filter { !registeredPaths.contains($0.url.standardizedFileURL.path) }
        for node in newRoots {
            await registerAndScan(rootURL: node.url)
            registeredPaths.insert(node.url.standardizedFileURL.path)
        }
        // Slice A: removed roots leave stale rows in IndexStore; Slice G handles cleanup
        _ = incomingPaths  // reserved for Slice G diff usage
    }

    /// Register one root + scan in background. Security-scoped access is
    /// assumed already started by V1 BookmarkManager.startAccessing(url).
    /// **幂等**：registerRoot 用 path 做 unique 键，重启同一 path 复用 id；
    /// FolderScanner 内 INSERT OR IGNORE 配合 UNIQUE(folder_id, relative_path)。
    private func registerAndScan(rootURL: URL) async {
        let normalizedPath = rootURL.standardizedFileURL.path
        do {
            let bookmark = try rootURL.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            let folderId = try indexStore.registerRoot(path: normalizedPath, bookmark: bookmark)

            // 在 detached task 之外把 indexStore 引用 capture 进局部 let，避免
            // capturing self 触发 Sendable 警告。indexStore 是 class，引用本身可跨边界。
            let store = self.indexStore
            await Task.detached(priority: .utility) {
                let scanner = FolderScanner(store: store)
                do {
                    try scanner.scan(rootURL: rootURL, folderId: folderId) { progress in
                        if progress.totalScanned % 200 == 0 {
                            print("[IndexStore] scanned \(progress.totalScanned), indexed \(progress.totalIndexed)")
                        }
                    }
                    print("[IndexStore] scan complete for \(rootURL.path)")
                } catch {
                    print("[IndexStore] scan FAILED for \(rootURL.path): \(error)")
                }
            }.value
        } catch {
            print("[IndexStore] registerAndScan FAILED for \(rootURL.path): \(error)")
        }
    }
}
```

- [ ] **Step 2**: ContentView 的 wiring 放到 task A.16（一并改 ContentView 时合并）。**本 task 仅产出 bridge 文件**，build 应通过。

- [ ] **Step 3**: `make build` 验证。

- [ ] **Step 4**: Commit。

```bash
git add Glance/IndexStore/FolderStoreIndexBridge.swift
git commit -m "Slice A.14: FolderStoreIndexBridge (sync + scan) [wip]"
```

---

### Task A.15: SmartFolderListView（sidebar 智能文件夹区 UI）

**Files:**
- Create: `Glance/FolderBrowser/SmartFolderListView.swift`

**Goal:** Sidebar 顶部显示 ⚙️ smart folder list（M1 仅一个 "全部最近"），点击 → 触发 SmartFolderStore.select。

**Steps:**

- [ ] **Step 1**: 创建 `Glance/FolderBrowser/SmartFolderListView.swift`。

```swift
import SwiftUI

struct SmartFolderListView: View {

    @EnvironmentObject var smartFolderStore: SmartFolderStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(smartFolderStore.availableSmartFolders) { folder in
                SmartFolderRow(folder: folder, isSelected: smartFolderStore.selected?.id == folder.id)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        Task { await smartFolderStore.select(folder) }
                    }
            }
        }
    }
}

private struct SmartFolderRow: View {
    let folder: SmartFolder
    let isSelected: Bool

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(isSelected ? .pink : .secondary)
            Text(folder.displayName)
                .font(.body)
                .foregroundStyle(isSelected ? Color.primary : Color.primary.opacity(0.85))
            Spacer()
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.xs)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
    }
}
```

> **DS.Spacing 真实命名**（已 Read `Glance/DesignSystem.swift` 验证）：`xs=4 / sm=8 / md=16 / lg=24 / xl=32`。本 plan 全部使用 `.sm` `.md` 等真实名（之前使用 `.s` `.m` 已修正）。

- [ ] **Step 2**: `make build` 验证。

- [ ] **Step 3**: Commit.

```bash
git add Glance/FolderBrowser/SmartFolderListView.swift
git commit -m "Slice A.15: SmartFolderListView (sidebar gear icon list) [wip]"
```

---

### Task A.16: SmartFolderGridView（cross-folder grid 显示）

> **Note**: A.16 ↔ A.17 在 codex review 后**互换位置**——SmartFolderGridView 必须先创建（A.16），ContentView 改造（A.17）才能引用 `SmartFolderGridView()` 类型。原编号下 A.16 ContentView 引用了不存在的 SmartFolderGridView，编译会 fail。

**Files:**
- Create: `Glance/FolderBrowser/SmartFolderGridView.swift`

**Goal:** 显示 SmartFolderStore.queryResult 的图，复用 V1 顶层 `loadThumbnail(url:maxPixelSize:)` 函数。

**关键 V1 事实**（已 Read 验证）：
- V1 `Glance/FolderBrowser/ImageGridView.swift:258` 顶层 internal 函数 `loadThumbnail(url:maxPixelSize:) async -> NSImage?`：复用，不重写
- DS 命名（已 Read DesignSystem.swift 验证）：`DS.Spacing.sm/md/xs/xl` ✓；`DS.Thumbnail.cornerRadius` ✓；`DS.Color.gridBackground` / `DS.Color.appBackground` 由 V1 决策 #6 保证存在

**Steps:**

- [ ] **Step 1**: 创建 `Glance/FolderBrowser/SmartFolderGridView.swift`。

```swift
import SwiftUI

struct SmartFolderGridView: View {

    @EnvironmentObject var smartFolderStore: SmartFolderStore

    private let columns = [
        GridItem(.adaptive(minimum: 140, maximum: 200), spacing: DS.Spacing.sm)
    ]

    var body: some View {
        ScrollView {
            if smartFolderStore.queryResult.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: columns, spacing: DS.Spacing.sm) {
                    ForEach(smartFolderStore.queryResult) { image in
                        SmartFolderImageCell(image: image)
                    }
                }
                .padding(DS.Spacing.md)
            }
        }
        .background(DS.Color.gridBackground)
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: DS.Spacing.md) {
            if smartFolderStore.isQuerying {
                ProgressView()
                Text("正在加载...")
                    .foregroundStyle(.secondary)
            } else {
                Text("暂无图片")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text("受管文件夹里没找到图片，或还在首次扫描")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DS.Spacing.xl)
    }
}

private struct SmartFolderImageCell: View {
    let image: IndexedImage
    @State private var thumbnail: NSImage?

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Group {
                if let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 140)
            .background(DS.Color.appBackground)
            .clipShape(RoundedRectangle(cornerRadius: DS.Thumbnail.cornerRadius))

            Text(image.filename)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .help(image.relativePath)   // hover tooltip 显示完整 relative path（D5）
        .task(id: image.id) {
            await loadThumb()
        }
    }

    /// 加载缩略图：解析 security-scoped bookmark → 调 V1 顶层 loadThumbnail。
    private func loadThumb() async {
        var stale = false
        guard let url = try? URL(
            resolvingBookmarkData: image.urlBookmark,
            options: [.withSecurityScope],
            bookmarkDataIsStale: &stale
        ) else { return }
        let didStart = url.startAccessingSecurityScopedResource()
        defer { if didStart { url.stopAccessingSecurityScopedResource() } }

        // ↓ 复用 V1 ImageGridView.swift 顶层 internal 函数
        let thumb = await loadThumbnail(url: url, maxPixelSize: 280)
        await MainActor.run {
            self.thumbnail = thumb
        }
    }
}
```

- [ ] **Step 2**: `make build` 验证。

- [ ] **Step 3**: Commit。

```bash
git add Glance/FolderBrowser/SmartFolderGridView.swift
git commit -m "Slice A.16 (was A.17): SmartFolderGridView 复用 V1 loadThumbnail [wip]"
```

---

### Task A.17: ContentView 改造（2 栏 NavigationSplitView 内 sidebar 上下分段 + 主区条件切换）

> **Note**: A.16 ↔ A.17 在 codex review 后**互换位置**——本 task 现编号 A.17，依赖 A.16 创建的 `SmartFolderGridView` 类型。

**Files:**
- Modify: `Glance/ContentView.swift`
- Modify: `Glance/SmartFolder/SmartFolderStore.swift`

**Goal:** 在 V1 现有两栏 `NavigationSplitView { sidebar } detail: { ... }` 形态下：
- sidebar 改为 VStack（SmartFolderListView + Divider + FolderSidebarView）
- detail 内 mainContent 区根据 `smartFolderStore.selected` 切换 SmartFolderGridView vs V1 现有内容
- **`.environmentObject(smartFolderStore)` 注入**给 sidebar + detail 两棵 view tree（children 用 @EnvironmentObject）
- IndexStore ready 后通过**幂等** `wireIfReady()` 同时被 `.onAppear` 和 `.onChange(of: indexStoreHolder.isReady)` 调（race-proof，Bool 是 Equatable）

**保留 V1 全部状态和行为不动**：
- State：`showInspector` / `quickViewerIndex` / `quickViewerEntry` / `previewFocusTrigger` / `gridFocusTrigger` / `previewVM` / `inspectorURL`
- Type：`QuickViewerEntry` enum（V1 私有 enum，commit 02a36dc 修 Bug 4 引入）
- Modifier：`.toolbar` / `.toolbarBackground(.hidden, for: .windowToolbar)`（V1 修 toolbar 横条断层加，commit c0c833a）
- Overlay：`.overlay { QuickViewerOverlay(onDismiss + onIndexChange) }`（onIndexChange 闭包 V1 commit 02a36dc 加）
- onChange handlers：V1 现有 `.onChange(of: quickViewerIndex / selectedFolder / selectedImageIndex / images)` 全部不动；A.17 加的 onChange（rootFolders / smartFolderStore.selected / 焦点路由）是新增 handler

**关键 V1 事实**（已 Read 验证，merge main 后真实当前状态）：
- 两栏 NavigationSplitView（sidebar + detail），不是三栏
- `folderStore.selectedFolder` 是 V1 选中态；不存在 `clearSelection()` 方法
- IndexStoreHolder（A.13）现有 `@Published var isReady: Bool`——让 `.onChange` 观察 Bool 而不是 non-Equatable IndexStore?
- ContentView 当前 204 行（merge main 后）；`var body` 从 line 38 起；`mainContent` 从 line 158 起
- V1 私有 `QuickViewerEntry` enum 定义在 ContentView struct **之外**（line 11-14），A.17 改造时不要把 V1 这个 enum 移进 struct 内

**Steps:**

- [ ] **Step 1**: 在 ContentView 加 V2 新状态：

```swift
@EnvironmentObject var indexStoreHolder: IndexStoreHolder
@StateObject private var smartFolderStore = SmartFolderStore.placeholder()
@State private var indexBridge: FolderStoreIndexBridge?
@State private var didWire: Bool = false   // 防 wireIfReady 重入
```

- [ ] **Step 2**: SmartFolderStore 加 `placeholder()` + `attach(engine:)` 模式（engine 改 optional var）。修改 `Glance/SmartFolder/SmartFolderStore.swift`：

```swift
@MainActor
final class SmartFolderStore: ObservableObject {
    @Published var availableSmartFolders: [SmartFolder] = BuiltInSmartFolders.all
    @Published var selected: SmartFolder?
    @Published var queryResult: [IndexedImage] = []
    @Published var isQuerying: Bool = false
    @Published var lastError: String?

    var engine: SmartFolderEngine?

    init(engine: SmartFolderEngine?) { self.engine = engine }

    static func placeholder() -> SmartFolderStore { SmartFolderStore(engine: nil) }
    func attach(engine: SmartFolderEngine) { self.engine = engine }

    func select(_ folder: SmartFolder?) async {
        selected = folder
        await refreshSelected()
    }

    func refreshSelected() async {
        guard let folder = selected, let eng = engine else {
            queryResult = []
            return
        }
        isQuerying = true
        lastError = nil
        defer { isQuerying = false }

        // capture engine into local before detach to avoid Sendable warning
        let capturedEngine = eng
        do {
            let result = try await Task.detached(priority: .userInitiated) {
                try capturedEngine.execute(folder)
            }.value
            queryResult = result
        } catch {
            lastError = "\(error)"
            queryResult = []
        }
    }
}
```

- [ ] **Step 3**: NavigationSplitView sidebar 改 VStack 三段 + **两处 `.environmentObject` 注入**：

```swift
NavigationSplitView {
    VStack(alignment: .leading, spacing: 0) {
        SmartFolderListView()
            .padding(.top, DS.Spacing.sm)
            .padding(.horizontal, DS.Spacing.xs)

        Divider()
            .padding(.vertical, DS.Spacing.xs)

        FolderSidebarView()
    }
    .navigationSplitViewColumnWidth(min: DS.Sidebar.minWidth, ideal: DS.Sidebar.width, max: DS.Sidebar.maxWidth)
    .environmentObject(smartFolderStore)   // ★ sidebar tree 注入（SmartFolderListView 用）
} detail: {
    HStack(spacing: 0) {
        mainContent
        if showInspector {
            // 注意：V1 已删独立 Divider（commit 086ade2 修粉色 focus ring 时改用 Inspector 自带
            // leading overlay，靠 DS.Inspector.separatorWidth = 0.5pt overlay 渲染分割线）。
            // A.17 不要重新加 Divider()。
            ImageInspectorView(url: inspectorURL)
                .frame(width: DS.Inspector.width)
                .transition(.move(edge: .trailing).combined(with: .opacity))
        }
    }
    .animation(DS.Anim.normal, value: showInspector)
    .toolbar { /* V1 现有 toolbar 不动 */ }
    .environmentObject(smartFolderStore)   // ★ detail tree 注入（SmartFolderGridView 用）
}
.overlay {
    /* V1 .overlay { QuickViewerOverlay } 不动 */
}
```

> **关键修复**：sidebar **和** detail **都**加 `.environmentObject(smartFolderStore)`——SwiftUI EnvironmentObject 走 view tree 注入，sidebar/detail 是 NavigationSplitView 的两棵独立 view tree。**注一处不够会触发 "No ObservableObject of type SmartFolderStore found" 运行时崩**。

- [ ] **Step 4**: 把 V1 现有的 mainContent（grid + 内嵌预览的 if 切换）抽成 `private var v1MainContent: some View`，新建 `private var mainContent`：

```swift
@ViewBuilder
private var mainContent: some View {
    if smartFolderStore.selected != nil {
        SmartFolderGridView()
    } else {
        v1MainContent
    }
}
```

- [ ] **Step 5**: 加幂等 `wireIfReady()` + 双触发避免 race。

```swift
/// 幂等 wire-up：IndexStore ready 后初始化 engine + bridge + 默认选中。
/// 同时被 .onAppear 和 .onChange(of: indexStoreHolder.isReady) 调，
/// didWire flag 守卫防重入；任何一条到达都成功。
private func wireIfReady() async {
    guard !didWire, let store = indexStoreHolder.store else { return }
    didWire = true

    let engine = SmartFolderEngine(store: store)
    smartFolderStore.attach(engine: engine)
    indexBridge = FolderStoreIndexBridge(indexStore: store)
    await indexBridge?.sync(with: folderStore.rootFolders)

    if smartFolderStore.selected == nil {
        await smartFolderStore.select(BuiltInSmartFolders.allRecent)
    } else {
        await smartFolderStore.refreshSelected()
    }
}
```

挂在 NavigationSplitView 的 modifier 上：

```swift
.onAppear {
    Task { await wireIfReady() }
}
.onChange(of: indexStoreHolder.isReady) { _, ready in
    guard ready else { return }
    Task { await wireIfReady() }
}
```

> **关键修复**：
> 1. `.onChange(of: indexStoreHolder.isReady)` 观察 **Bool**（Equatable）——原 plan 写 `.onChange(of: indexStoreHolder.store)` 是 IndexStore? 不 Equatable，**不编译**
> 2. `wireIfReady` 用 `didWire` 守卫防重入；若 `.onAppear` 时 store 已 ready（IndexStoreHolder bootstrap 比 ContentView 出现快）→ onAppear 一击成功；否则等 `.onChange` 触发。**两条路径任一到达都 OK**——race condition 消除

- [ ] **Step 6**: 加 rootFolders 变化时 trigger bridge sync + 当前 SF 重 query：

```swift
.onChange(of: folderStore.rootFolders) { _, newRoots in
    guard let bridge = indexBridge else { return }
    Task {
        await bridge.sync(with: newRoots)
        await smartFolderStore.refreshSelected()
    }
}
```

- [ ] **Step 7**: 加 selection 互斥（smart folder 选中 → 清 V1；反之亦然）：

```swift
.onChange(of: folderStore.selectedFolder) { _, newFolder in
    if newFolder != nil && smartFolderStore.selected != nil {
        Task { await smartFolderStore.select(nil) }
    }
}
.onChange(of: smartFolderStore.selected) { _, newSF in
    if newSF != nil && folderStore.selectedFolder != nil {
        folderStore.selectedFolder = nil
        folderStore.images = []
        folderStore.selectedImageIndex = nil
    }
}
```

> 注意：直接写 `selectedFolder = nil; images = []; selectedImageIndex = nil` 是 V1 `selectFolder(_:)` 反操作的 inline 复刻；V1 没 `clearSelection()` helper。Slice A 后续 refactor 候选项（不 block ship）。

- [ ] **Step 8**: `make build` 验证。

- [ ] **Step 9**: `make run` 视觉粗看：
  1. 启动 V2 → sidebar 上半 ⚙️ "全部最近" + 分隔线 + 下半 V1 folder tree
  2. 加 root folder → 等几秒（看 console log [IndexStore] scan complete）→ 主 grid 显示该 folder 的图（如果"全部最近"已默认选中）
  3. 点 V1 folder → 主区切到 V1 grid（V1 行为零退化）
  4. 点 ⚙️ "全部最近" → 主区切回 cross-folder grid
  5. QuickViewer / Inspector / 排序 / 键盘快捷键 全部正常

- [ ] **Step 10**: Commit。

```bash
git add Glance/ContentView.swift Glance/SmartFolder/SmartFolderStore.swift
git commit -m "Slice A.17 (was A.16): ContentView sidebar VStack + V2 wire-up + EnvironmentObject 注入 [wip]"
```

---

### Task A.18: 整体串联实测（happy path + 边界 audit）

> **Note**: A.17 的 `wireIfReady()` 已包含"默认选中全部最近"逻辑（store ready 后自动 select(allRecent)），原 plan A.18 step 1 单独再加 `.onAppear { select(allRecent) }` 现在是冗余 + 与 wireIfReady 抢先后顺序的潜在 race。本 task 改为"启动后端到端实测 + 边界 audit + 加幂等性场景测试"，**不写新代码**（除非实测发现 bug）。

**Files:**
- 仅可能 modify 已存在的 `Glance/ContentView.swift`（实测发现 bug 时）

**Goal:** Slice A 全部 task 实施完后跑端到端 happy path + 重启幂等性 + 文件夹增删测试，发现 P0 bug 即修，否则 commit。

**Steps:**

- [ ] **Step 1**: `make run` Happy path 测试：
  1. 启动 V2 → sidebar 上半 ⚙️ "全部最近"（默认高亮）+ 分隔线 + 下半 V1 folder tree
  2. 主区显示"暂无图片"（如还没 root folder）或扫描中 spinner
  3. 加 1 个含图的 root folder → console 输出 `[IndexStore] scan complete for ...` → 主 grid 自动出现该 folder 的图
  4. 切到 V1 folder tree 一具体 folder → 主区切回 V1 ImageGridView（V1 行为零退化）
  5. 切回 ⚙️ "全部最近" → 主区回到 cross-folder grid

- [ ] **Step 2**: 重启幂等性测试（**关键回归点**）：
  1. 关闭 V2
  2. 重启 V2 → console 不应再次跑 `[IndexStore] scan complete`（registerRoot path 去重 + INSERT OR IGNORE 配合 UNIQUE 约束 → 0 重复行）
  3. 主 grid 应直接出现已有图片（无需重扫）
  4. SQLite 验证：`sqlite3 ~/Library/Application\ Support/Glance/index.sqlite "SELECT count(*) FROM images;"` —— 多次重启 count 应稳定，不持续增长

- [ ] **Step 3**: 多 folder 测试：
  1. 加第 2 个 root folder → smart folder grid 显示**两个 folder 的图混排**（按 birth_time 倒序）
  2. 删除第 1 个 root folder → V1 sidebar 该 entry 消失；smart folder grid **暂仍显示该 folder 的旧图**（Slice G FSEvents 才会清理孤立行；本 Slice A 接受 known limitation，仅记入 PENDING）

- [ ] **Step 4**: 边界 case audit（如发现 P0 bug 修，P1+ 进 PENDING）：
  - 加一个 0 张图的空 folder → 应显示"暂无图片"而非崩
  - 加一个含 1 万张图的大 folder → 首次扫描有进度日志（Slice I 才有 UI），扫描期间 grid 渐进显示
  - smart folder 选中态 → 关 V2 → 重启 → 仍默认 ⚙️ "全部最近"（Slice A 不持久化用户选中态，每次启动都默认 allRecent）

- [ ] **Step 5**: Commit（端到端实测无 P0 bug）：

```bash
git commit --allow-empty -m "Slice A.18: 整体串联实测通过 (happy path + 重启幂等 + 多folder) [wip]"
```

> **Note**: 用 `--allow-empty` 因本 task 通常不写新代码；若 step 4 发现 bug 修了，对应 file 再 git add。

---

### Task A.19: Slice A 收尾——/go 五步 + Roadmap 更新 + PENDING

**Files:**
- Modify: `specs/Roadmap.md`（M1 进度段）
- Modify: `specs/PENDING-USER-ACTIONS.md`（追加 Slice A 人工测试项）

**Goal:** 完成 /go 标准收尾流程（verify + 文档同步 + PENDING + commit + push + 汇报）。本步 commit 用 clean message（不带 [wip]），让 pre-push codex 真正审查。

**Steps:**

- [ ] **Step 1**: 跑 verify.sh。

```bash
./scripts/verify.sh
```

红 → 修 → 重跑（最多 5 轮）。绿 → 进 step 2。

- [ ] **Step 2**: 文档同步。

更新 `specs/Roadmap.md`，在「V2 决策」段后加「V2 进度」段（如不存在），记录 Slice A 完成。

```markdown
### V2 进度

- [x] **Slice A**（thin cross-folder MVP，~2026-05-XX 完成 commit YYYY）：IndexStore + 单 folder scan + "全部最近" + Sidebar IA + cross-folder grid 跑通 → V2.0-beta1 ship-able
- [ ] Slice B（时间分段 sticky header）
- [ ] Slice C（"本周新增"，merged into B）
- [ ] Slice D（hide toggle 右键菜单 + Hover tooltip + Inspector source path）
- [ ] Slice G（FSEvents 增量监听）
- [ ] Slice H（内容去重 SHA256 + cheap-first）
- [ ] Slice I（首次索引进度 UI）
```

更新 `CLAUDE.md` 项目文件结构段，加 IndexStore/ 和 SmartFolder/ 目录。

- [ ] **Step 3**: PENDING 人工清单。`specs/PENDING-USER-ACTIONS.md` 追加：

```markdown
## Pending（V2 Slice A）

### 端到端基础
- [ ] 加 1 个含 ~100 张图的 root folder 到 V1 sidebar；3 秒内 ⚙️ "全部最近" grid 显示这些图
- [ ] 加第 2 个 root folder；切到 ⚙️ "全部最近" 应看到两个 folder 的图混在一起按 birth_time 倒序
- [ ] V1 sidebar 点选具体 folder → 主视图切到 V1 ImageGridView 显示该 folder 的图（V1 行为零退化）
- [ ] 切回 ⚙️ "全部最近" → 主视图回到 cross-folder grid

### 幂等性（codex review 重点）
- [ ] **应用关闭重启** → ⚙️ "全部最近" 默认选中且 grid 自动显示（IndexStore 持久化生效）
- [ ] **重启前后 image 行数稳定**：`sqlite3 ~/Library/Application\ Support/Glance/index.sqlite "SELECT count(*) FROM images;"` 在多次启动后 count 一致，不持续增长（验证 INSERT OR IGNORE + UNIQUE(folder_id, relative_path) 幂等）
- [ ] **重启前后 folder 行数稳定**：`sqlite3 ... "SELECT count(*) FROM folders WHERE root_url_bookmark IS NOT NULL;"` 多次启动后 count 等于 V1 已加 root folder 数，不重复
- [ ] **path 变化不破坏幂等**：把一个 root folder 在 Finder 重命名（同一磁盘位置）→ 重启 V2 → 不应出现重复 folder 行（registerRoot 用 standardizedFileURL.path 做 unique key）

### 视觉与文件系统
- [ ] index.sqlite 文件位于 `~/Library/Application Support/Glance/index.sqlite`，sqlite3 CLI 能查到 images / folders 表 + UNIQUE 索引
- [ ] hover 缩略图显示 relative path tooltip（D5）
- [ ] 加一个 1 万张图的 root folder：首次扫描 < 10 分钟（性能目标，非硬性 reject）；扫描期间 grid 渐进显示已索引图

### Slice A 已知 limitation（不阻塞 ship，记入待解段）
- [ ] **删 root folder 后智能文件夹 grid 仍显示该 folder 旧图**——Slice G FSEvents 才清理；Slice A 接受
- [ ] **首次大量索引无 UI 进度条**——只有 console log；Slice I 才有 overlay UI
- [ ] **未实现内容去重**（D3 SHA256）——Slice A 副本会出现两次显示；Slice H 才补
- [ ] **第 2 个内置 smart folder "本周新增"未上**——Slice B 加；Slice A only ship "全部最近" 1 个
- [ ] **smart folder 选中态不持久化跨重启**——每次启动重置默认 allRecent；非 M1 deliverable
```

- [ ] **Step 4**: Final commit（**不带 [wip]**，会触发 pre-push codex 审查）。

```bash
git add specs/Roadmap.md specs/PENDING-USER-ACTIONS.md CLAUDE.md
# 也 squash 之前所有 Slice A.X [wip] commits？
# Pragmatic：保留 [wip] commits 作为 history（记录 task-by-task 进展），最后只加文档同步 commit
git commit -m "Slice A 完成：跨文件夹浏览 thin MVP（IndexStore + SmartFolder + Sidebar IA + grid）→ V2.0-beta1"
```

- [ ] **Step 5**: Push。pre-push hook 触发 codex review，[P1] 阻塞会被指出。

```bash
git push
```

预期：codex 通过 → 推送成功；codex [P1] 阻塞 → 修对应问题再 push（如未通过审查不算 Slice A 完成）。

- [ ] **Step 6**: 汇报（口头/对话）：BUILD 状态首行 + Slice A deliverables 完成项 + commit hash + Pending 项数 + 下一 slice。

---

## Slice A 总览（19 tasks）

| Task | 估时 | Goal |
|---|---|---|
| A.1 | 2-3h | IndexDatabase sqlite3 thin wrapper（含 `var handle` 暴露）|
| A.2 | 3-4h | IndexStoreSchema v1：forward-looking + UNIQUE 约束（幂等）+ FK NULLable（避免自链死锁）|
| A.3 | 2h | IndexStore 高层入口 + auto-migrate |
| A.4 | 3-4h | ManagedFolder + folders 表 CRUD（registerRoot 幂等用 root_path UNIQUE）|
| A.5 | 5-7h | IndexedImage + 幂等 insertImageIfAbsent + 注入安全 fetch(_ compiled:) + 全 bind 检查 |
| A.6 | 3-4h | ImageMetadataReader |
| A.7 | 4-5h | FolderScanner（INSERT OR IGNORE 配合 UNIQUE）|
| A.8 | 4-5h | SmartFolder + Predicate/Atom（含 D6 user-rule validation）|
| A.9 | 4-6h | SmartFolderQueryBuilder（snake_case raw values 与 DB 列名对齐）|
| A.10 | 1-2h | SmartFolderEngine（调 fetch(_ compiled:)）|
| A.11 | 1h | BuiltInSmartFolders（全部最近）|
| A.12 | 2-3h | SmartFolderStore @MainActor + placeholder/attach 模式 |
| A.13 | 3-4h | GlanceApp 注入 IndexStoreHolder（含 isReady Bool 让 .onChange 可观察）|
| A.14 | 4-6h | FolderStore→IndexStore bridge + 首次扫描（path-based 幂等 dedup）|
| A.15 | 3-4h | SmartFolderListView UI |
| A.16 | 4-6h | **SmartFolderGridView**（codex review 后 swap：先建 grid 类型，A.17 才能引用）|
| A.17 | 5-7h | **ContentView 改造**（VStack sidebar + .environmentObject 注入 sidebar/detail 两处 + wireIfReady 幂等 + onChange isReady）|
| A.18 | 2-3h | 整体串联实测（happy path + 重启幂等 + 多 folder）|
| A.19 | 3-4h | /go 收尾 + Roadmap + PENDING + Final commit |

**Total Slice A**: ~70-90 小时 ≈ **9-13 工作日**（codex review 后从原 7-10 天上调，吸收 critical/high finding 修复 + idempotent + dedup 调整工作量）。

---

## Slices B-I 概要（待 Slice A ship 后各自 plan 之）

每个 slice 的详细 task / step / code / verify 计划在该 slice 启动时单独写一份（reuse `superpowers:writing-plans` skill），文件命名：`specs/v2/2026-XX-XX-m1-slice-X-plan.md`。

### Slice B: 时间分段 sticky header（2 天）

**Goal**: SmartFolderGridView 顶部出现 5 段固定时间标题（今天 / 昨天 / 本周 / 本月 / 更早），随滚动 sticky。

**Deliverables**:
- `Glance/FolderBrowser/TimeBucket.swift`（5 段枚举 + boundary 算法）✅ B-α
- SmartFolderGridView 改造为 LazyVGrid sectioned + sticky `pinnedViews` ✅ B-α
- 验收：滚动 grid 时段标题固定在顶部；跨午夜午夜段 0:01 截图正确归"昨天"段（人工测试 → PENDING）

**进度**：全部完成（2026-05-09 ship）。
- B-α：`25d6a94` 主体 + 4 轮 follow-up（`60a2de2` / `bd4cfa7` / `c5b048a` / `ef08f72`）
- B-β：`7e2893a`
- B-γ：本 commit（Roadmap ✅ + tag v2.0-beta2）

**Ship**: V2.0-beta2 ✓

### Slice C: 第 2 个 SF "本周新增"（0.5 天，merged into B）

**Goal**: BuiltInSmartFolders 加 `thisWeekAdded` instance；sidebar 自动显示。

**Deliverables**:
- `BuiltInSmartFolders.swift` 加 thisWeekAdded（rule: birth_time BETWEEN -7d/now）
- 验收：sidebar 出现两个 ⚙️ entry，切换显示对应结果

**Ship**: 跟 Slice B 一起 V2.0-beta2

### Slice D: hide toggle 右键菜单（root + 子目录两层 + 状态继承）（1.5 天）

**Goal**: V1 sidebar root folder + 子目录上右键 → "在智能文件夹中隐藏" toggle，状态可继承（hide root 默认 hide 整棵树，子目录可单独 unhide）。

**Deliverables**:
- folders 表写入 hide_in_smart_view（已有列）
- SmartFolderQueryBuilder.emitAtom 中 .hidden case 改为真实 SQL（之前 placeholder）
- FolderSidebarView 加 contextMenu
- 状态继承计算逻辑：walk path 找最具体的 explicit hide
- 验收：hide root → 智能文件夹 grid 该 root 图全消失；unhide 子目录 → 该子目录图重现

**Ship**: V2.0-beta3

### Slice E: Hover tooltip 显示 relative path（0.5 天，merged into D）

**Goal**: SmartFolderImageCell hover → 显示 tooltip = 完整 relative path（如 `工作素材/草稿/banner.png`）。

**Deliverables**:
- SmartFolderImageCell 加 `.help(image.relativePath)`
- 验收：鼠标停在缩略图上 1.5s 后浮出 path

**Ship**: 跟 Slice D 一起 V2.0-beta3

### Slice F: Inspector 来源 path + Show in Finder（0.5 天，merged into D）

**Goal**: V1 Inspector 在 smart folder 选中图时显示 absolute path + "在 Finder 中显示" 按钮。

**Deliverables**:
- ImageInspectorView 加来源段（absolute path + button）
- 按钮触发 NSWorkspace.shared.activateFileViewerSelecting
- 验收：smart folder grid 选图打开 Inspector → 显示完整 path + 按钮可用

**Ship**: 跟 Slice D 一起 V2.0-beta3

### Slice G: FSEvents 增量监听（2 天）

**Goal**: managed folder 文件变化（add/remove/modify）→ IndexStore 增量更新（不全量重扫）。

**Deliverables**:
- `Glance/IndexStore/FSEventsWatcher.swift`（CoreServices FSEventStream Swift wrapper）
- 每个 root 启动一个 stream
- 文件 created → 调 ImageMetadataReader + insertImage
- 文件 deleted → DELETE FROM images WHERE relative_path = ? AND folder_id = ?
- 文件 modified → UPDATE （仅元数据变更）
- 验收：在 Finder 拖一张图到 managed folder → 5s 内出现在智能文件夹 grid

**Ship**: V2.0-beta4

### Slice H: 内容去重 SHA256 + cheap-first（2 天）

**Goal**: 索引时按 D3 cheap-first 算法判定 dedup_canonical；smart folder 结果只显示 canonical（其他副本在 Inspector 副本段列出）。

**Deliverables**:
- 索引完一个 root 后，跑 dedup 后处理：GROUP BY (file_size, format) HAVING count > 1 → 对每组算 SHA256 → set canonical = earliest birth_time
- update SmartFolderQueryBuilder .dedupCanonicalOrNull 逻辑（已 placeholder，确认 SQL 正确）
- ImageInspectorView 加副本段（query 同 SHA256 其他 url）
- 验收：cp 一张图到第二个 managed folder → smart folder grid 仍只显示 1 张 + Inspector 副本段显示 2 个 path

**Ship**: V2.0-beta5

### Slice I: 首次索引进度 UI + 错误处理（1 天）

**Goal**: 首次大批量扫描时显示进度 overlay（"正在索引 X / Y"），可中途取消恢复（保存当前 cursor）。

**Deliverables**:
- `Glance/IndexStore/IndexingProgressView.swift`（progress overlay UI）
- IndexStoreHolder 暴露 @Published progress: Double
- FolderScanner 增加 cancel token（CancellationToken pattern）
- 进度持久化（保存 last_processed_path） → 重启后从断点继续
- 错误处理：扫描失败用 banner 通知用户，不阻塞主 UI
- 验收：1 万张图 root 加入时显示进度条；扫描中关 V2，重开继续不重头

**Ship**: V2.0 RC（M1 全部 deliverable 齐 + 性能目标过 → 正式 V2.0 GA）

---

## M1 完成判定

M1 完成需所有 Slice A-I ship + 以下整体验收过：

1. **三段式 verify**（`./scripts/verify.sh`）零 error 零 warning
2. **PENDING-USER-ACTIONS** Slice A-I 所有项 ✓
3. **回归**：V1 既有功能（QuickViewer / Inspector / 文件夹浏览 / 排序 / 键盘快捷键 / 全屏 / 外观模式）零退化
4. **性能目标**：1 万张图首次索引 < 10min，FSEvents 增量响应 < 5s，smart folder query < 200ms
5. **GitHub release V2.0**（DMG notarized + signed，参照 V1 release pipeline）

---

## Self-Review

**Spec coverage check** (against `specs/v2/2026-05-06-v2-design.md`):

- ✅ § 2 IA（Sidebar 智能文件夹区 + 分隔线 + V1 tree） → Slice A.15 + A.17（A.17 = ContentView 改造）
- ✅ § 3 核心模块清单 IndexStore / SmartFolderEngine / Search / SimilarityService → Slice A 覆盖前两个；Search/Similarity 是 M2/M3 范围
- ✅ § 4 IndexStore schema forward-looking → Slice A.2 + A.5
- ✅ § 5 规则引擎 AND/OR + 5 段时间分段 → Slice A.8-A.10（规则引擎），Slice B（时间分段）
- ✅ § 7 M1 deliverables → **codex review 后澄清**：M1 = Slice A-I 累积 deliverables，不是 Slice A 单独完成 M1。Slice A ship 1 内置 SF + 无 dedup + 无时间分段，**这是 V2.0-beta1 = Slice A**，不是"M1 完成"
- ✅ § 8 不做清单 → 不在 plan 范围内

**Placeholder scan**: 无 TODO / TBD / "implement later"。

**Type consistency**: SmartFolder.id (String) / SmartFolderPredicate / IndexStore.fetch(_ compiled:) 签名一致；ManagedFolder.id (Int64) 与 IndexedImage.folderId (Int64) 一致；SmartFolderStore.engine 在所有引用处统一为 `SmartFolderEngine?`（attach 模式）；ManagedFolder.parentRootId: Int64? 与 schema parent_root_id NULLable 一致；SmartFolderField.rawValue 与 DB column name（snake_case）一致。

**Codex consult review** (session `019dfca8-...`)，Critical/High findings 已修：

| Finding | 修复位置 | 说明 |
|---|---|---|
| C: parent_root_id NOT NULL + 自链 FK 死锁 | A.2 schema | parent_root_id NULLable，root 行 NULL，FK 不触发 |
| C: A.16/A.17 dependency reversal | A.16/A.17 swap | SmartFolderGridView 现 A.16，ContentView 改造现 A.17，引用顺序对 |
| C: EnvironmentObject 未注入 → 运行时崩 | A.17 step 3 | sidebar + detail 两处都 `.environmentObject(smartFolderStore)` |
| C: `.onChange(of: store)` 不 Equatable 编译 fail | A.13 + A.17 step 5 | IndexStoreHolder 加 `isReady: Bool`，观察 Bool 而非 IndexStore? |
| H: 幂等性缺失 → 重启复制 | A.2 schema + A.4 + A.5 + A.7 | UNIQUE(root_path) + UNIQUE(folder_id, relative_path) + INSERT OR IGNORE |
| H: SmartFolderField camelCase vs DB snake_case | A.8 | raw value 改为真实 column name |
| H: A.18 race（select before engine attach）| A.17 step 5 + A.18 重写 | wireIfReady() 幂等 + .onAppear/.onChange 双触发 |
| H: fetchImages raw whereClause SQL injection 隐患 | A.5 | API 改 `fetch(_ compiled: CompiledSmartFolderQuery)` 强制走 builder |
| H: D3 dedup drift（design 说 M1 含 dedup，plan deferred Slice H）| 顶部 Slice Roadmap + Spec coverage | M1 = Slice A-I 累积；Slice A 无 dedup 是 known limitation 不是 drift |
| M: 设计 M1 = 2 内置 SF / Slice A ship 1 | 同上 | M1 累积 ≥2，Slice A 仅"全部最近"是 vertical slice 边界 |
| M: D6 嵌套未约束 | A.8 | 加 `validateD6UserRule()`（M4 用户规则编辑器调用，内置 SF 信任跳过）|

**Code reality check**（per 全局 CLAUDE.md "写 plan 引用已有代码前必须 Read 实际文件"硬规则）：所有引用 V1 已有符号已通过 Read / grep 验证 ✓

> **2026-05-07 重跑**：merge `main` → `v2/dev` 后（merge commit `86b2a24`）按本表 11 项重新核对。7 项无漂移，2 项行号漂移（语义一致），1 项 V1 加 state（A.17 保留清单已扩），1 项 GlanceApp About scene 已被 V1 重构（A.13 代码示例已更新）。下表行号 / 注释已对齐 merge 后真实状态。

| V1 引用 | 验证方式 | 结果 |
|---|---|---|
| `GlanceApp.init()` block 模式 | Read `Glance/GlanceApp.swift:18-22` | ✓ 真实 init() block（bm + folderStore），扩展 3 行接入 IndexStoreHolder |
| `FolderStore(bookmarkManager:)` 必须传 bm | Read `FolderStore.swift:88` | ✓ V1 现有，无默认 init |
| `FolderStore.rootFolders: [FolderNode]`（不是 `[URL]`） | Read `FolderStore.swift:48` | ✓ FolderNode 含 `url: URL`，bridge 用 `node.url` |
| `FolderStore.selectedFolder: URL?` | Read `FolderStore.swift:49` | ✓ 直接 `= nil` 清选，无 `clearSelection()` 方法 |
| `DS.Spacing.xs/sm/md/lg/xl`（不是 `.s/.m`） | Read `DesignSystem.swift:15-21` | ✓ 全 plan 统一为 `.sm/.md/.xs` |
| `DS.Sidebar.minWidth/width/maxWidth` | Read `DesignSystem.swift:36-38` | ✓ |
| `DS.Thumbnail.cornerRadius` | Read `DesignSystem.swift:30` | ✓ |
| `loadThumbnail(url:maxPixelSize:)` 顶层函数 | grep `ImageGridView.swift:276`（merge 前 :258，行号漂移） | ✓ internal 级别可全局调用，A.16 复用，签名未变 |
| ContentView 两栏 NavigationSplitView（不是三栏） | Read `ContentView.swift:38-79`（merge 前 :29-70，文件总长 204 行 vs 166 行） | ✓ A.17 改造保留两栏形态 + 全部 V1 状态；结构 NavigationSplitView + HStack + Inspector 不变 |
| ContentView V1 状态：`showInspector` `quickViewerIndex` `quickViewerEntry`（V1 加，commit 02a36dc）`previewFocusTrigger` `gridFocusTrigger` `previewVM` `inspectorURL` | Read `ContentView.swift:17-36` + struct 外 line 11-14 `QuickViewerEntry` enum | ✓ A.17 明确不动 7 项 state + 1 enum |
| ContentView V1 modifier：`.toolbarBackground(.hidden, for: .windowToolbar)`（V1 加，commit c0c833a 修 toolbar 横条断层） | Read `ContentView.swift:131` | ✓ A.17 明确不动 |
| ContentView V1 callback：`QuickViewerOverlay(onIndexChange:)`（V1 加，commit 02a36dc 修 Bug 4 扩展） | Read `ContentView.swift:93-99` | ✓ A.17 明确不动 |
| `@NSApplicationDelegateAdaptor(AppDelegate)` / `CommandGroup(replacing: .appInfo)` | Read `GlanceApp.swift:16, 35-42` | ✓ A.13 明确保留 |
| ⚠️ V1 已删 `Window("关于一眼", id: "about")` SwiftUI scene | Read `GlanceApp.swift`（不存在）+ `Glance/About/AboutWindowController.swift`（V1 commit 20fa509 加） | ✓ A.13 不再"保留 SwiftUI Window scene"——V1 已重构为 AppKit `AboutWindowController.shared.show()`，A.13 不动该重构 |
| ⚠️ V1 已删 `.preferredColorScheme(...)` modifier | Read `GlanceApp.swift`（不存在）+ `WindowAccessor.swift`（V1 commit 2b858cf 改 NSApp.appearance） | ✓ A.13 不再"保留 .preferredColorScheme"——V1 已迁移到 AppKit 层，A.13 不动该重构 |

**Identified gaps / future-resolution items**（其中部分由 codex review 发现）：

1. **SmartFolderStore enum-state 重构**：`engine: SmartFolderEngine?` + `attach` 是 Slice A 过渡形态，更干净的 `loading / ready(engine) / failed` enum state 留待 Slice I（已记入 Slice I deliverables）。codex 指出 attach 模式跟 EnvironmentObject 未注入是两个独立问题——后者已修，前者 V1.0 GA 前重构。
2. **Bridge 用 path string dedup（Slice A 简化）**：`registerRoot(path:bookmark:)` 用 `standardizedFileURL.path` 做 unique 键。Slice G 加 FSEvents 时应改为 stable folder.id 跟踪，并处理"用户从 V1 删 root"的清理（FolderStore.removeFolder 已删 bookmark，但 IndexStore.folders/images 行 Slice A 残留）。
3. **codex M findings 记入 known limitations，不在 Slice A 修**：
   - Task.detached 在 SmartFolderStore.refreshSelected / FolderStoreIndexBridge 的 capture 在 strict concurrency 下可能 warning（Sendable）。Slice A.14 / A.17 已加 local capture 缓解；Swift 6 strict mode 真触发后再硬修
   - clearSelection inline 三行（selectedFolder/images/selectedImageIndex）跳过 V1 selectFolder semantics，脆——Slice A 后续 refactor 加 V1 helper（不阻塞 ship）
4. **V1 supportedExtensions vs V2 ImageMetadataReader 范围差异**：V1 `FolderStore.supportedExtensions = jpg/jpeg/png/heic/heif/gif/webp/tiff`；V2 用 UTType 范围更广（含 RAW/BMP）。可能导致 V1 单 folder grid 看不见的 RAW 出现在 smart folder grid，且 V1 `loadThumbnail` 对 RAW 可能 fallback 空白。Slice A 接受此差异；M2 feature print 整合时统一扩展。
5. **codex L findings**：19 task commit-granular 是 preference call，**保留现状**（atomic [wip] commit trail 价值 > consolidation；codex 建议 A.8-A.12 合一被 push back，user-confirmed 接受）。

**Codex review 主要价值**：抓出了我 self-review 完全没察觉的 **spec→plan drift（D3 dedup / 内置 SF 数量 / D6 嵌套验证）+ schema FK 死锁 + EnvironmentObject 注入 + onChange Equatable 编译错 + 字段名 camelCase/snake_case 漂移**。这些在 self-review syntactic 检查里看不到，必须靠跨工具 reality check。

---

## Execution Handoff

Plan 完成，已保存到 `specs/v2/2026-05-06-m1-implementation-plan.md`。两条 execution 路径：

**1. Subagent-Driven（推荐）** — 每 task fresh subagent + 中间 review，快速 iterate；适合 task 独立性高且想要 plan 严格执行的场景。

**2. Inline Execution** — 在当前 session 用 `superpowers:executing-plans` skill batch 执行，checkpoint review；适合想看每步进展并即时调整的场景。

但鉴于本项目 5 步 `/go` workflow + pre-push codex hook 已经是密集 review 机制，且 Slice A 有些 task（A.13/A.14）依赖 V1 现有代码现状（FolderStore / GlanceApp / ContentView 当前形态），**第 3 选项**也可考虑：

**3. 用户主导 + AI 辅助** — 你按本 plan 一个 task 一个 task 走，遇到 unclear 的细节我具体辅助；每 slice 末走 `/go` 收尾。这是 Glance 项目当前实际 workflow，跟 V1 一致；plan 作为 scope 锚点而不是逐字脚本。

我倾向 **(3)**——本项目脚手架强、TDD 不适用、plan 中已有 V1 现状假设的不确定（A.13/A.14 需要看 V1 实际代码），subagent 先验地装作不熟悉项目反而摩擦多。但你定。
