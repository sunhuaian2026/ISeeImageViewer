# Glance V2 M2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Plan strategy**: M2 covers 2 slices. **Slice J**（V2.1-beta1，端到端 demo）full task/step/code detail；**Slice K**（V2.1 GA，polish + Vision revision）outline 形式（K start 前再写 detailed plan，吸收 J ship 后的实测教训）。
>
> **Spec reference**: `specs/v2/2026-05-10-m2-design.md`
> **Decision references**: `specs/v2/2026-05-06-v2-design.md` D1-D10 + 本 plan D11-D14
> **Term references**: `CONTEXT.md`「跨文件夹聚合」段（Feature Print / Ephemeral 视图 / Revision）

**Goal:** Ship V2.1（类似图查找）by delivering 2 vertical slices over ~3 weeks: J = 找类似端到端 demo（V2.1-beta1），K = revision 迁移 + polish（V2.1 GA）。

**Architecture:** 新增 `Glance/Similarity/` 模块层（SimilarityService + FeaturePrintIndexer + EphemeralResultView + ProgressView 共 5 文件）。复用 V2 M1 已有基础设施：IndexStore SQLite blob 列（v1 schema 已 forward-looking）、IndexStoreHolder progress/error pattern、Slice I 进度 chip 样式、FolderStoreIndexBridge handleCreated hook、Slice A.18 QV transition .identity insertion 模式。

**Tech Stack:** Swift 5.9+ / SwiftUI / Vision (`VNGenerateImageFeaturePrintRequest` + `VNFeaturePrintObservation`) / Foundation NSKeyedArchiver-NSSecureCoding 序列化 fp / sqlite3 C API（已建立 pattern）/ Task.detached + Task.isCancelled 后台 pipeline / async-await。**禁第三方依赖**。

---

## M2 Slice Roadmap

| Slice | Goal | Estimate | Ship as | Status |
|---|---|---|---|---|
| **J** ⭐ (this plan, detailed) | 后台 fp 索引 + Quick Viewer 找类似按钮 + EphemeralResultView 端到端 demo | 11-13 天 | V2.1-beta1 | ✅ 完成 2026-05-11 |
| K | Vision revision 迁移 + 失败重试 polish + 错误 banner + 性能验收 | 4-5 天 | V2.1 GA | ✅ K.1/K.2/K.3 完成 2026-05-11；K.4 性能验收 + K.5 tag deferred |

**Total:** ~15-18 工作日 ≈ **3 周**（落 V2 design D9 的 M2 = 3 周锁定范围）。

每 slice 完成跑 `/go`（5 步 verify + 文档同步 + PENDING + commit + push + 汇报）。

---

## M2 plan-time 决策（写入 `specs/Roadmap.md` V2 决策段当 D11-D14）

详见 `specs/v2/2026-05-10-m2-design.md` § 3。本 plan 落地这四条：

| ID | 决策 | 落地点 |
|---|---|---|
| D11 | 后台 fp 索引启动即跑（lazy backfill） | J.5 GlanceApp.onAppear → `FeaturePrintIndexer.start()` |
| D12 | M2 = 2 slice（J 端到端 + K polish） | 本 plan 整体结构 |
| D13 | 类似图 = 纯 top-30 不加阈值 | J.1 SimilarityService.queryTopN 写死 30 |
| D14 | 部分库时允许查 + banner 提示 | J.10 ContentView.handleFindSimilar 计算 banner string + 传入 EphemeralResultView |

---

## File Structure (Slice J)

| 操作 | 路径 | 责任 |
|---|---|---|
| Create | `Glance/Similarity/SimilarityService.swift` | Vision wrapper：单图抽 fp（archived Data + revision）+ batch top-N（cosine via `computeDistance`）|
| Create | `Glance/Similarity/FeaturePrintIndexingProgress.swift` | progress record struct（indexed/total/lastImageName） |
| Create | `Glance/Similarity/FeaturePrintIndexer.swift` | 后台 pipeline：start/cancel + queue enqueue + Task.detached loop + Task.isCancelled 检测 + 每 N 张 emit progress |
| Create | `Glance/Similarity/FeaturePrintProgressView.swift` | chip UI（mirror IndexingProgressView，紫色调区分） |
| Create | `Glance/Similarity/EphemeralResultView.swift` | layout 容器 + ThumbnailCell 复用 + banner 槽 + 关闭按钮 + 单击/双击/键盘导航 |
| Modify | `Glance/IndexStore/IndexedImage.swift`（末尾 extension） | 加 5 fp CRUD method |
| Modify | `Glance/IndexStore/IndexStoreHolder.swift` | 加 `featurePrintProgress` @Published + `cancelFeaturePrintIndexing` closure + 持有 indexer |
| Modify | `Glance/IndexStore/FolderStoreIndexBridge.swift` | `handleCreated` 末尾通知 indexer enqueue |
| Modify | `Glance/QuickViewer/QuickViewerOverlay.swift` | bottomToolbar 加「找类似」按钮 + onFindSimilar callback + currentSupportsFeaturePrint flag |
| Modify | `Glance/GlanceApp.swift` | `.onAppear` 启动 FeaturePrintIndexer（IndexStoreHolder ready 后）|
| Modify | `Glance/ContentView.swift` | `currentEphemeral: EphemeralRequest?` state + `handleFindSimilar` + EphemeralResultView 路由 + QV onFindSimilar wire |
| Modify | `Glance/DesignSystem.swift` | 加 `DS.Similarity` token 段（fp 进度 chip 颜色 + ephemeral banner 颜色）|

---

## Slice J: 端到端 demo（V2.1-beta1，11 task）

### Task J.1: SimilarityService（Vision wrapper + 单图抽 + batch top-N）

**Files:**
- Create: `Glance/Similarity/SimilarityService.swift`

- [ ] **Step 1: 创建 SimilarityService 文件**

```swift
//
//  SimilarityService.swift
//  Glance
//
//  Vision VNFeaturePrintObservation 包装。两个职责：
//  1. extract(url:) — 单图抽 feature print，返回 (archived Data, revision Int) 给 IndexStore 存
//  2. queryTopN(sourceArchive:candidates:n:) — 给定一张源图 + 候选 list → 算 distance 取 top-N
//
//  序列化：VNFeaturePrintObservation 没有从 raw bytes 重建 observation 的 init，
//  只能走 NSKeyedArchiver/Unarchiver（NSSecureCoding 路径）。所以 IndexStore 存的
//  feature_print blob = NSKeyedArchiver.archivedData(observation, secureCoding: true)。
//
//  距离指标：用 Apple 自带 VNFeaturePrintObservation.computeDistance(_:to:) Float（越小越相似）。
//  CONTEXT.md「俗称余弦距离」是行业速记说法，实际指标以 Apple API 返回值为准。
//

import Foundation
import Vision
import AppKit

nonisolated enum SimilarityService {

    enum SimilarityError: Error {
        case extractFailed(String)
        case unsupportedFormat
        case archiveFailed
        case unarchiveFailed
    }

    /// 单图抽 feature print。返回 (archivedData, revision)。读图失败 / Vision 不支持
    /// 该格式 → 抛 .unsupportedFormat（caller 标 supports_feature_print=false 跳过）。
    /// 调用方所在 task 应已 startAccessing root scoped resource（FeaturePrintIndexer 负责）。
    static func extract(url: URL) throws -> (archived: Data, revision: Int) {
        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(url: url, options: [:])

        do {
            try handler.perform([request])
        } catch {
            throw SimilarityError.unsupportedFormat
        }

        guard let observation = request.results?.first as? VNFeaturePrintObservation else {
            throw SimilarityError.unsupportedFormat
        }

        let archived: Data
        do {
            archived = try NSKeyedArchiver.archivedData(
                withRootObject: observation,
                requiringSecureCoding: true
            )
        } catch {
            throw SimilarityError.archiveFailed
        }

        let revision = request.revision
        return (archived, revision)
    }

    /// 反序列化 archived blob → VNFeaturePrintObservation（cosine 用）。失败抛 .unarchiveFailed。
    static func unarchive(_ data: Data) throws -> VNFeaturePrintObservation {
        guard let observation = try? NSKeyedUnarchiver.unarchivedObject(
            ofClass: VNFeaturePrintObservation.self, from: data
        ) else {
            throw SimilarityError.unarchiveFailed
        }
        return observation
    }

    /// Batch top-N 查询。给定源 observation + 候选 [(id, archivedData)] → 算 distance →
    /// 按距离升序取前 n 个 id（不含源 id 自身）。
    /// D13：n 写死 30；caller 传 30 即可。
    /// 性能：10k 候选 unarchive + computeDistance 估算 < 1s（Vision computeDistance 优化过）。
    static func queryTopN(
        source: VNFeaturePrintObservation,
        candidates: [(id: Int64, archivedData: Data)],
        excludingId: Int64,
        n: Int
    ) -> [(id: Int64, distance: Float)] {
        var scored: [(Int64, Float)] = []
        scored.reserveCapacity(candidates.count)

        for (id, data) in candidates {
            guard id != excludingId else { continue }
            guard let candidateObs = try? unarchive(data) else { continue }
            var distance: Float = 0
            do {
                try source.computeDistance(&distance, to: candidateObs)
                scored.append((id, distance))
            } catch {
                continue
            }
        }

        scored.sort { $0.1 < $1.1 }
        return Array(scored.prefix(n))
    }
}
```

- [ ] **Step 2: 编译验证**

Run: `make build`
Expected: 0 error 0 warning。SimilarityService 可被 import 但无 caller。

