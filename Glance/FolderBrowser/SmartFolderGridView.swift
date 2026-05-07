//
//  SmartFolderGridView.swift
//  Glance
//
//  跨文件夹 grid。显示 SmartFolderStore.queryResult 的图，复用 V1 顶层
//  loadThumbnail(url:maxPixelSize:) 函数（位于 ImageGridView.swift）。
//
//  Slice A 仅渲染 cell（无选中 / 无 hover preview / 无双击进 QuickViewer），
//  这些交互留待后续 slice。hover tooltip 显示 relative path 已加（D5）。
//

import SwiftUI

struct SmartFolderGridView: View {

    @EnvironmentObject var smartFolderStore: SmartFolderStore

    private let columns = [
        GridItem(.adaptive(minimum: 140, maximum: 200), spacing: DS.Spacing.sm)
    ]

    var body: some View {
        ScrollView {
            if smartFolderStore.queryResult.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: columns, spacing: DS.Spacing.sm) {
                    ForEach(smartFolderStore.queryResult) { image in
                        SmartFolderImageCell(image: image)
                    }
                }
                .padding(DS.Spacing.md)
            }
        }
        .background(DS.Color.gridBackground)
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: DS.Spacing.md) {
            if smartFolderStore.isQuerying {
                ProgressView()
                Text("正在加载...")
                    .foregroundStyle(.secondary)
            } else {
                Text("暂无图片")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text("受管文件夹里没找到图片，或还在首次扫描")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DS.Spacing.xl)
    }
}

private struct SmartFolderImageCell: View {
    let image: IndexedImage
    @State private var thumbnail: NSImage?

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Group {
                if let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 140)
            .background(DS.Color.appBackground)
            .clipShape(RoundedRectangle(cornerRadius: DS.Thumbnail.cornerRadius))

            Text(image.filename)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .help(image.relativePath)
        .task(id: image.id) {
            await loadThumb()
        }
    }

    /// 解析 security-scoped bookmark → 复用 V1 ImageGridView 顶层 loadThumbnail。
    private func loadThumb() async {
        var stale = false
        guard let url = try? URL(
            resolvingBookmarkData: image.urlBookmark,
            options: [.withSecurityScope],
            bookmarkDataIsStale: &stale
        ) else { return }
        let didStart = url.startAccessingSecurityScopedResource()
        defer { if didStart { url.stopAccessingSecurityScopedResource() } }

        let thumb = await loadThumbnail(url: url, maxPixelSize: 280)
        await MainActor.run {
            self.thumbnail = thumb
        }
    }
}
