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