- [ ] **Step 3: Commit**

```bash
git add Glance/Similarity/SimilarityService.swift
git commit -m "feat: add SimilarityService — Vision feature print extract + top-N (J.1)"
```

---

### Task J.2: IndexStore feature print CRUD（5 method 加到 IndexedImage extension）

**Files:**
- Modify: `Glance/IndexStore/IndexedImage.swift`（在最后的 `private func checkBind` 之前插入 5 个 method）

- [ ] **Step 1: 读 IndexedImage.swift 末尾确认插入点**

Run: `grep -n "private func checkBind" Glance/IndexStore/IndexedImage.swift`
Expected: 单行匹配（约 line 457）。

- [ ] **Step 2: 在 `private func checkBind` 之前插入 5 个 fp CRUD method**

把以下代码插入到 `// MARK: - Slice H 内容去重` 段之后、`private func checkBind` 之前：

```swift
    // MARK: - M2 Slice J 找类似（feature print CRUD）

    /// J.3 — 拉一批 supports_feature_print=1 且 feature_print IS NULL 的 row 给 indexer 抽。
    /// 按 id ASC 取，配 limit 实现 batch backfill。返回 [(id, urlBookmark, relativePath, folderId)]。
    /// 不返回 IndexedImage 整 row（只用到这 4 列，省内存 + IO）。
    func fetchImagesNeedingFeaturePrint(limit: Int) throws -> [(id: Int64, urlBookmark: Data, relativePath: String, folderId: Int64)] {
        try sync { db in
            let stmt = try db.prepare("""
                SELECT id, url_bookmark, relative_path, folder_id FROM images
                WHERE supports_feature_print = 1 AND feature_print IS NULL
                ORDER BY id ASC LIMIT ?;
            """)
            defer { sqlite3_finalize(stmt) }
            try checkBind(sqlite3_bind_int(stmt, 1, Int32(limit)), index: 1, db: db)

            var results: [(Int64, Data, String, Int64)] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = sqlite3_column_int64(stmt, 0)
                let blobLen = sqlite3_column_bytes(stmt, 1)
                let blobPtr = sqlite3_column_blob(stmt, 1)
                let bookmark = blobPtr.map { Data(bytes: $0, count: Int(blobLen)) } ?? Data()
                let relPath = String(cString: sqlite3_column_text(stmt, 2))
                let folderId = sqlite3_column_int64(stmt, 3)
                results.append((id, bookmark, relPath, folderId))
            }
            return results
        }
    }

    /// J.3 — 写入 feature_print blob + revision；caller (indexer) 已 SimilarityService.extract 拿到。
    func setFeaturePrint(imageId: Int64, archivedData: Data, revision: Int) throws {
        try sync { db in
            let stmt = try db.prepare("""
                UPDATE images SET feature_print = ?, feature_print_revision = ?
                WHERE id = ?;
            """)
            defer { sqlite3_finalize(stmt) }
            let blobBytes = archivedData as NSData
            try checkBind(
                sqlite3_bind_blob(stmt, 1, blobBytes.bytes, Int32(blobBytes.length), unsafeBitCast(-1, to: sqlite3_destructor_type.self)),
                index: 1, db: db
            )
            try checkBind(sqlite3_bind_int(stmt, 2, Int32(revision)), index: 2, db: db)
            try checkBind(sqlite3_bind_int64(stmt, 3, imageId), index: 3, db: db)
            guard sqlite3_step(stmt) == SQLITE_DONE else {
                throw IndexDatabaseError.stepFailed(message: "setFeaturePrint: \(db.lastErrorMessage())")
            }
        }
    }

    /// J.3 — Vision 抽取失败（unsupported format / corrupted file）→ 标 supports=0，
    /// 让 fetchImagesNeedingFeaturePrint 永久跳过（避免无限 retry 同一坏图）。
    func setFeaturePrintUnsupported(imageId: Int64) throws {
        try sync { db in
            let stmt = try db.prepare("""
                UPDATE images SET supports_feature_print = 0,
                                  feature_print = NULL,
                                  feature_print_revision = NULL
                WHERE id = ?;
            """)
            defer { sqlite3_finalize(stmt) }
            try checkBind(sqlite3_bind_int64(stmt, 1, imageId), index: 1, db: db)
            guard sqlite3_step(stmt) == SQLITE_DONE else {
                throw IndexDatabaseError.stepFailed(message: "setFeaturePrintUnsupported: \(db.lastErrorMessage())")
            }
        }
    }

    /// J.10 — 找类似 query：取所有有 fp 的 (id, archivedData)，加载 SimilarityService 算 distance。
    /// 1 万图 × ~6KB archive = ~60MB 内存峰值，M1 mac 可接受。
    func fetchAllFeaturePrintsForCosine() throws -> [(id: Int64, archivedData: Data)] {
        try sync { db in
            let stmt = try db.prepare("""
                SELECT id, feature_print FROM images
                WHERE supports_feature_print = 1 AND feature_print IS NOT NULL
                ORDER BY id ASC;
            """)
            defer { sqlite3_finalize(stmt) }
            var results: [(Int64, Data)] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = sqlite3_column_int64(stmt, 0)
                let blobLen = sqlite3_column_bytes(stmt, 1)
                let blobPtr = sqlite3_column_blob(stmt, 1)
                let archived = blobPtr.map { Data(bytes: $0, count: Int(blobLen)) } ?? Data()
                guard !archived.isEmpty else { continue }
                results.append((id, archived))
            }
            return results
        }
    }

    /// J.10 — 找类似时：按 image full URL 查 (id, archivedData)。caller 反查源图自己的 fp。
    /// 失败（行不存在 / fp 未抽 / fp 损坏）→ 返 nil（caller 提示"该图未索引/不支持"）。
    func fetchFeaturePrintByFullPath(_ fullPath: String) throws -> (id: Int64, archivedData: Data)? {
        try sync { db in
            let stmt = try db.prepare("""
                SELECT i.id, i.feature_print FROM images i
                JOIN folders f ON i.folder_id = f.id
                WHERE f.root_path || '/' || i.relative_path = ? LIMIT 1;
            """)
            defer { sqlite3_finalize(stmt) }
            try checkBind(sqlite3_bind_text(stmt, 1, (fullPath as NSString).utf8String, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self)), index: 1, db: db)
            guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
            let id = sqlite3_column_int64(stmt, 0)
            guard sqlite3_column_type(stmt, 1) != SQLITE_NULL else { return nil }
            let blobLen = sqlite3_column_bytes(stmt, 1)
            let blobPtr = sqlite3_column_blob(stmt, 1)
            let archived = blobPtr.map { Data(bytes: $0, count: Int(blobLen)) } ?? Data()
            guard !archived.isEmpty else { return nil }
            return (id, archived)
        }
    }

    /// J.10 — 已知 image id list → URL list（resolve root bookmark + 拼 relative_path）。
    /// computeV2Urls 同款 pattern；失败行 silently skip（compactMap）。
    func fetchUrlsByIds(_ ids: [Int64]) throws -> [URL] {
        guard !ids.isEmpty else { return [] }
        return try sync { db in
            let placeholders = ids.map { _ in "?" }.joined(separator: ",")
            let sql = "SELECT id, url_bookmark, relative_path FROM images WHERE id IN (\(placeholders));"
            let stmt = try db.prepare(sql)
            defer { sqlite3_finalize(stmt) }
            for (idx, id) in ids.enumerated() {
                try checkBind(sqlite3_bind_int64(stmt, Int32(idx + 1), id), index: idx + 1, db: db)
            }

            // 先拉 row 进字典，再按入参 ids 顺序输出（preserve top-N 排序）
            var byId: [Int64: URL] = [:]
            while sqlite3_step(stmt) == SQLITE_ROW {
                let rowId = sqlite3_column_int64(stmt, 0)
                let blobLen = sqlite3_column_bytes(stmt, 1)
                let blobPtr = sqlite3_column_blob(stmt, 1)
                let bookmark = blobPtr.map { Data(bytes: $0, count: Int(blobLen)) } ?? Data()
                let relPath = String(cString: sqlite3_column_text(stmt, 2))
                var stale = false
                if let rootURL = try? URL(
                    resolvingBookmarkData: bookmark,
                    options: [.withSecurityScope],
                    bookmarkDataIsStale: &stale
                ) {
                    byId[rowId] = rootURL.appendingPathComponent(relPath)
                }
            }
            return ids.compactMap { byId[$0] }
        }
    }

```

- [ ] **Step 3: 编译验证**

Run: `make build`
Expected: 0 error 0 warning。

- [ ] **Step 4: Commit**

```bash
git add Glance/IndexStore/IndexedImage.swift
git commit -m "feat: IndexStore feature print CRUD (J.2)"
```

---

### Task J.3: FeaturePrintIndexer（后台 pipeline + cancel + queue）

**Files:**
- Create: `Glance/Similarity/FeaturePrintIndexingProgress.swift`
- Create: `Glance/Similarity/FeaturePrintIndexer.swift`

- [ ] **Step 1: 创建 progress record**

Create `Glance/Similarity/FeaturePrintIndexingProgress.swift`:

```swift
//
//  FeaturePrintIndexingProgress.swift
//  Glance
//
//  M2 Slice J — feature print indexer 进度 record。Equatable 让 .onChange 能观察。
//

import Foundation

struct FeaturePrintIndexingProgress: Equatable {
    /// 已抽取并写入 IndexStore 的图数量
    let indexed: Int
    /// 当前批次的总待抽数（initial fetch 时定值，每批 progress 都用同一 total）
    let total: Int
    /// 最近一张抽取成功的图文件名（UI 简洁展示用）
    let lastImageName: String
}
```

