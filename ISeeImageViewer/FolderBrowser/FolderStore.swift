//
//  FolderStore.swift
//  ISeeImageViewer
//

import Foundation
import AppKit
import Combine

// MARK: - FolderNode（树形节点）

struct FolderNode: Identifiable, Hashable {
    let url: URL
    /// nil = 无子文件夹（叶节点）；non-nil = 有子文件夹（可展开）
    var children: [FolderNode]?

    var id: URL { url }

    static func == (lhs: FolderNode, rhs: FolderNode) -> Bool {
        lhs.url == rhs.url
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }
}

// MARK: - SortOrder

enum SortOrder: String, CaseIterable {
    case nameAsc  = "名称 ↑"
    case nameDesc = "名称 ↓"
    case dateAsc  = "日期 ↑"
    case dateDesc = "日期 ↓"
    case sizeAsc  = "大小 ↑"
    case sizeDesc = "大小 ↓"
}

// MARK: - FolderStore

@MainActor
class FolderStore: ObservableObject {
    @Published var rootFolders: [FolderNode] = []
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
        Task {
            var nodes: [FolderNode] = []
            for url in restored {
                let node = await discoverTree(at: url)
                nodes.append(node)
            }
            rootFolders = nodes.sorted {
                $0.url.lastPathComponent.localizedStandardCompare($1.url.lastPathComponent) == .orderedAscending
            }
            // 统计各文件夹图片数（后台完成，badge 会自动更新）
            for node in rootFolders {
                await countImagesInTree(node)
            }
        }
    }

    func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "选择文件夹"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        if rootFolders.contains(where: { $0.url == url }) {
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

        Task {
            let node = await discoverTree(at: url)
            rootFolders.append(node)
            rootFolders.sort {
                $0.url.lastPathComponent.localizedStandardCompare($1.url.lastPathComponent) == .orderedAscending
            }
            await countImagesInTree(node)
            selectFolder(url)
        }
    }

    func removeFolder(_ url: URL) {
        guard rootFolders.contains(where: { $0.url == url }) else { return }
        bookmarkManager.stopAccessing(url)
        bookmarkManager.removeBookmark(for: url)
        rootFolders.removeAll { $0.url == url }
        imageCountByFolder.removeValue(forKey: url)
        // 若选中的是被删除树中的任意节点，则取消选择
        if let selected = selectedFolder,
           selected == url || selected.path.hasPrefix(url.path + "/") {
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

    // MARK: - Tree Discovery

    /// 递归构建 FolderNode 树（只扫目录，不扫图片）
    private func discoverTree(at url: URL) async -> FolderNode {
        let subdirs: [URL] = await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            guard let contents = try? fm.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { return [] }
            return contents
                .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true }
                .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        }.value

        if subdirs.isEmpty {
            return FolderNode(url: url, children: nil)
        }

        var children: [FolderNode] = []
        for subdir in subdirs {
            let child = await discoverTree(at: subdir)
            children.append(child)
        }
        return FolderNode(url: url, children: children)
    }

    /// 递归统计每个节点的直接图片数，结果写入 imageCountByFolder
    private func countImagesInTree(_ node: FolderNode) async {
        let ext = Self.supportedExtensions
        let url = node.url
        let count: Int = await Task.detached(priority: .utility) {
            let fm = FileManager.default
            guard let contents = try? fm.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else { return 0 }
            return contents.filter { ext.contains($0.pathExtension.lowercased()) }.count
        }.value
        imageCountByFolder[node.url] = count
        if let children = node.children {
            for child in children {
                await countImagesInTree(child)
            }
        }
    }

    // MARK: - Image Scanning

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
