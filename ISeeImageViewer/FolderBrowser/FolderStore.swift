//
//  FolderStore.swift
//  ISeeImageViewer
//

import Foundation
import AppKit
import Combine

@MainActor
class FolderStore: ObservableObject {
    @Published var folders: [URL] = []
    @Published var selectedFolder: URL? = nil
    @Published var images: [URL] = []
    @Published var selectedImageIndex: Int? = nil
    @Published var isLoadingImages: Bool = false

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
            return contents
                .filter { ext.contains($0.pathExtension.lowercased()) }
                .sorted {
                    $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
                }
        }.value
        images = scanned
        isLoadingImages = false
    }
}