- [ ] **Step 2: 创建 indexer 主体**

Create `Glance/Similarity/FeaturePrintIndexer.swift`:

```swift
//
//  FeaturePrintIndexer.swift
//  Glance
//
//  M2 Slice J — 后台 feature print 索引 pipeline。启动后从 IndexStore 拉所有
//  supports_feature_print=1 且 feature_print IS NULL 的 row 逐批抽（每批 50），
//  抽成功 → setFeaturePrint；Vision 不支持 → setFeaturePrintUnsupported（永久跳过）。
//
//  生命周期：
//  - GlanceApp .onAppear（IndexStoreHolder ready 后）→ start()
//  - 用户点 progress chip X → cancel()
//  - 全库抽完 → 自然结束（fetchImagesNeedingFeaturePrint 返空 list）
//  - FSEvents 派发新图 → enqueueIfNeeded（重启 task 拉新一批；不维护 in-memory queue 简化）
//
//  cancel 模式 mirror FolderScanner：Task.detached + Task.isCancelled 检测。
//  NOT cancel 但批次完成（list 空）→ Task 自然 return；下次 enqueueIfNeeded 重启。
//

import Foundation

@MainActor
final class FeaturePrintIndexer {

    private let store: IndexStore
    /// 每批 fetch 的图数量。50 是 SQLite IO + Vision 单线程吞吐折中。
    private let batchSize = 50
    /// 当前正在跑的索引 task；nil = 空闲。start/enqueueIfNeeded 重新创建。
    private var currentTask: Task<Void, Never>?

    /// J.4 — 进度更新回调（IndexStoreHolder.featurePrintProgress = nil 表示空闲/完成）。
    var onProgress: ((FeaturePrintIndexingProgress?) -> Void)?

    /// J.4 — 错误（catch 后调；caller 设 holder.lastError 触发 banner）。
    /// J 阶段宽容处理：Vision 单图失败 → setFeaturePrintUnsupported 不抛；
    /// 仅 IndexStore IO 异常调此 callback。
    var onError: ((String) -> Void)?

    init(store: IndexStore) {
        self.store = store
    }

    /// 启动索引；若已有 task 在跑则忽略（幂等）。
    func start() {
        guard currentTask == nil else { return }
        let store = self.store
        let progressCB = self.onProgress
        let errorCB = self.onError
        let batchSize = self.batchSize

        currentTask = Task.detached(priority: .utility) { [weak self] in
            await Self.runLoop(
                store: store,
                batchSize: batchSize,
                progressCB: progressCB,
                errorCB: errorCB
            )
            await MainActor.run { [weak self] in
                self?.currentTask = nil
                self?.onProgress?(nil)  // clear chip
            }
        }
    }

    /// 用户点 progress chip X → 取消当前批次。
    func cancel() {
        currentTask?.cancel()
    }

    /// FSEvents handleCreated 后调；如果索引器空闲了 → start 一批新的。
    /// 如果还在跑 → 自然下批 fetch 会拉到新行（不主动打断）。
    func enqueueIfNeeded() {
        guard currentTask == nil else { return }
        start()
    }

    /// detached 内运行的主循环。Sendable-safe：参数都是 value 或 nonisolated 引用。
    private static func runLoop(
        store: IndexStore,
        batchSize: Int,
        progressCB: ((FeaturePrintIndexingProgress?) -> Void)?,
        errorCB: ((String) -> Void)?
    ) async {
        var totalIndexed = 0
        // total 在批次开始时计算（pending 估算总量）
        var pendingTotal = 0
        do {
            let all = try store.fetchImagesNeedingFeaturePrint(limit: Int.max)
            pendingTotal = all.count
        } catch {
            await MainActor.run { errorCB?("初始化 feature print 索引失败：\(error.localizedDescription)") }
            return
        }
        guard pendingTotal > 0 else { return }

        while !Task.isCancelled {
            let batch: [(id: Int64, urlBookmark: Data, relativePath: String, folderId: Int64)]
            do {
                batch = try store.fetchImagesNeedingFeaturePrint(limit: batchSize)
            } catch {
                await MainActor.run { errorCB?("feature print 索引拉取失败：\(error.localizedDescription)") }
                return
            }
            if batch.isEmpty { break }

            for row in batch {
                if Task.isCancelled { return }

                // resolve root bookmark → 拼 child URL（mirror computeV2Urls pattern）
                var stale = false
                guard let rootURL = try? URL(
                    resolvingBookmarkData: row.urlBookmark,
                    options: [.withSecurityScope],
                    bookmarkDataIsStale: &stale
                ) else {
                    // bookmark 失效 → 标 unsupported 跳过（不阻塞 pipeline）
                    try? store.setFeaturePrintUnsupported(imageId: row.id)
                    continue
                }
                let started = rootURL.startAccessingSecurityScopedResource()
                defer { if started { rootURL.stopAccessingSecurityScopedResource() } }

                let fileURL = rootURL.appendingPathComponent(row.relativePath)

                do {
                    let (archived, revision) = try SimilarityService.extract(url: fileURL)
                    try store.setFeaturePrint(imageId: row.id, archivedData: archived, revision: revision)
                    totalIndexed += 1
                    let lastName = (row.relativePath as NSString).lastPathComponent
                    let snapshot = FeaturePrintIndexingProgress(
                        indexed: totalIndexed,
                        total: pendingTotal,
                        lastImageName: lastName
                    )
                    await MainActor.run { progressCB?(snapshot) }
                } catch SimilarityService.SimilarityError.unsupportedFormat,
                        SimilarityService.SimilarityError.archiveFailed {
                    // Vision 不支持 / 序列化失败 → 永久标 supports=0 跳过
                    try? store.setFeaturePrintUnsupported(imageId: row.id)
                } catch {
                    // IndexStore IO 异常 → 报 banner 并退出（避免在错误 DB 上 spin）
                    await MainActor.run {
                        errorCB?("feature print 索引写入失败：\(error.localizedDescription)")
                    }
                    return
                }
            }
        }
    }
}
```

- [ ] **Step 3: 编译验证**

Run: `make build`
Expected: 0 error 0 warning。FeaturePrintIndexer 可被 init 但还没 caller。

- [ ] **Step 4: Commit**

```bash
git add Glance/Similarity/FeaturePrintIndexingProgress.swift Glance/Similarity/FeaturePrintIndexer.swift
git commit -m "feat: FeaturePrintIndexer background pipeline (J.3)"
```

---

### Task J.4: IndexStoreHolder 扩 fp progress + cancel hook

**Files:**
- Modify: `Glance/IndexStore/IndexStoreHolder.swift`

- [ ] **Step 1: 加 fp progress 字段 + cancel closure**

在现有 `var cancelCurrentScan: (() -> Void)?` 之后插入：

```swift
    /// M2 Slice J — feature print 索引进度（nil = 空闲/完成）。
    /// FeaturePrintIndexer.onProgress 回调更新。
    @Published var featurePrintProgress: FeaturePrintIndexingProgress?

    /// M2 Slice J — 用户点 fp 进度 chip 上的 X 触发取消。FeaturePrintIndexer.cancel() 转发。
    var cancelFeaturePrintIndexing: (() -> Void)?

    /// M2 Slice J — 持有 indexer 引用。GlanceApp/ContentView wire 后由 wireIfReady 设值。
    var featurePrintIndexer: FeaturePrintIndexer?
```

- [ ] **Step 2: 编译验证**

Run: `make build`
Expected: 0 error 0 warning。

- [ ] **Step 3: Commit**

```bash
git add Glance/IndexStore/IndexStoreHolder.swift
git commit -m "feat: IndexStoreHolder featurePrint progress + cancel hook (J.4)"
```

---

### Task J.5: GlanceApp 启动 indexer + ContentView wireIfReady 挂回调

**Files:**
- Modify: `Glance/ContentView.swift`（`wireIfReady()` 末尾追加 indexer wire 段）

> 不动 GlanceApp.swift——indexer 启动放 ContentView.wireIfReady 内（已有 IndexStoreHolder ready 守卫 + bridge 创建逻辑），保持 wire 单一入口。GlanceApp.onAppear 已 wire 了 folderStore.loadSavedFolders，indexer 在 wireIfReady 末尾启动符合"IndexStore + bridge 都 ready 后再开抽"语义。

- [ ] **Step 1: 在 wireIfReady 末尾追加 indexer 创建 + 回调挂载 + start**

读 `Glance/ContentView.swift` line 366-400 附近的 `wireIfReady` 函数。在 `await smartFolderStore.refreshSelected()` else 分支之后、函数 return 之前插入：

```swift
        // M2 Slice J — feature print indexer 启动 + 回调挂载
        let indexer = FeaturePrintIndexer(store: store)
        let holderRef2 = indexStoreHolder  // shadow capture（指针不变 capture 安全）
        indexer.onProgress = { progress in
            holderRef2.featurePrintProgress = progress
        }
        indexer.onError = { msg in
            holderRef2.lastError = msg
        }
        holderRef2.featurePrintIndexer = indexer
        holderRef2.cancelFeaturePrintIndexing = { [weak indexer] in
            indexer?.cancel()
        }
        indexer.start()
```

完整修改后的 wireIfReady 函数末尾应像这样（仅展示新增部分上下文）：

