//
//  FolderStore.swift
//  ISeeImageViewer
//

import Foundation
import AppKit
import Combine

enum SortOrder: String, CaseIterable {
    case nameAsc  = "名称 ↑"
    case nameDesc = "名称 ↓"
    case dateAsc  = "日期 ↑"
    case dateDesc = "日期 ↓"
    case sizeAsc  = "大小 ↑"
    case sizeDesc = "大小 ↓"
}

@MainActor
class FolderStore: ObservableObject {
    @Published var folders: [URL] = []
    @Published var selectedFolder: URL? = nil
    @Published var images: [URL] = []
    @Published var selectedImageIndex: Int? = nil
    @Published var isLoadingImages: Bool = false
    @Published var imageCountByFolder: [URL: Int] = [:]
    @Published var sortOrder: SortOrder = {
        let raw = UserDefaults.standard.string(forKey: "sortOrder") ?? ""
        return SortOrder(rawValue: raw) ?? .nameAsc
    }() {
        didSet {
            UserDefaults.standard.set(sortOrder.rawValue, forKey: "sortOrder")
            guard !images.isEmpty else { return }
            Task { images = await sortImages(images) }
        }
    }

    private let bookmarkManager: BookmarkManager

    private static let supportedExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "heif", "gif", "webp", "tiff"
    ]

    init(bookmarkManager: BookmarkManager) {
        self.bookmarkManager = bookmarkManager
    }

    // MARK: - Public

    func loadSavedFolders() {
        let restored = bookmarkManager.restoreBookmarks()
        for url in restored {
            _ = bookmarkManager.startAccessing(url)
        }
        folders = restored.sorted {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        }
    }

    func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "选择文件夹"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        if folders.contains(url) {
            selectFolder(url)
            return
        }

        do {
            try bookmarkManager.saveBookmark(for: url)
        } catch {
            print("saveBookmark failed: \(error)")
            return
        }

        _ = bookmarkManager.startAccessing(url)
        folders.append(url)
        selectFolder(url)
    }

    func removeFolder(_ url: URL) {
        bookmarkManager.stopAccessing(url)
        bookmarkManager.removeBookmark(for: url)
        folders.removeAll { $0 == url }
        imageCountByFolder.removeValue(forKey: url)
        if selectedFolder == url {
            selectedFolder = nil
            images = []
            selectedImageIndex = nil
        }
    }

    func selectFolder(_ url: URL) {
        selectedFolder = url
        selectedImageIndex = nil
        images = []
        Task { await scanImages(in: url) }
    }

    // MARK: - Private

    private func scanImages(in url: URL) async {
        isLoadingImages = true
        let ext = Self.supportedExtensions
        let scanned: [URL] = await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            guard let contents = try? fm.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else { return [] }
            return contents.filter { ext.contains($0.pathExtension.lowercased()) }
        }.value
        let sorted = await sortImages(scanned)
        images = sorted
        imageCountByFolder[url] = sorted.count
        isLoadingImages = false
    }

    private func sortImages(_ urls: [URL]) async -> [URL] {
        let order = sortOrder
        return await Task.detached(priority: .userInitiated) {
            switch order {
            case .nameAsc:
                return urls.sorted {
                    $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
                }
            case .nameDesc:
                return urls.sorted {
                    $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedDescending
                }
            case .dateAsc, .dateDesc:
                let keys: Set<URLResourceKey> = [.contentModificationDateKey]
                let dated: [(URL, Date)] = urls.map { url in
                    let date = (try? url.resourceValues(forKeys: keys))?.contentModificationDate
                    return (url, date ?? .distantPast)
                }
                let sorted = dated.sorted { order == .dateAsc ? $0.1 < $1.1 : $0.1 > $1.1 }
                return sorted.map { $0.0 }
            case .sizeAsc, .sizeDesc:
                let keys: Set<URLResourceKey> = [.fileSizeKey]
                let sized: [(URL, Int)] = urls.map { url in
                    let size = (try? url.resourceValues(forKeys: keys))?.fileSize
                    return (url, size ?? Int.max)
                }
                let sorted = sized.sorted { order == .sizeAsc ? $0.1 < $1.1 : $0.1 > $1.1 }
                return sorted.map { $0.0 }
            }
        }.value
    }
}
