//
//  ImageGridView.swift
//  ISeeImageViewer
//

import SwiftUI
import ImageIO

struct ImageGridView: View {
    @EnvironmentObject var folderStore: FolderStore
    var onDoubleClick: (Int) -> Void = { _ in }

    @FocusState private var isFocused: Bool
    @State private var highlightedURL: URL? = nil

    private var gridColumns: [GridItem] {
        [GridItem(.adaptive(
            minimum: folderStore.thumbnailSize,
            maximum: folderStore.thumbnailSize + 20
        ), spacing: DS.Thumbnail.spacing)]
    }

    var body: some View {
        Group {
            if folderStore.selectedFolder == nil {
                DS.Color.gridBackground
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay {
                        ContentUnavailableView(
                            "选择文件夹",
                            systemImage: DS.Icon.folder,
                            description: Text("从左侧添加并选择一个文件夹来浏览图片")
                        )
                    }
                    .contextMenu {
                        Button("添加文件夹…") { folderStore.addFolder() }
                    }
            } else if folderStore.isLoadingImages {
                ProgressView("加载中…")
            } else if folderStore.images.isEmpty {
                ContentUnavailableView(
                    "无图片",
                    systemImage: "photo",
                    description: Text("此文件夹中没有支持的图片格式")
                )
            } else {
                gridContent
            }
        }
        .navigationTitle({
            if let idx = folderStore.selectedImageIndex,
               folderStore.images.indices.contains(idx) {
                return folderStore.images[idx].lastPathComponent
            }
            return folderStore.selectedFolder?.lastPathComponent ?? ""
        }())
        .onChange(of: folderStore.images) { _, _ in
            highlightedURL = nil
        }
        .toolbar {
            if folderStore.selectedImageIndex == nil {
                ToolbarItem(placement: .automatic) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.grid.3x3")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Slider(
                            value: $folderStore.thumbnailSize,
                            in: DS.Thumbnail.minSize...DS.Thumbnail.maxSize,
                            step: 10
                        )
                        .labelsHidden()
                        .frame(width: 140)
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    .help("调整缩略图大小")
                }
                ToolbarItem(placement: .automatic) {
                    HStack(spacing: 4) {
                        Picker("", selection: Binding<SortKey>(
                            get: { folderStore.sortKey },
                            set: { key in folderStore.applySortKey(key, direction: .asc) }
                        )) {
                            ForEach(SortKey.allCases, id: \.self) { key in
                                Text(key.rawValue).tag(key)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .help("排序方式")
                        Button {
                            folderStore.applySortKey(folderStore.sortKey, direction: folderStore.sortDirection.toggled)
                        } label: {
                            Image(systemName: folderStore.sortDirection == .asc ? "arrow.up" : "arrow.down")
                        }
                        .buttonStyle(.borderless)
                        .help(folderStore.sortDirection == .asc ? "升序（点击切换降序）" : "降序（点击切换升序）")
                    }
                }
            }
        }
    }

    // MARK: - Grid