```swift
        if smartFolderStore.selected == nil {
            await smartFolderStore.select(BuiltInSmartFolders.allRecent)
        } else {
            await smartFolderStore.refreshSelected()
        }

        // M2 Slice J — feature print indexer 启动 + 回调挂载
        let indexer = FeaturePrintIndexer(store: store)
        let holderRef2 = indexStoreHolder
        indexer.onProgress = { progress in
            holderRef2.featurePrintProgress = progress
        }
        indexer.onError = { msg in
            holderRef2.lastError = msg
        }
        holderRef2.featurePrintIndexer = indexer
        holderRef2.cancelFeaturePrintIndexing = { [weak indexer] in
            indexer?.cancel()
        }
        indexer.start()
    }
```

- [ ] **Step 2: 编译验证**

Run: `make build`
Expected: 0 error 0 warning。indexer 在 IndexStore ready 后启动，但还无进度 UI。

- [ ] **Step 3: 手动 smoke test**

Run: `make run`，确认：
- 启动后 console 看到（如果 root folder 已 indexed）「[FolderScanner] scan complete」之后 indexer 默默工作（暂无 chip）
- 启动 console 不报 crash

- [ ] **Step 4: Commit**

```bash
git add Glance/ContentView.swift
git commit -m "feat: wire FeaturePrintIndexer in ContentView.wireIfReady (J.5)"
```

---

### Task J.6: FolderStoreIndexBridge 加 fp indexer enqueue hook

**Files:**
- Modify: `Glance/IndexStore/FolderStoreIndexBridge.swift`（`handleCreated` 末尾 + class 加 `featurePrintIndexer` 引用）

- [ ] **Step 1: 加 indexer 引用 + setter**

在 `private var watchers: [Int64: FSEventsWatcher] = [:]` 之后插入：

```swift
    /// M2 Slice J — FSEvents 派发新图后触发 fp indexer 重启拉一批新行。ContentView wireIfReady
    /// 调 setFeaturePrintIndexer 注入。weak 引用避免 retain cycle（indexer 由 IndexStoreHolder 强持）。
    private weak var featurePrintIndexer: FeaturePrintIndexer?

    func setFeaturePrintIndexer(_ indexer: FeaturePrintIndexer) {
        self.featurePrintIndexer = indexer
    }
```

- [ ] **Step 2: 在 handleCreated 末尾（成功 insert 后）调 enqueueIfNeeded**

定位 `handleCreated` 函数内 `triggerDedupGroup(fileSize: metadata.fileSize, format: metadata.format)` 这行之后、`return true` 之前。修改成：

```swift
        do {
            _ = try indexStore.insertImageIfAbsent(record)
            // Slice H — 新图入索引 → 重新决议该 (file_size, format) group 的 canonical
            triggerDedupGroup(fileSize: metadata.fileSize, format: metadata.format)
            // M2 Slice J — 通知 fp indexer 重启拉新一批（含本图）
            featurePrintIndexer?.enqueueIfNeeded()
            return true
        } catch {
            print("[FSEvents] insertImageIfAbsent FAILED \(path): \(error)")
            return false
        }
```

- [ ] **Step 3: ContentView wireIfReady 内调 bridge.setFeaturePrintIndexer(indexer)**

在 J.5 已添加的 indexer 段落之后追加一行：

```swift
        bridge.setFeaturePrintIndexer(indexer)
```

完整 wire 应像：

```swift
        let indexer = FeaturePrintIndexer(store: store)
        let holderRef2 = indexStoreHolder
        indexer.onProgress = { progress in holderRef2.featurePrintProgress = progress }
        indexer.onError = { msg in holderRef2.lastError = msg }
        holderRef2.featurePrintIndexer = indexer
        holderRef2.cancelFeaturePrintIndexing = { [weak indexer] in indexer?.cancel() }
        bridge.setFeaturePrintIndexer(indexer)
        indexer.start()
```

- [ ] **Step 4: 编译验证**

Run: `make build`
Expected: 0 error 0 warning。

- [ ] **Step 5: Commit**

```bash
git add Glance/IndexStore/FolderStoreIndexBridge.swift Glance/ContentView.swift
git commit -m "feat: FSEvents handleCreated triggers fp indexer enqueue (J.6)"
```

---

### Task J.7: FeaturePrintProgressView（chip mirror Slice I + 挂 ContentView mainContent）

**Files:**
- Create: `Glance/Similarity/FeaturePrintProgressView.swift`
- Modify: `Glance/DesignSystem.swift`（加 `DS.Similarity` 段）
- Modify: `Glance/ContentView.swift`（mainContent ZStack 顶层 VStack 加新 chip）

- [ ] **Step 1: 加 DS.Similarity tokens**

在 `Glance/DesignSystem.swift` 找到 `enum IndexingProgress` 段（约 line 106）之后插入：

```swift
    // MARK: - Similarity（V2 M2 Slice J — feature print 索引进度 chip）

    enum Similarity {
        /// fp 进度 chip 用紫色调（视觉与扫描进度区分；DS.Color.glowPrimary 系）
        static let chipAccent: SwiftUI.Color = .accentColor
        static let spinnerScale: CGFloat = 0.7
    }
```

- [ ] **Step 2: 创建 FeaturePrintProgressView**

Create `Glance/Similarity/FeaturePrintProgressView.swift`:

```swift
//
//  FeaturePrintProgressView.swift
//  Glance
//
//  M2 Slice J — feature print 索引进度 chip。形态 mirror Slice I IndexingProgressView：
//  Capsule + .thickMaterial + .strokeBorder hairline + 取消 X 按钮。视觉差异化：图标用
//  rectangle.stack.badge.minus 区分扫描 chip（progressspinner）。
//
//  挂在 ContentView mainContent ZStack 顶层 VStack 第二行（Slice I chip 之下），共享相同
//  动效 + 隐藏规则（progress = nil → fade out）。
//

import SwiftUI

struct FeaturePrintProgressView: View {
    let progress: FeaturePrintIndexingProgress
    var onCancel: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.caption.weight(.semibold))
                .foregroundStyle(DS.Similarity.chipAccent)
            Text("正在索引相似度 · \(progress.indexed) / \(progress.total)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
            if let onCancel {
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(DS.Color.secondaryText)
                }
                .buttonStyle(.borderless)
                .help("取消相似度索引")
            }
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xs)
        .background(.thickMaterial, in: Capsule())
        .overlay(
            Capsule().strokeBorder(
                .primary.opacity(DS.SectionHeader.chipBorderOpacity),
                lineWidth: DS.SectionHeader.chipBorderWidth
            )
        )
    }
}
```

- [ ] **Step 3: ContentView mainContent ZStack 顶层 VStack 加 fp chip**

定位 `Glance/ContentView.swift` 内 `mainContent` 函数（约 line 236）。在现有 `if let progress = indexStoreHolder.progress { IndexingProgressView(...) }` 块之后、`if let err = indexStoreHolder.lastError { ... }` 之前插入：

```swift
                // M2 Slice J — feature print 索引进度 chip（紫色调区分扫描 chip）
                if let fpProgress = indexStoreHolder.featurePrintProgress {
                    FeaturePrintProgressView(progress: fpProgress, onCancel: {
                        indexStoreHolder.cancelFeaturePrintIndexing?()
                    })
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
```

并在 mainContent 末尾的 `.animation(...)` 之后追加一条 fp 进度 animation：

```swift
        .animation(DS.Anim.fast, value: indexStoreHolder.featurePrintProgress)
```

- [ ] **Step 4: 编译验证**

Run: `make build`
Expected: 0 error 0 warning。

- [ ] **Step 5: 手动 smoke test**

Run: `make run`，确认：
- 启动后（如果 root folder 已索引）chip 出现两条：扫描 chip（已扫完会很快消失）+ fp chip 显示 `0 / N`，N 持续增长直到 0=N 后 chip 消失
- 点 X 按钮 → fp chip 立刻消失（cancel 生效）

- [ ] **Step 6: Commit**

```bash
git add Glance/Similarity/FeaturePrintProgressView.swift Glance/DesignSystem.swift Glance/ContentView.swift
git commit -m "feat: feature print progress chip + DS.Similarity tokens (J.7)"
```

---

### Task J.8: EphemeralResultView（layout + ThumbnailCell 复用 + banner）

**Files:**
- Create: `Glance/Similarity/EphemeralResultView.swift`

- [ ] **Step 1: 创建 EphemeralResultView**

Create `Glance/Similarity/EphemeralResultView.swift`:

