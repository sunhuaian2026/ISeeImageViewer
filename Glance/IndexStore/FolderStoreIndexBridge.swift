//
//  FolderStoreIndexBridge.swift
//  Glance
//
//  当 V1 FolderStore.rootFolders 变化时，把新 root 注册到 IndexStore
//  + 启动 FolderScanner 异步扫描。FolderStore 本身 0 改动，bridge 由
//  ContentView 在 IndexStore ready 后创建并显式调 sync(with:)。
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class FolderStoreIndexBridge: ObservableObject {

    let indexStore: IndexStore
    /// Track which root URLs we've already registered (by standardized path)
    /// to avoid duplicate registration / rescan across calls.
    private var registeredPaths: Set<String> = []

    init(indexStore: IndexStore) {
        self.indexStore = indexStore
    }

    /// Diff incoming rootFolders vs registered set; register/scan new ones.
    /// Removed folders are NOT cleaned up in Slice A (Slice G FSEvents will revisit).
    /// Caller (ContentView) invokes whenever folderStore.rootFolders changes.
    func sync(with rootFolders: [FolderNode]) async {
        let newRoots = rootFolders.filter {
            !registeredPaths.contains($0.url.standardizedFileURL.path)
        }
        for node in newRoots {
            await registerAndScan(rootURL: node.url)
            registeredPaths.insert(node.url.standardizedFileURL.path)
        }
    }

    /// Register one root + scan in background. Security-scoped access is
    /// assumed already started by V1 BookmarkManager.startAccessing(url).
    /// 幂等：registerRoot 用 path 做 unique 键，重启同一 path 复用 id；
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

            // 局部 capture indexStore 避免 capturing self 的 Sendable 警告。
            // indexStore 是 class，引用本身可跨 actor 边界。
            // rootBookmark capture 进 detached：scanner 把它复用到每条 image row 的
            // url_bookmark（macOS sandbox 不允许子文件创建 .withSecurityScope bookmark）
            let store = self.indexStore
            let rootBookmarkCopy = bookmark
            await Task.detached(priority: .utility) {
                let scanner = FolderScanner(store: store)
                do {
                    try scanner.scan(rootURL: rootURL, rootBookmark: rootBookmarkCopy, folderId: folderId) { progress in
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
