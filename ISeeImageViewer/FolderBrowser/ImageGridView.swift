//
//  ImageGridView.swift
//  ISeeImageViewer
//

import SwiftUI
import ImageIO

struct ImageGridView: View {
    @EnvironmentObject var folderStore: FolderStore

    private let columns = [GridItem(.adaptive(
        minimum: DS.Thumbnail.defaultSize,
        maximum: DS.Thumbnail.defaultSize + DS.Spacing.xl
    ))]

    var body: some View {
        Group {
            if folderStore.selectedFolder == nil {
                Color.primary.opacity(0.001)
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
                ScrollView {
                    LazyVGrid(columns: columns, spacing: DS.Thumbnail.spacing) {
                        ForEach(Array(folderStore.images.enumerated()), id: \.element) { index, url in
                            VStack(spacing: DS.Spacing.xs) {
                                ThumbnailCell(url: url)
                                    .onTapGesture(count: 2) {
                                        withAnimation(DS.Animation.normal) {
                                            folderStore.selectedImageIndex = index
                                        }
                                    }
                                Text(url.deletingPathExtension().lastPathComponent)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .frame(maxWidth: DS.Thumbnail.defaultSize)
                            }
                        }
                    }
                    .padding(DS.Spacing.sm)
                }
            }
        }
        .navigationTitle(folderStore.selectedFolder?.lastPathComponent ?? "")
    }
}

// MARK: - ThumbnailCell

struct ThumbnailCell: View {
    let url: URL
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
            if isHovered {
                RoundedRectangle(cornerRadius: DS.Thumbnail.cornerRadius)
                    .fill(DS.Color.hoverBackground)
            }
        }
        .animation(DS.Animation.fast, value: isHovered)
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