```swift
//
//  EphemeralResultView.swift
//  Glance
//
//  M2 Slice J — 临时结果视图（找类似 / M3 搜索共用骨架）。layout = topBar（关闭+title+banner）
//  + LazyVGrid（复用 ImageGridView ThumbnailCell pattern）。不持久化（关闭即销毁状态）。
//
//  与 SmartFolderGridView 区别：
//  - 不依赖 SmartFolder（M3 搜索结果不是 SF）
//  - 不做时间分段（top-N 是排序结果，不是时间序列）
//  - 单击/双击行为复用 V1 mode（onSingleClick → preview / onDoubleClick → QV，调用方接）
//
//  D14 banner：caller 计算"已索引 X / Y 张"提示，nil 时不渲染 banner row。
//

import SwiftUI

struct EphemeralResultView: View {
    let title: String
    let urls: [URL]
    let bannerText: String?
    let onClose: () -> Void
    let onSingleClick: (Int) -> Void
    let onDoubleClick: (Int) -> Void

    @EnvironmentObject var folderStore: FolderStore

    @FocusState private var isFocused: Bool
    @State private var highlightedURL: URL?

    private var gridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: folderStore.thumbnailSize), spacing: DS.Thumbnail.spacing)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            topBar
            if let bannerText {
                bannerRow(text: bannerText)
            }
            ScrollView {
                if urls.isEmpty {
                    emptyState
                } else {
                    LazyVGrid(columns: gridColumns, spacing: DS.Thumbnail.spacing) {
                        ForEach(Array(urls.enumerated()), id: \.element) { idx, url in
                            VStack(spacing: DS.Spacing.xs) {
                                ThumbnailCell(
                                    url: url,
                                    isHighlighted: highlightedURL == url,
                                    size: folderStore.thumbnailSize
                                )
                                Text(url.lastPathComponent)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .frame(maxWidth: folderStore.thumbnailSize)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) {
                                highlightedURL = url
                                onDoubleClick(idx)
                            }
                            .onTapGesture(count: 1) {
                                highlightedURL = url
                                onSingleClick(idx)
                            }
                        }
                    }
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                }
            }
        }
        .background(DS.Color.appBackground)
        .focusable()
        .focusEffectDisabled()
        .focused($isFocused)
        .onAppear { isFocused = true }
        .onKeyPress(.escape) {
            onClose()
            return .handled
        }
    }

    private var topBar: some View {
        HStack(spacing: DS.Spacing.sm) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 28, height: 28)
                    .background(Color.gray.opacity(0.15), in: Circle())
            }
            .buttonStyle(.plain)
            .help("返回 (ESC)")

            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Text("\(urls.count) 张")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .background(.thinMaterial)
    }

    private func bannerRow(text: String) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.secondary)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Spacer()
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.xs)
        .background(Color.gray.opacity(0.08))
    }

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: "square.stack.3d.up.slash")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("无结果")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 80)
    }
}
```

- [ ] **Step 2: 编译验证**

Run: `make build`
Expected: 0 error 0 warning。`ThumbnailCell` 是 ImageGridView.swift 顶层 struct，import 同 module 即可用。

- [ ] **Step 3: Commit**

```bash
git add Glance/Similarity/EphemeralResultView.swift
git commit -m "feat: EphemeralResultView layout + ThumbnailCell reuse (J.8)"
```

---

### Task J.9: QuickViewerOverlay 加「找类似」按钮

**Files:**
- Modify: `Glance/QuickViewer/QuickViewerOverlay.swift`（init 加新参数 + bottomToolbar 加按钮）

- [ ] **Step 1: 加 QV 接收 onFindSimilar callback + currentSupports flag**

修改 QuickViewerOverlay struct 顶部 stored property + init：

```swift
struct QuickViewerOverlay: View {
    @StateObject private var viewModel: QuickViewerViewModel
    @EnvironmentObject var appState: AppState
    let onDismiss: () -> Void
    let onIndexChange: (Int) -> Void
    /// M2 Slice J — 用户点「找类似」按钮触发；caller (ContentView) 接到当前图 URL 后
    /// 反查 image id + 调 SimilarityService.queryTopN + 切到 EphemeralResultView。
    /// nil → 不渲染按钮（caller 未提供能力时静默隐藏）。
    let onFindSimilar: ((URL) -> Void)?
    /// M2 Slice J — 当前图是否支持找类似（IndexStore.supports_feature_print 反查）。
    /// false → 按钮 disable + tooltip 提示。caller 在 ContentView 算好传入。
    let currentSupportsFeaturePrint: Bool

    @FocusState private var isFocused: Bool
    @State private var controlsVisible = true
    @State private var hideTask: Task<Void, Never>?

    init(
        images: [URL],
        startIndex: Int,
        onDismiss: @escaping () -> Void,
        onIndexChange: @escaping (Int) -> Void,
        onFindSimilar: ((URL) -> Void)? = nil,
        currentSupportsFeaturePrint: Bool = true
    ) {
        _viewModel = StateObject(wrappedValue: QuickViewerViewModel(images: images, startIndex: startIndex))
        self.onDismiss = onDismiss
        self.onIndexChange = onIndexChange
        self.onFindSimilar = onFindSimilar
        self.currentSupportsFeaturePrint = currentSupportsFeaturePrint
    }
```

- [ ] **Step 2: bottomToolbar 加按钮**

在 `bottomToolbar` 函数内的 `toolbarButton(title: "全屏 (F)" ...)` 之前插入「找类似」按钮：

```swift
            if let onFindSimilar {
                toolbarButton(
                    title: currentSupportsFeaturePrint ? "找类似" : "该格式暂不支持类似图查找",
                    systemImage: "rectangle.stack.badge.plus"
                ) {
                    if currentSupportsFeaturePrint,
                       let url = viewModel.images[safe: viewModel.currentIndex] {
                        onFindSimilar(url)
                    }
                }
                .opacity(currentSupportsFeaturePrint ? 1.0 : 0.4)
                .allowsHitTesting(currentSupportsFeaturePrint)
            }
```

注意：因 `toolbarButton` 是已有 builder method，opacity / allowsHitTesting 修饰直接挂在调用上即可。

- [ ] **Step 3: 编译验证**

Run: `make build`
Expected: 0 error 0 warning。caller (ContentView) 之前调用 QuickViewerOverlay 用了 default init（没传 onFindSimilar / currentSupportsFeaturePrint），靠默认参数兼容现有 caller。

- [ ] **Step 4: Commit**

```bash
git add Glance/QuickViewer/QuickViewerOverlay.swift
git commit -m "feat: QV toolbar add 找类似 button (J.9)"
```

---

### Task J.10: ContentView ephemeral state + similarity query 触发 + ESC 路由

**Files:**
- Modify: `Glance/ContentView.swift`（加 `currentEphemeral` state + `handleFindSimilar` + EphemeralResultView 路由 + QV onFindSimilar wire）

- [ ] **Step 1: 在 ContentView struct 顶部加 ephemeral state + enum**

定位 ContentView struct 顶部（`@State private var v2Urls: [URL] = []` 之后）插入：

```swift
    /// M2 Slice J — 类似图查找结果视图状态。non-nil 时主区域换 EphemeralResultView 替代 baseGrid。
    @State private var currentEphemeral: EphemeralRequest?
```

在文件顶部 `private enum QuickViewerEntry` 之后插入：

```swift
/// M2 Slice J — 临时结果视图请求。M2 仅支持 .similar；M3 加 .search。
/// banner 由 caller 计算（D14 部分库提示），nil = 不显示 banner。
private enum EphemeralRequest: Equatable {
    case similar(sourceUrl: URL, results: [URL], banner: String?)

    var title: String {
        switch self {
        case .similar(let url, _, _):
            return "类似于 \(url.lastPathComponent)"
        }
    }

    var urls: [URL] {
        switch self {
        case .similar(_, let r, _): return r
        }
    }

    var banner: String? {
        switch self {
        case .similar(_, _, let b): return b
        }
    }
}
```

- [ ] **Step 2: 加 handleFindSimilar 函数**

在 `private func wireIfReady() async { ... }` 之后、`private func resolveFolderCoord` 之前插入：

```swift
    /// M2 Slice J — 触发"找类似"：源 URL → IndexStore 反查 fp → SimilarityService 算 top-30
    /// → fetch URLs → 切 EphemeralResultView。
    /// D14：feature print 全库未抽完 → banner 提示已索引 X / Y。
    private func handleFindSimilar(sourceUrl: URL) {
        guard let store = indexStoreHolder.store else { return }
        Task { [weak indexStoreHolder] in
            // 1. 反查源图 fp
            guard let (sourceId, sourceArchive) = try? store.fetchFeaturePrintByFullPath(sourceUrl.path) else {
                await MainActor.run {
                    indexStoreHolder?.lastError = "「\(sourceUrl.lastPathComponent)」尚未索引或不支持类似图查找"
                }
                return
            }
            // 2. 反序列化源 observation
            guard let sourceObs = try? SimilarityService.unarchive(sourceArchive) else {
                await MainActor.run {
                    indexStoreHolder?.lastError = "源图特征向量损坏，请稍后重试"
                }
                return
            }
            // 3. 拉所有候选 fp（D14: 部分库 ok）
            guard let candidates = try? store.fetchAllFeaturePrintsForCosine() else {
                await MainActor.run {
                    indexStoreHolder?.lastError = "类似图查找数据库读取失败"
                }
                return
            }
            // 4. cosine top-30 (D13)
            let topN = SimilarityService.queryTopN(
                source: sourceObs,
                candidates: candidates,
                excludingId: sourceId,
                n: 30
            )
            let topIds = topN.map { $0.id }
            // 5. ids → URLs
            let urls = (try? store.fetchUrlsByIds(topIds)) ?? []

            // 6. D14 banner：检查 fp 索引覆盖率
            let banner = await Self.computeBanner(
                store: store,
                indexedCount: candidates.count
            )

            await MainActor.run {
                self.currentEphemeral = .similar(sourceUrl: sourceUrl, results: urls, banner: banner)
                // 关闭 QV（让 ephemeral 视图占主区）
                self.quickViewerIndex = nil
            }
        }
    }

    /// 算 D14 部分库 banner 字符串。100% 覆盖 → nil；否则返回提示。
    private static func computeBanner(store: IndexStore, indexedCount: Int) async -> String? {
        // 算总图数（不含 supports=0）。简化：拉一次 SQL 总数对比
        let total = (try? store.sync { db in
            let stmt = try db.prepare("SELECT COUNT(*) FROM images WHERE supports_feature_print = 1;")
            defer { sqlite3_finalize(stmt) }
            guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
            return Int(sqlite3_column_int(stmt, 0))
        }) ?? 0
        guard total > 0 else { return nil }
        if indexedCount >= total { return nil }
        return "已索引 \(indexedCount) / \(total) 张，结果为部分库"
    }
```

