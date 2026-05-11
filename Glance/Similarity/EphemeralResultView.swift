//
//  EphemeralResultView.swift
//  Glance
//
//  M2 Slice J — 临时结果视图（找类似 / M3 搜索共用骨架）。layout = topBar（关闭+title+banner）
//  + LazyVGrid（复用 ImageGridView ThumbnailCell pattern）。不持久化（关闭即销毁状态）。
//
//  与 SmartFolderGridView 区别：
//  - 不依赖 SmartFolder（M3 搜索结果不是 SF）
//  - 不做时间分段（top-N 是排序结果，不是时间序列）
//  - 单击/双击行为复用 V1 mode（onSingleClick → preview / onDoubleClick → QV，调用方接）
//
//  D14 banner：caller 计算"已索引 X / Y 张"提示，nil 时不渲染 banner row。
//

import SwiftUI

struct EphemeralResultView: View {
    let title: String
    let urls: [URL]
    let bannerText: String?
    let onClose: () -> Void
    let onSingleClick: (Int) -> Void
    let onDoubleClick: (Int) -> Void

    @EnvironmentObject var folderStore: FolderStore

    @FocusState private var isFocused: Bool
    @State private var highlightedURL: URL?

    private var gridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: folderStore.thumbnailSize), spacing: DS.Thumbnail.spacing)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.zero) {
            topBar
            if let bannerText {
                bannerRow(text: bannerText)
            }
            ScrollView {
                if urls.isEmpty {
                    emptyState
                } else {
                    LazyVGrid(columns: gridColumns, spacing: DS.Thumbnail.spacing) {
                        ForEach(Array(urls.enumerated()), id: \.element) { idx, url in
                            VStack(spacing: DS.Spacing.xs) {
                                ThumbnailCell(
                                    url: url,
                                    isHighlighted: highlightedURL == url,
                                    size: folderStore.thumbnailSize
                                )
                                Text(url.lastPathComponent)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .frame(maxWidth: folderStore.thumbnailSize)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) {
                                highlightedURL = url
                                onDoubleClick(idx)
                            }
                            .onTapGesture(count: 1) {
                                highlightedURL = url
                                onSingleClick(idx)
                            }
                        }
                    }
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                }
            }
        }
        .background(DS.Color.appBackground)
        .focusable()
        .focusEffectDisabled()
        .focused($isFocused)
        .onAppear { isFocused = true }
        .onKeyPress(.escape) {
            onClose()
            return .handled
        }
    }

    private var topBar: some View {
        HStack(spacing: DS.Spacing.sm) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(width: DS.Similarity.closeButtonSize, height: DS.Similarity.closeButtonSize)
                    .background(DS.Similarity.neutralOverlay.opacity(DS.Similarity.closeButtonBgOpacity), in: Circle())
            }
            .buttonStyle(.plain)
            .help("返回 (ESC)")

            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Text("\(urls.count) 张")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .background(.thinMaterial)
    }

    private func bannerRow(text: String) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.secondary)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Spacer()
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.xs)
        .background(DS.Similarity.neutralOverlay.opacity(DS.Similarity.bannerBgOpacity))
    }

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: "square.stack.3d.up.slash")
                .font(.system(size: DS.Similarity.emptyStateIconSize))
                .foregroundStyle(.tertiary)
            Text("无结果")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, DS.Similarity.emptyStateTopPadding)
    }
}
