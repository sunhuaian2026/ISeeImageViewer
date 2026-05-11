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
    /// 必须显式 nonisolated：FeaturePrintIndexer 是 @MainActor final class，
    /// 不加 nonisolated 时 static func 会继承 MainActor 隔离，导致 Task.detached
    /// 内的 `await Self.runLoop(...)` hop 回主线程，Vision + SQLite 在 main thread 跑阻塞 UI。
    nonisolated private static func runLoop(
        store: IndexStore,
        batchSize: Int,
        progressCB: ((FeaturePrintIndexingProgress?) -> Void)?,
        errorCB: ((String) -> Void)?
    ) async {
        var totalIndexed = 0
        // total 在批次开始时计算（pending 估算总量）
        var pendingTotal = 0
        do {
            // COUNT(*) 单独 query，避免传 Int.max 给 fetch 内部 Int32(limit) 溢出 trap
            pendingTotal = try store.countImagesNeedingFeaturePrint()
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
                } catch SimilarityService.SimilarityError.extractFailed {
                    // 单图 I/O 失败（坏文件 / 权限丢失）→ 永久标 supports=0 跳过，不阻塞 pipeline
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
