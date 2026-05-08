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
    @EnvironmentObject var folderStore: FolderStore

    /// 单击 cell 回调（参数：被点 cell 在 queryResult 中的当前位置 index）。
    /// 实时 firstIndex 查找避免 LazyVGrid 复用 cell 时闭包捕获 index 过期（参考 V1 c112059 修法）。
    let onSingleClick: (Int) -> Void
    /// 双击 cell 回调（同 onSingleClick 的 index 语义）。
    let onDoubleClick: (Int) -> Void

    /// V2 grid 内 cell 高亮状态（mirror V1 ImageGridView.highlightedURL）。
    /// 同步规则：cell 单击 / 双击设当前 cell；preview 方向键 navigate 写
    /// folderStore.selectedImageIndex → 这里 onChange 同步到 queryResult[idx].id；
    /// queryResult 整体变化（重新 query）→ reset nil。
    @State private var highlightedID: Int64?

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
                        SmartFolderImageCell(image: image, isHighlighted: highlightedID == image.id)
                            .contentShape(Rectangle())
                            // 双击优先注册（macOS SwiftUI 双 onTapGesture pattern；count:1 在 count:2 之后注册可让
                            // tap recognizer 优先识别双击不触发单击）。参考 V1 ImageGridView 同模式。
                            .onTapGesture(count: 2) {
                                if let idx = smartFolderStore.queryResult.firstIndex(where: { $0.id == image.id }) {
                                    highlightedID = image.id
                                    onDoubleClick(idx)
                                }
                            }
                            .onTapGesture(count: 1) {
                                if let idx = smartFolderStore.queryResult.firstIndex(where: { $0.id == image.id }) {
                                    highlightedID = image.id
                                    onSingleClick(idx)
                                }
                            }
                    }
                }
                .padding(DS.Spacing.md)
            }
        }
        .background(DS.Color.gridBackground)
        .navigationTitle({
            // mirror V1 ImageGridView 行为：preview 模式（selectedImageIndex 非 nil）显示 filename，
            // grid 模式显示 SmartFolder displayName
            if let idx = folderStore.selectedImageIndex,
               smartFolderStore.queryResult.indices.contains(idx) {
                return smartFolderStore.queryResult[idx].filename
            }
            return smartFolderStore.selected?.displayName ?? ""
        }())
        // preview 方向键 navigate 时 selectedImageIndex 变 → 同步 highlight 跟到当前预览图
        // → ESC 退回 grid 时 highlight 落在浏览到的最后一张
        .onChange(of: folderStore.selectedImageIndex) { _, newValue in
            if let idx = newValue, smartFolderStore.queryResult.indices.contains(idx) {
                highlightedID = smartFolderStore.queryResult[idx].id
            }
        }
        // queryResult 整体重新 query → 老 highlight 已无意义，reset
        .onChange(of: smartFolderStore.queryResult) { _, _ in
            highlightedID = nil
        }
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
    var isHighlighted: Bool = false
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
            // mirror V1 ThumbnailCell isHighlighted 视觉：accent 半透明填充 + 2pt accent stroke
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
            .animation(DS.Anim.fast, value: isHighlighted)

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

    /// 解析 root bookmark → startAccessing → 拼 root + relative_path 得到 child URL → 读缩略图。
    /// (image.urlBookmark 实际是 root bookmark，不是 image 自己的 bookmark；macOS sandbox
    /// 不允许给 enumerator 出来的子文件创建 .withSecurityScope bookmark，所以子访问只能
    /// 通过 root active scope 隐式走。Slice I 重构候选：rename field / 改为 folder_id lookup。)
    private func loadThumb() async {
        var stale = false
        guard let rootURL = try? URL(
            resolvingBookmarkData: image.urlBookmark,
            options: [.withSecurityScope],
            bookmarkDataIsStale: &stale
        ) else { return }
        let didStart = rootURL.startAccessingSecurityScopedResource()
        defer { if didStart { rootURL.stopAccessingSecurityScopedResource() } }

        // root + relative_path → child file URL，通过 root active scope 隐式访问
        let fileURL = rootURL.appendingPathComponent(image.relativePath)
        let thumb = await loadThumbnail(url: fileURL, maxPixelSize: 280)
        await MainActor.run {
            self.thumbnail = thumb
        }
    }
}