    private var gridContent: some View {
        let images = folderStore.images
        let colCount = columnCount()

        return ScrollViewReader { scrollProxy in
            ScrollView {
                LazyVGrid(columns: gridColumns, spacing: DS.Thumbnail.spacing) {
                    ForEach(images, id: \.self) { url in
                        VStack(spacing: DS.Spacing.xs) {
                            ThumbnailCell(url: url, isHighlighted: highlightedURL == url, size: folderStore.thumbnailSize)
                            Text(url.lastPathComponent)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .frame(maxWidth: folderStore.thumbnailSize)
                        }
                        .id(url)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            guard let idx = folderStore.images.firstIndex(of: url) else { return }
                            onDoubleClick(idx)
                        }
                        .onTapGesture(count: 1) {
                            highlightedURL = url
                            folderStore.selectedImageIndex = folderStore.images.firstIndex(of: url)
                        }
                    }
                }
                .animation(DS.Anim.fast, value: folderStore.thumbnailSize)
                .padding(DS.Spacing.sm)
            }
            .background(DS.Color.gridBackground)
            .focusable()
            .focused($isFocused)
            .onAppear { isFocused = true }
            // Space：进入全窗口查看器
            .onKeyPress(.space) {
                guard !images.isEmpty else { return .ignored }
                let target = highlightedURL.flatMap({ folderStore.images.firstIndex(of: $0) }) ?? 0
                onDoubleClick(target)
                return .handled
            }
            // 方向键导航
            .onKeyPress(.leftArrow)  { moveHighlight(by: -1,        colCount: colCount, total: images.count, proxy: scrollProxy); return .handled }
            .onKeyPress(.rightArrow) { moveHighlight(by: +1,        colCount: colCount, total: images.count, proxy: scrollProxy); return .handled }
            .onKeyPress(.upArrow)    { moveHighlight(by: -colCount, colCount: colCount, total: images.count, proxy: scrollProxy); return .handled }
            .onKeyPress(.downArrow)  { moveHighlight(by: +colCount, colCount: colCount, total: images.count, proxy: scrollProxy); return .handled }
        }
    }

    // MARK: - Helpers

    private func moveHighlight(by delta: Int, colCount: Int, total: Int, proxy: ScrollViewProxy) {
        guard total > 0 else { return }
        let current = highlightedURL.flatMap({ folderStore.images.firstIndex(of: $0) })
            ?? (delta > 0 ? -1 : 0)
        let next = max(0, min(total - 1, current + delta))
        highlightedURL = folderStore.images[next]
        withAnimation(DS.Anim.fast) {
            proxy.scrollTo(folderStore.images[next], anchor: .center)
        }
    }

    private func columnCount() -> Int {
        // 估算列数，用于上下方向键步进
        let cellWidth = folderStore.thumbnailSize + DS.Thumbnail.spacing
        let windowWidth = NSApp.keyWindow?.contentView?.bounds.width ?? 800
        return max(1, Int(windowWidth / cellWidth))
    }

}

// MARK: - ThumbnailCell

struct ThumbnailCell: View {
    let url: URL
    var isHighlighted: Bool = false
    var size: CGFloat = DS.Thumbnail.defaultSize
    @State private var thumbnail: NSImage? = nil
    @State private var isHovered = false

    var body: some View {
        ZStack {
            if let image = thumbnail {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.secondary.opacity(0.15))
                    .frame(width: size, height: size)
                    .overlay { ProgressView() }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: DS.Thumbnail.cornerRadius))
        .overlay {
            if isHovered && !isHighlighted {
                RoundedRectangle(cornerRadius: DS.Thumbnail.cornerRadius)
                    .fill(DS.Color.hoverOverlay)
            }
        }
        .overlay {
            if isHighlighted {
                RoundedRectangle(cornerRadius: DS.Thumbnail.cornerRadius)
                    .fill(Color.accentColor.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Thumbnail.cornerRadius)
                            .stroke(Color.accentColor, lineWidth: 2)
                    )
            }
        }
        .scaleEffect(isHovered && !isHighlighted ? 1.03 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .animation(DS.Anim.fast, value: isHighlighted)
        .animation(DS.Anim.fast, value: size)
        .onHover { isHovered = $0 }
        .task(id: url) {
            thumbnail = nil
            let scale = NSScreen.main?.backingScaleFactor ?? 2.0
            let result = await loadThumbnail(url: url, maxPixelSize: Int(size * scale))
            guard !Task.isCancelled else { return }
            thumbnail = result
        }
    }
}

// MARK: - Thumbnail Loading（internal，供 FilmstripCell 复用）

func loadThumbnail(url: URL, maxPixelSize: Int = 200) async -> NSImage? {
    await Task.detached(priority: .userInitiated) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }.value
}
