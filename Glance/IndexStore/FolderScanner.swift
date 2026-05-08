import Foundation

struct ScanProgress {
    let totalScanned: Int
    let totalIndexed: Int
    let lastIndexed: URL?
}

nonisolated final class FolderScanner {

    let store: IndexStore

    init(store: IndexStore) {
        self.store = store
    }

    /// Recursively scan a root URL and insert image records into IndexStore.
    /// `onProgress` is called every 50 files (best-effort).
    /// Caller must have started accessing the security-scoped resource if needed.
    /// `rootBookmark`：调用方已对 rootURL 创建好的 .withSecurityScope bookmark；scanner 把它
    /// 复制进每个 image row 的 url_bookmark 字段（**不**为 enumerator 出来的子文件单独创建
    /// bookmark —— macOS 沙盒规则：子 URL 仅通过 active 父 scope 隐式访问，自身无 scope，
    /// 不能创建 .withSecurityScope bookmark）。读图时由调用方解析 root bookmark + 拼
    /// relative_path 重建子 URL 访问。
    func scan(
        rootURL: URL,
        rootBookmark: Data,
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
            // 复用 root bookmark（不为子文件单独建 .withSecurityScope bookmark，sandbox 不允许）；
            // 读图时由调用方 resolve(rootBookmark) → startAccessing → root.appendingPathComponent(relPath)
            let record = ImageInsertRecord(
                urlBookmark: rootBookmark,
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
