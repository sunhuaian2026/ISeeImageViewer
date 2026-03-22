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
    @State private var highlightedIndex: Int? = nil

    private let columns = [GridItem(.adaptive(
        minimum: DS.Thumbnail.defaultSize,
        maximum: DS.Thumbnail.defaultSize + DS.Spacing.xl
    ))]

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
        .navigationTitle(folderStore.selectedFolder?.lastPathComponent ?? "")
        .onChange(of: folderStore.images) { _, _ in
            highlightedIndex = nil
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Menu {
                    ForEach(SortOrder.allCases, id: \.self) { order in
                        Button {
                            folderStore.sortOrder = order
                        } label: {
                            Label(
                                order.rawValue,
                                systemImage: folderStore.sortOrder == order ? "checkmark" : ""
                            )
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .help("排序方式")
            }
        }
    }

    // MARK: - Grid

    private var gridContent: some View {
        let images = folderStore.images
        let colCount = columnCount()

        return ScrollViewReader { scrollProxy in
            ScrollView {
                LazyVGrid(columns: columns, spacing: DS.Thumbnail.spacing) {
                    ForEach(Array(images.enumerated()), id: \.element) { index, url in
                        VStack(spacing: DS.Spacing.xs) {
                            ThumbnailCell(url: url, isHighlighted: highlightedIndex == index)
                                .onTapGesture(count: 2) {
                                    onDoubleClick(index)
                                }
                                .onTapGesture(count: 1) {
                                    highlightedIndex = index
                                    folderStore.selectedImageIndex = index
                                }
                            Text(url.deletingPathExtension().lastPathComponent)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .frame(maxWidth: DS.Thumbnail.defaultSize)
                        }
                        .id(index)
                    }
                }
                .padding(DS.Spacing.sm)
            }
            .background(DS.Color.gridBackground)
            .focusable()
            .focused($isFocused)
            .onAppear { isFocused = true }
            // Space：进入全窗口查看器
            .onKeyPress(.space) {
                let target = highlightedIndex ?? 0
                guard !images.isEmpty else { return .ignored }
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
        let current = highlightedIndex ?? (delta > 0 ? -1 : 0)
        let next = max(0, min(total - 1, current + delta))
        highlightedIndex = next
        withAnimation(DS.Anim.fast) {
            proxy.scrollTo(next, anchor: .center)
        }
    }

    private func columnCount() -> Int {
        // 估算列数，用于上下方向键步进
        let cellWidth = DS.Thumbnail.defaultSize + DS.Thumbnail.spacing
        let windowWidth = NSApp.keyWindow?.contentView?.bounds.width ?? 800
        return max(1, Int(windowWidth / cellWidth))
    }
}

// MARK: - ThumbnailCell

struct ThumbnailCell: View {
    let url: URL
    var isHighlighted: Bool = false
    @State private var thumbnail: NSImage? = nil
    @State private var isHovered = false

    var body: some View {
        ZStack {
            if let image = thumbnail {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: DS.Thumbnail.defaultSize, height: DS.Thumbnail.defaultSize)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.secondary.opacity(0.15))
                    .frame(width: DS.Thumbnail.defaultSize, height: DS.Thumbnail.defaultSize)
                    .overlay { ProgressView() }
            }
        }
        .frame(width: DS.Thumbnail.defaultSize, height: DS.Thumbnail.defaultSize)
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
        .onHover { isHovered = $0 }
        .task { thumbnail = await loadThumbnail(url: url) }
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
