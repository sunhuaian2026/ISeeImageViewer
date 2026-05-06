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
