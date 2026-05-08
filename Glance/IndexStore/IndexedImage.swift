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

nonisolated extension IndexStore {

    /// 幂等 insert：SELECT-first by (folder_id, relative_path)。
    /// 行存在 → 返回已有 id；不存在 → INSERT（**不用 OR IGNORE**，让 FK / NOT NULL /
    /// 其他 constraint violation 真实 surface，而不是被 OR IGNORE 静默吞成"post-IGNORE
    /// lookup 找不到行"的混淆错误）。
    /// 错误消息含 record 关键字段 dump，下次失败直接看 root cause。
    func insertImageIfAbsent(_ record: ImageInsertRecord) throws -> Int64 {
        try sync { db in
            // 1. SELECT first：行存在直接返回 id（幂等 happy path）
            let lookupStmt = try db.prepare("SELECT id FROM images WHERE folder_id = ? AND relative_path = ? LIMIT 1;")
            defer { sqlite3_finalize(lookupStmt) }
            try checkBind(sqlite3_bind_int64(lookupStmt, 1, record.folderId), index: 1, db: db)
            try checkBind(sqlite3_bind_text(lookupStmt, 2, (record.relativePath as NSString).utf8String, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self)), index: 2, db: db)
            if sqlite3_step(lookupStmt) == SQLITE_ROW {
                return sqlite3_column_int64(lookupStmt, 0)
            }

            // 2. 不存在 → INSERT（不带 OR IGNORE，让真实错误 surface）
            let insStmt = try db.prepare("""
                INSERT INTO images
                (url_bookmark, birth_time, file_size, format, filename, relative_path,
                 folder_id, dimensions_width, dimensions_height, supports_feature_print)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 1);
            """)
            defer { sqlite3_finalize(insStmt) }

            let bookmarkBytes = record.urlBookmark as NSData
            try checkBind(sqlite3_bind_blob(insStmt, 1, bookmarkBytes.bytes, Int32(bookmarkBytes.length), unsafeBitCast(-1, to: sqlite3_destructor_type.self)), index: 1, db: db)
            try checkBind(sqlite3_bind_double(insStmt, 2, record.birthTime.timeIntervalSince1970), index: 2, db: db)
            try checkBind(sqlite3_bind_int64(insStmt, 3, record.fileSize), index: 3, db: db)
            try checkBind(sqlite3_bind_text(insStmt, 4, (record.format as NSString).utf8String, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self)), index: 4, db: db)
            try checkBind(sqlite3_bind_text(insStmt, 5, (record.filename as NSString).utf8String, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self)), index: 5, db: db)
            try checkBind(sqlite3_bind_text(insStmt, 6, (record.relativePath as NSString).utf8String, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self)), index: 6, db: db)
            try checkBind(sqlite3_bind_int64(insStmt, 7, record.folderId), index: 7, db: db)
            if let w = record.dimensionsWidth {
                try checkBind(sqlite3_bind_int(insStmt, 8, Int32(w)), index: 8, db: db)
            } else {
                try checkBind(sqlite3_bind_null(insStmt, 8), index: 8, db: db)
            }
            if let h = record.dimensionsHeight {
                try checkBind(sqlite3_bind_int(insStmt, 9, Int32(h)), index: 9, db: db)
            } else {
                try checkBind(sqlite3_bind_null(insStmt, 9), index: 9, db: db)
            }

            let stepResult = sqlite3_step(insStmt)
            guard stepResult == SQLITE_DONE else {
                throw IndexDatabaseError.stepFailed(message: """
                    insertImage step \(stepResult): \(db.lastErrorMessage()) — \
                    folder_id=\(record.folderId), relative_path=\(record.relativePath), \
                    filename=\(record.filename), format=\(record.format), \
                    file_size=\(record.fileSize), bookmark_size=\(record.urlBookmark.count)
                    """)
            }
            return sqlite3_last_insert_rowid(db.handle)
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