注意：`Self.computeBanner` 用了 `import SQLite3`——确认 ContentView.swift 顶部已 import 之；若无则加 `import SQLite3`。

- [ ] **Step 3: 检查 import 语句**

Run: `head -10 Glance/ContentView.swift`
若没 `import SQLite3`，在 `import SwiftUI` 之后加：

```swift
import SQLite3
```

- [ ] **Step 4: 在 mainContent ZStack 加 currentEphemeral 替换 baseGrid 路由**

定位 `private var mainContent: some View` 函数。修改 ZStack 第一行 `baseGrid` 为条件路由：

```swift
    @ViewBuilder
    private var mainContent: some View {
        ZStack(alignment: .top) {
            if let req = currentEphemeral {
                EphemeralResultView(
                    title: req.title,
                    urls: req.urls,
                    bannerText: req.banner,
                    onClose: {
                        withAnimation(DS.Anim.normal) { currentEphemeral = nil }
                    },
                    onSingleClick: { idx in
                        // 类似图结果单击 → 进 preview（v2Urls 路径，复用 V2 mode）
                        v2Urls = req.urls
                        folderStore.selectedImageIndex = idx
                    },
                    onDoubleClick: { idx in
                        v2Urls = req.urls
                        folderStore.selectedImageIndex = nil
                        quickViewerEntry = .grid
                        quickViewerIndex = idx
                    }
                )
            } else {
                baseGrid
                previewOverlay
            }
            VStack(spacing: DS.Spacing.xs) {
                // ... 既有 progress / fp progress / error banner chip 不变 ...
```

完整修改：原 mainContent 主体的 `baseGrid` + `previewOverlay` 两行包进 `else` 分支；其余 chip 和 banner 段不变。

- [ ] **Step 5: QV onFindSimilar + currentSupports wire**

定位 `.overlay { if let idx = quickViewerIndex { QuickViewerOverlay(...) } }`（约 line 126）。给 init 加两参数：

```swift
                QuickViewerOverlay(
                    images: smartFolderStore.selected != nil ? v2Urls : folderStore.images,
                    startIndex: idx,
                    onDismiss: {
                        withAnimation(DS.Anim.normal) {
                            quickViewerIndex = nil
                        }
                    },
                    onIndexChange: { newIdx in
                        folderStore.selectedImageIndex = newIdx
                    },
                    onFindSimilar: { sourceUrl in
                        handleFindSimilar(sourceUrl: sourceUrl)
                    },
                    currentSupportsFeaturePrint: currentSupportsFeaturePrint(at: idx)
                )
```

- [ ] **Step 6: 加 currentSupportsFeaturePrint helper**

在 ContentView 内（`handleFindSimilar` 之后）插入：

```swift
    /// M2 Slice J — 查 idx 处图片的 supports_feature_print。读不到（idx 越界 / 行不存在）→ true 默认（不主动 disable，让用户点了再失败提示）。
    private func currentSupportsFeaturePrint(at idx: Int) -> Bool {
        let images = smartFolderStore.selected != nil ? v2Urls : folderStore.images
        guard idx < images.count, let store = indexStoreHolder.store else { return true }
        let url = images[idx]
        return (try? store.sync { db in
            let stmt = try db.prepare("""
                SELECT i.supports_feature_print FROM images i
                JOIN folders f ON i.folder_id = f.id
                WHERE f.root_path || '/' || i.relative_path = ? LIMIT 1;
            """)
            defer { sqlite3_finalize(stmt) }
            _ = sqlite3_bind_text(stmt, 1, (url.path as NSString).utf8String, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            guard sqlite3_step(stmt) == SQLITE_ROW else { return true }
            return sqlite3_column_int(stmt, 0) == 1
        }) ?? true
    }
```

- [ ] **Step 7: ESC 路由覆盖（ephemeral 视图打开时）**

EphemeralResultView 内 onClose button 已处理鼠标点击。SwiftUI 在 ContentView 层加全局 ESC 监听以支持键盘：

在 ContentView body 末尾（`.background { WindowAccessor(...) }` 之前）追加：

```swift
        .onKeyPress(.escape) {
            if currentEphemeral != nil {
                withAnimation(DS.Anim.normal) { currentEphemeral = nil }
                return .handled
            }
            return .ignored
        }
```

- [ ] **Step 8: 编译验证**

Run: `make build`
Expected: 0 error 0 warning。

- [ ] **Step 9: 手动 smoke test（端到端）**

Run: `make run`，按以下顺序操作：
1. 等启动后扫描 chip + fp 索引 chip 跑完（小 root 几秒，1 万图 ~17 分钟；用小 root 演示）
2. 双击任一缩略图进 QV
3. 点 QV bottomToolbar「找类似」按钮（图标 `rectangle.stack.badge.plus`）
4. 期望：QV 关闭 + 主区切到 EphemeralResultView，title = "类似于 xxx.png"，30 张缩略图按距离升序排列
5. 单击 EphemeralResultView 任一 cell → 进 preview（同 V2 mode 行为）
6. ESC 关 preview → 仍在 EphemeralResultView
7. ESC 再按 → 关 EphemeralResultView 回 baseGrid
8. 部分库测试（可选）：找一张图 ID 大的（fp 还没抽到）当源 → 应弹"尚未索引"红 banner

- [ ] **Step 10: Commit**

```bash
git add Glance/ContentView.swift
git commit -m "feat: ContentView ephemeral state + similarity query end-to-end (J.10)"
```

---

### Task J.11: Slice J 收尾（/go 五步 + Roadmap + PENDING + tag V2.1-beta1）

**Files:**
- Modify: `specs/Roadmap.md`（V2 进度段加 M2 Slice J 表 + Bug Fix 记录新增的）
- Modify: `specs/PENDING-USER-ACTIONS.md`（J 新增人工测试项）
- Modify: `CLAUDE.md`（文件结构段加 `Glance/Similarity/`）

- [ ] **Step 1: 跑完整 verify**

Run: `./scripts/verify.sh`
Expected: Stage 1 静态规则通过；Stage 2 编译 0 error 0 warning。红了不修完不进 Step 2。

- [ ] **Step 2: 同步 CLAUDE.md 文件结构**

在 `Glance/IndexStore/` 段之后插入 `Glance/Similarity/` 段：

```markdown
    ├── Similarity/                  ← V2 M2 类似图查找（feature print + Vision）
    │   ├── SimilarityService.swift           ← Vision VNFeaturePrintObservation 包装 + computeDistance batch top-N
    │   ├── FeaturePrintIndexer.swift          ← 后台 fp 索引 pipeline（batch 50 + cancel + enqueueIfNeeded）
    │   ├── FeaturePrintIndexingProgress.swift ← progress record（indexed/total/lastImageName）
    │   ├── FeaturePrintProgressView.swift     ← chip 形态进度 UI（mirror Slice I 紫色调区分）
    │   └── EphemeralResultView.swift          ← 临时结果视图（layout + ThumbnailCell 复用 + banner 槽）
```

- [ ] **Step 3: 同步 Roadmap.md**

在「V2 进度」段「M1 - 跨文件夹聚合 MVP」之后追加：

```markdown
### M2 - 类似图查找（3 周）

| Slice | 状态 | Ship as | 完成日期 | 关键 commit |
|---|---|---|---|---|
| **J** ⭐ thin similarity MVP | ✅ 完成 | V2.1-beta1 | YYYY-MM-DD | 见下方表格 |
| K Vision revision 迁移 + polish | 🚧 待开始 | V2.1 GA | — | — |

### Slice J 完成详细（11 task）

| Task | Goal | Commit |
|---|---|---|
| J.1 | SimilarityService（Vision wrapper）| TBD |
| J.2 | IndexStore 5 fp CRUD method | TBD |
| J.3 | FeaturePrintIndexer pipeline | TBD |
| J.4 | IndexStoreHolder fp progress hook | TBD |
| J.5 | ContentView wireIfReady 启动 indexer | TBD |
| J.6 | FolderStoreIndexBridge handleCreated enqueue | TBD |
| J.7 | FeaturePrintProgressView + DS.Similarity tokens | TBD |
| J.8 | EphemeralResultView | TBD |
| J.9 | QV toolbar 找类似按钮 | TBD |
| J.10 | ContentView ephemeral state + 端到端 | TBD |
| J.11 | /go 收尾 + tag V2.1-beta1 | TBD |
```

J.11 commit 后回填这里的 commit hash（用「docs: 回填 X hash 到 Roadmap」补丁 commit）。

在「关键架构决策」段尾追加 D11-D14：

