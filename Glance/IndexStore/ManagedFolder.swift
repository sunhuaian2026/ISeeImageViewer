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

nonisolated extension IndexStore {

    /// Register a root managed folder; **幂等**：同一 path 重复调用返回已有 id，不新建行。
    /// `path` = rootURL.standardizedFileURL.path，作为 unique 键。
    /// caller（FolderStoreIndexBridge）传 path + bookmark，bookmark 在重启可能 stale 但 path 稳定。
    func registerRoot(path: String, bookmark: Data) throws -> Int64 {
        try sync { db in
            let selStmt = try db.prepare("SELECT id FROM folders WHERE root_path = ? LIMIT 1;")
            defer { sqlite3_finalize(selStmt) }
            sqlite3_bind_text(selStmt, 1, (path as NSString).utf8String, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            if sqlite3_step(selStmt) == SQLITE_ROW {
                return sqlite3_column_int64(selStmt, 0)
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