```markdown
### M2 决策（2026-05-10 brainstorming + plan-time 拍板）

24. **D11 后台 feature print 索引启动即跑**：GlanceApp / ContentView wireIfReady 在 IndexStore ready 后立即启动 FeaturePrintIndexer.start()，全库 lazy backfill；已抽过的 row 通过 `feature_print IS NULL` SQL 谓词自然跳过。Why: 用户首次点"找类似"大概率已抽完，"立刻可用"体验优先于"启动 0 CPU"；CPU 占用换感知一致性。How to apply: 不在 lazy 模式（用户首点找类似才开抽）也不在 settings 加 toggle（M2 不引 Settings 面板）；K 阶段实测如电池机感知不可接受再考虑切策略。

25. **D12 M2 = 2 slice（J 端到端 + K polish）**：J（V2.1-beta1）一次 ship 后台索引 + QV 找类似按钮 + EphemeralResultView 端到端；K（V2.1 GA）专做 Vision revision 迁移 + 失败重试 polish + 错误 banner + 性能验收。Why: J 必须 user-perceptible（违反 vertical slice 三标准否决"backend only"切法）；K 是 polish + revision 数据一致性，单独 ship 不引新 demo 按钮。How to apply: J ship 后用户拿到完整 demo；K 仅修 J 暴露的 polish 项，不动 J 的 UI 接口。

26. **D13 类似图 = 纯 top-30 不加阈值过滤**：SimilarityService.queryTopN 取距离最小的 30 张返回；不加 hard threshold（0.6 之类）也不加 UI 分隔线。Why: 阈值是魔数字，不同库分布最优阈值差异大；用户自己判"像不像"成本低于学习配置。How to apply: queryTopN 写死 n=30；M3+ 如有调整诉求改成 setting；K 阶段如收用户反馈"小库末尾不准"考虑加 fade-out UI 提示但不切数据。

27. **D14 部分库时允许查 + banner 提示**：feature print 全库未抽完时（pendingTotal > 0）"找类似"按钮不 disable；查询走 fetchAllFeaturePrintsForCosine 拿当前已抽 row 跑 cosine；EphemeralResultView 顶部 banner = "已索引 X / Y 张，结果为部分库"。Why: 1 万图首次抽 ~17 分钟；disable 体验 17 分钟死锁。部分可用 + 显式提示符合 "show progress, don't gate" 原则。How to apply: ContentView.computeBanner 算 indexed/total，indexed >= total → banner = nil（隐藏）；EphemeralResultView bannerText 是可选参数。
```

- [ ] **Step 4: 同步 PENDING-USER-ACTIONS.md**

在 Pending 段末尾追加：

```markdown
### V2 M2 Slice J（2026-05-10）

- [ ] J 启动后 feature print indexer 自动开抽（chip 显示 "正在索引相似度 X / Y"）
- [ ] J 索引完成后 chip 自动消失
- [ ] J 索引中点 chip 上 X 按钮 → cancel 生效，chip 立刻消失
- [ ] J QV 内点「找类似」按钮 → 切到 EphemeralResultView 显示 30 张
- [ ] J EphemeralResultView 顶 X 按钮 / ESC 键退出回 baseGrid
- [ ] J EphemeralResultView 单击进 preview，ESC 退回 ephemeral 视图（不直接回 baseGrid）
- [ ] J EphemeralResultView 双击进 QV，ESC 退回 baseGrid（不回 ephemeral 视图，路径 1 兼容性）
- [ ] J 部分库时（feature_print IS NULL 还有行）找类似 → banner 显示 "已索引 X / Y 张，结果为部分库"
- [ ] J 全库索引完成时（indexed = total）banner 不显示
- [ ] J 添加新文件夹 → 新图 FSEvents 派发 → fp indexer 自动 enqueueIfNeeded → 该图很快被索引（看 chip 短暂出现）
- [ ] J 关 app 中途取消 fp indexer → 重启后自动从断点继续（feature_print IS NULL 行从 SQL 重新被拉到）
- [ ] J 损坏图 / RAW 等 Vision 不支持的格式 → 单图标 supports_feature_print=0 永久跳过，不阻塞 pipeline
- [ ] J QV 内当前图 supports_feature_print=0 → 「找类似」按钮 disable + tooltip 显示"该格式暂不支持类似图查找"
- [ ] J 1 万图典型库索引耗时记录（M1 mac 实测）：______ 分钟
- [ ] J 找类似查询响应耗时（10k 库）：______ 秒
```

- [ ] **Step 5: commit J.11（含所有文档同步）**

```bash
git add specs/Roadmap.md specs/PENDING-USER-ACTIONS.md CLAUDE.md
git commit -m "docs: V2 M2 Slice J ship → V2.1-beta1 (Roadmap + PENDING + CLAUDE.md sync)"
```

- [ ] **Step 6: 跑 verify 最终一遍 + push**

```bash
./scripts/verify.sh && git push
```

Expected: verify Stage 1+2 全绿；push 走 pre-push codex hook（J 涉及 .swift 改动，预期触发 codex 审查；通过则 push 完成）。

- [ ] **Step 7: tag V2.1-beta1**

```bash
git tag -a v2.1-beta1 -m "V2 M2 Slice J — feature print indexing + QV find similar end-to-end"
git push origin v2.1-beta1
```

- [ ] **Step 8: 一段话汇报**

汇报模板（参考 `.claude/commands/go.md`）：

> BUILD SUCCEEDED — 0 errors, 0 code warnings
>
> M2 Slice J ship 完成（V2.1-beta1，11 task / X commit）。新增 `Glance/Similarity/` 5 文件 + IndexStore 5 fp CRUD method + ContentView ephemeral 路由。后台 feature print 索引启动即跑，QV 找类似按钮端到端可用，EphemeralResultView 共用骨架就位（M3 搜索可复用）。文档同步 Roadmap + CLAUDE.md + PENDING（15 项人工验收）。pre-push codex hook 通过。tag v2.1-beta1 已推。下一步 Slice K（Vision revision 迁移 + polish + 性能验收）。

---

## Slice K: V2.1 GA（outline，K 启动前再写 detailed plan，~5 task）

> Slice K detail 留到 J ship 后实测过 → 写 dedicated plan（mirror M1 plan strategy "Slices B-I 概要"）。本段仅占位 + goal/deliverable，避免 J 实测后 K 假设需要修又重写。

### K.1: Vision revision 检测 + schema_meta 表

**Goal**：macOS 升级 `VNGenerateImageFeaturePrintRequest.revision` 不匹配时，自动 reset 全库 fp + 让 indexer 重抽。

**Deliverable**:
- IndexStoreSchema 升 v3：加 `schema_meta(key TEXT PRIMARY KEY, value TEXT)` 表
- IndexedImage 加 `resetAllFeaturePrintsForRevisionMigration(targetRevision: Int)` method（UPDATE images SET feature_print=NULL, feature_print_revision=NULL WHERE supports_feature_print=1）
- IndexStore 加 `fetchSchemaMeta(key:) -> String?` / `setSchemaMeta(key:value:)`
- ContentView wireIfReady 启动比对：当前 macOS 的 `VNGenerateImageFeaturePrintRequest().revision` vs `schema_meta` 中存的最近 revision；不匹配 → reset + log + 启动 indexer
- 模拟测试：手动改 schema_meta value → 重启验 indexer 重跑

### K.2: 失败重试策略（防无限 retry）

**Goal**：单图 Vision extract 失败 N 次（N=3）→ 标 supports_feature_print=0，不再尝试。

**Deliverable**:
- IndexStore 加 `feature_print_attempt_count INTEGER NOT NULL DEFAULT 0` 列（schema v4 ALTER TABLE）
- FeaturePrintIndexer 抽取失败时先 increment count，达到 3 再 setUnsupported；J.3 当前是失败立刻标 unsupported（K.2 改成宽容 retry）
- IndexStore 加 `incrementFeaturePrintAttempt(imageId:)` + `fetchAttemptCount(imageId:)`

### K.3: 错误 banner 复用（IndexStoreHolder.lastError）

**Goal**：indexer fatal error（IndexStore IO 异常）→ ContentView 红色 banner 自动展示。

**Deliverable**:
- 验 J.3 已建立的 `onError` 回调链路在真实异常下生效（J 阶段无单测，K 阶段 mock IndexStore 异常实测）
- 错误 banner 文案 review

### K.4: 性能验收（1 万图实测）

**Goal**：Slice J 验收预算（fp 索引 < 30 分钟 / 找类似查询 < 1 秒 / 60MB 内存峰值）实测过关。

**Deliverable**:
- 用真实 1 万图库（用户提供 / 合成）跑：启动 → fp 索引完成耗时
- 找类似查询响应时间（QV 找类似按钮 → EphemeralResultView 渲染）
- index.sqlite 体积变化 du 验证
- 写性能数据进 PENDING

### K.5: /go 收尾 + tag v2.1（GA）

**Deliverable**:
- 5 步 /go：verify 三段 + 文档同步 + PENDING 收尾 + commit + push
- Roadmap M2 表标"✅ 完成"
- tag `v2.1` 推 origin

---

### Slice K 完成详细（追溯式 — 2026-05-11 实施记录）

**注**：本表是 2026-05-11 K ship 后的追溯记录（K plan 阶段直接在 conversation 完成未及时拆 detailed task 表，违反 V2 milestone-level 工作流；事后纠正补此表）。实际落地比上方 outline 收敛了一些范围（schema_meta 表 / retry_count 列 / tag v2.1 都没做），下表为真相源。

| Task | 落地内容 | Commit |
|---|---|---|
| K.1 | Vision revision 启动期迁移：`SimilarityService.currentRevision` 静态 getter（构 `VNGenerateImageFeaturePrintRequest()` 读 `.revision` 默认值，避免 schema_meta 表的额外复杂度）+ `IndexedImage.resetFeaturePrintsWithStaleRevision(currentRevision: Int) throws -> Int`（UPDATE images SET feature_print/feature_print_revision = NULL WHERE feature_print_revision IS NOT NULL AND != ?，返回 `sqlite3_changes`）+ `ContentView.wireIfReady` 在 indexer.start 前调一次，>0 → `holderRef.lastError = "ℹ️ Vision 模型已更新，正在重新索引 X 张图片..."`（info banner 复用 lastError 通道，K.3 决定不升级 enum）；schema_meta 表方案丢弃（fetched revision 已能从 SQL `WHERE != ?` 直接判，无 meta 表必要）| `7347013` |
| K.2 | 失败重试 polish：`FeaturePrintIndexer.runLoop` 加 `var retryCounts: [Int64: Int]` in-memory（per-pipeline-run，session 限），`extractFailed` 累计 < `DS.Similarity.extractRetryThreshold = 3` 时不标 supports=0 让下批 fetch 自然重试；>= 3 才永久标。`unsupportedFormat` / `archiveFailed` 仍立即永久标（永久错误）。retry threshold 通过参数传 nonisolated runLoop 绕 MainActor 隔离 warning。决定**不入 DB schema**（K outline 原计划加 `feature_print_attempt_count` 列被否定）：跨 session 重置给坏盘修好的图再次机会是有意设计，schema 持久化反而违背该意图 | `7347013` |
| K.3 | 错误 banner 文案润色：3 处 `"feature print 索引..."` → `"类似图特征索引..."`（用户面向中文术语，跟 V2 UI 类似图按钮文案对齐）。决定**不升级** `lastError: String?` 到 `BannerMessage` enum（scope 不平衡，info / error 用前缀图标 ℹ️ / ⚠️ 区分够用，UI 不需重渲染逻辑）| `7347013` |
| K.4 | 性能验收（1 万图 fp 索引 < 30min / 查询 < 1s / index.sqlite < 50MB）| 🚧 **Deferred** — 等用户 1 万图大库实测机会；PENDING 已留位（"V2 M2 Slice K performance" 项）|
| K.5 | /go 收尾 + tag v2.1 | 🚧 **Deferred** — V2.1 GA 包内容已就位（K.1+K.2+K.3 全 ship），但用户当前不发布只继续往 M3 肝；tag 留到适当公开窗口再打 |

**plan vs 实际收敛点**：
1. schema_meta 表（K.1 outline）→ 砍掉，SQL WHERE 直判够用
2. `feature_print_attempt_count` schema 列（K.2 outline）→ 砍掉，in-memory 跨 session 重置更符合 polish 意图
3. `BannerMessage` enum 升级（K.3 outline 隐含）→ 砍掉，前缀图标够区分
4. `tag v2.1`（K.5）→ deferred，等用户公开发布意图

**Codex pre-push hook 在 K push 触发 1 个 P1 误判**："missing doc sync — specs/<module>.md 当前进度" — 根因是 hook PROMPT 第 11 条规则没考虑 V2 milestone-level plan 文档（per-milestone in `specs/v2/`，非 per-module）。当时走 `SKIP_CODEX_REVIEW=1` bypass + 870cf80 precedent。**根治在本追溯写入后**：hook 规则在 commit Roadmap CLAUDE.md 文档同步段已扩展明确 V2 工作流，下次 milestone 工作不会再误判。

---

## Pending（V2 M2 Slice J）

J.11 Step 4 已把 PENDING 项一次性追加到 `specs/PENDING-USER-ACTIONS.md`。本 plan 不再重复列。Slice K 启动前再追加 K 的人工测试项。

---

## M2 完成判定

满足以下全部条件 = M2 完成：

1. **三段式 verify**（`./scripts/verify.sh`）：J ship 后 + K ship 后 各一次，0 error 0 warning
2. **Slice J 11 task 全部 commit + push**
3. **Slice K ~5 task 全部 commit + push**
4. **PENDING-USER-ACTIONS** Slice J 15 项 + Slice K 全部人工项 用户测试通过
5. **三标准核对**：
   - (a) 端到端可跑：启动 V2.1 → 后台 fp 索引跑 → QV 找类似 → top-30 出现
   - (b) 用户可感知：QV 多了「找类似」按钮 + 索引 chip 多一行 + ephemeral 视图新增
   - (c) 独立可 ship：v2.1 tag 公开发布 / DMG 可分发
6. **回归**：V1 + V2 M1 既有功能不退化（QV / Inspector / smart folder grid / hide / FSEvents / dedup / 进度 chip 全部不变）
7. **性能目标（K.4 验收）**：1 万图 fp 索引 < 30 分钟 / 找类似查询 < 1s / index.sqlite 体积增量 < 50MB
8. **D11-D14 写入 `specs/Roadmap.md`**
9. **CLAUDE.md 文件结构同步**（`Glance/Similarity/` 段已加）
10. **`specs/v2/2026-05-10-m2-design.md` 状态从 design lock → ✅ shipped**

---

## Self-Review

完整 plan 写完后用 fresh eyes 跑一遍：

### 1. Spec coverage（design.md → plan task 映射）

| design.md 章节 | 对应 task |
|---|---|
| § 2.1 SimilarityService | J.1 |
| § 2.1 后台 feature print 索引 | J.3 + J.5 + J.6 |
| § 2.1 Vision revision 迁移 | K.1（outline）|
| § 2.1 Quick Viewer「找类似」按钮 | J.9 |
| § 2.1 EphemeralResultView 组件 | J.8 |
| § 2.1 失效处理（RAW + 部分库 banner）| J.10 + K.2 |
| § 4.1 5 个新增模块 | J.1 + J.3 + J.7 + J.8 + Progress（J.3 副产品）|
| § 4.2 5 个 IndexStore 扩展 | J.2（5 method 全覆盖）|
| § 4.2 IndexStoreHolder 扩展 | J.4 |
| § 4.2 QuickViewerOverlay 扩展 | J.9 |
| § 4.2 ContentView 扩展 | J.10 |
| § 4.2 FolderStoreIndexBridge 扩展 | J.6 |
| § 4.2 GlanceApp 扩展 | J.5（实际放 ContentView wireIfReady）|
| § 4.3 数据流 | J.3（启动）+ J.10（找类似查询）+ J.6（FSEvents）|
| § 5 EphemeralResultView 接口 | J.8 |
| § 6 Vision Revision 迁移逻辑 | K.1 |
| § 7.1 性能预算 | K.4 |
| § 7.2 验收标准 | M2 完成判定段 |
| § 8.1 Slice J 拆分 | J.1-J.11 task |
| § 8.2 Slice K 拆分 | K outline |
| § 9 已知风险 | 各 task step 内 inline 处理 |
| § 10 D11-D14 | J.11 Step 3 写入 Roadmap |

✅ Spec 全覆盖。

### 2. Placeholder scan

✅ 所有 task step 都有 actual code / actual command / actual expected output。无 "TBD"（K outline 内 commit hash "TBD" 是 plan 体外占位 — Roadmap commit hash 在 J.11 Step 3 commit 时回填，符合项目「docs: 回填 hash」commit 模式）。

### 3. Type / signature consistency

- `SimilarityService.extract(url:)` 返回 `(archived: Data, revision: Int)` — J.1 定义，J.3 调用一致 ✓
- `SimilarityService.queryTopN(source:candidates:excludingId:n:)` — J.1 定义，J.10 调用一致 ✓
- `SimilarityService.unarchive(_:)` — J.1 定义，J.10 调用一致 ✓
- `IndexStore.fetchImagesNeedingFeaturePrint(limit:)` 返 `[(id:, urlBookmark:, relativePath:, folderId:)]` — J.2 定义，J.3 调用一致 ✓
- `IndexStore.setFeaturePrint(imageId:, archivedData:, revision:)` — J.2 定义，J.3 调用一致 ✓
- `IndexStore.setFeaturePrintUnsupported(imageId:)` — J.2 定义，J.3 调用一致 ✓
- `IndexStore.fetchAllFeaturePrintsForCosine()` 返 `[(id:, archivedData:)]` — J.2 定义，J.10 调用一致 ✓
- `IndexStore.fetchFeaturePrintByFullPath(_:)` — J.2 定义，J.10 调用一致 ✓
- `IndexStore.fetchUrlsByIds(_:)` — J.2 定义，J.10 调用一致 ✓
- `FeaturePrintIndexer.start()` / `cancel()` / `enqueueIfNeeded()` / `onProgress` / `onError` — J.3 定义，J.5/J.6 调用一致 ✓
- `IndexStoreHolder.featurePrintProgress` / `cancelFeaturePrintIndexing` / `featurePrintIndexer` — J.4 定义，J.5/J.7 引用一致 ✓
- `FolderStoreIndexBridge.setFeaturePrintIndexer(_:)` — J.6 定义，J.6 Step 3 调用一致 ✓
- `QuickViewerOverlay.init` 加两参数 `onFindSimilar` / `currentSupportsFeaturePrint` — J.9 定义，J.10 调用一致 ✓
- `EphemeralResultView` props (title/urls/bannerText/onClose/onSingleClick/onDoubleClick) — J.8 定义，J.10 调用一致 ✓
- `EphemeralRequest` enum + `currentEphemeral` state — J.10 定义，J.10 内部一致 ✓

✅ All consistent.

### 4. Scope check

11 task J + 5 task K = 16 task ≈ 3 周。每 task 平均 1-1.5 天，符合 bite-sized + frequent commit。J 单 slice 端到端覆盖（vertical slice 三标准过）✓。

✅ Scope 合理。

---

**Plan 写完。落盘 `specs/v2/2026-05-10-m2-implementation-plan.md`，等用户审批 → 选择执行模式。**
