//
//  SmartFolderGridView.swift
//  Glance
//
//  跨文件夹 grid。显示 SmartFolderStore.queryResult 的图，复用 V1 顶层
//  loadThumbnail(url:maxPixelSize:) 函数（位于 ImageGridView.swift）。
//
//  Slice A 行为对齐 V1 ImageGridView：单击进 preview / 双击进 QuickViewer /
//  方向键 grid 内导航 / Space 进 QV / F 切全屏 / focus 同步管理 / hover tooltip 显示
//  relative path（D5）。
//

import SwiftUI

struct SmartFolderGridView: View {

    @EnvironmentObject var smartFolderStore: SmartFolderStore
    @EnvironmentObject var folderStore: FolderStore
    @EnvironmentObject var appState: AppState

    /// 单击 cell 回调（参数：被点 cell 在 queryResult 中的当前位置 index）。
    /// 实时 firstIndex 查找避免 LazyVGrid 复用 cell 时闭包捕获 index 过期（参考 V1 c112059 修法）。
    let onSingleClick: (Int) -> Void
    /// 双击 cell 回调（同 onSingleClick 的 index 语义）。
    let onDoubleClick: (Int) -> Void
    /// QuickViewer / preview 关闭后 ContentView 通过 trigger 拉 grid 焦点回来。
    let gridFocusTrigger: UUID

    /// V2 grid 内 cell 高亮状态（mirror V1 ImageGridView.highlightedURL）。
    /// 同步规则：cell 单击 / 双击设当前 cell；preview 方向键 navigate 写
    /// folderStore.selectedImageIndex → 这里 onChange 同步到 queryResult[idx].id；
    /// queryResult 整体变化（重新 query）→ reset nil。
    @State private var highlightedID: Int64?
    @FocusState private var isFocused: Bool

    var body: some View {
        GeometryReader { geo in
            // colCount 用 grid 实际可用宽度算（geo.size.width 反映 mainContent 区，
            // 不含 sidebar / inspector），上下方向键步长才与 LazyVGrid 实际列数一致
            let colCount = computeColumnCount(width: geo.size.width)

            ScrollViewReader { scrollProxy in
                ScrollView {
                    if smartFolderStore.queryResult.isEmpty {
                        emptyState
                    } else {
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: cellMinWidth, maximum: cellMaxWidth), spacing: DS.Spacing.sm)],
                            spacing: DS.Spacing.sm
                        ) {
                            ForEach(smartFolderStore.queryResult) { image in
                                SmartFolderImageCell(image: image, isHighlighted: highlightedID == image.id)
                                    .id(image.id)
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
                .focusable()
                .focusEffectDisabled()
                .focused($isFocused)
                .onAppear { isFocused = true }
                .navigationTitle({
                    // mirror V1 ImageGridView 行为：preview 模式（selectedImageIndex 非 nil）显示 filename，
                    // grid 模式显示 SmartFolder displayName
                    if let idx = folderStore.selectedImageIndex,
                       smartFolderStore.queryResult.indices.contains(idx) {
                        return smartFolderStore.queryResult[idx].filename
                    }
                    return smartFolderStore.selected?.displayName ?? ""
                }())
                // preview 方向键 navigate 时 selectedImageIndex 变 → 同步 highlight 跟到当前预览图；
                // preview/QV 关闭（→ nil）时拉回 grid 焦点（mirror V1 ImageGridView Y-1/Y-2 race 修法）
                .onChange(of: folderStore.selectedImageIndex) { _, newValue in
                    if let idx = newValue, smartFolderStore.queryResult.indices.contains(idx) {
                        highlightedID = smartFolderStore.queryResult[idx].id
                    } else if newValue == nil {
                        isFocused = true
                    }
                }
                // ContentView 在 QuickViewer / preview 关闭后通过 gridFocusTrigger 拉回焦点
                .onChange(of: gridFocusTrigger) { _, _ in isFocused = true }
                // queryResult 整体重新 query → 老 highlight 已无意义，reset
                .onChange(of: smartFolderStore.queryResult) { _, _ in
                    highlightedID = nil
                }
                // Space：进入全窗口查看器（用当前 highlight 或第一张）
                .onKeyPress(.space) {
                    guard !smartFolderStore.queryResult.isEmpty else { return .ignored }
                    let target = smartFolderStore.queryResult.firstIndex(where: { $0.id == highlightedID }) ?? 0
                    onDoubleClick(target)
                    return .handled
                }
                // F：切换全屏（跟 QuickViewer / preview 一致，spec AppState.md 全局 F 键设计）
                .onKeyPress(.init("f"), phases: .down) { _ in
                    appState.toggleFullScreen()
                    return .handled
                }
                // 方向键导航
                .onKeyPress(.leftArrow)  { moveHighlight(by: -1,        colCount: colCount, proxy: scrollProxy); return .handled }
                .onKeyPress(.rightArrow) { moveHighlight(by: +1,        colCount: colCount, proxy: scrollProxy); return .handled }
                .onKeyPress(.upArrow)    { moveHighlight(by: -colCount, colCount: colCount, proxy: scrollProxy); return .handled }
                .onKeyPress(.downArrow)  { moveHighlight(by: +colCount, colCount: colCount, proxy: scrollProxy); return .handled }
            }
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

    // MARK: - Helpers

    private func moveHighlight(by delta: Int, colCount: Int, proxy: ScrollViewProxy) {
        let total = smartFolderStore.queryResult.count
        guard total > 0 else { return }
        let current = smartFolderStore.queryResult.firstIndex(where: { $0.id == highlightedID })
            ?? (delta > 0 ? -1 : 0)
        let next = max(0, min(total - 1, current + delta))
        let nextImage = smartFolderStore.queryResult[next]
        highlightedID = nextImage.id
        withAnimation(DS.Anim.fast) {
            proxy.scrollTo(nextImage.id, anchor: .center)
        }
    }

    /// V2 grid LazyVGrid 列数估算：mirror V1 SwiftUI .adaptive(minimum:) 算法，
    /// floor((W + spacing) / (cellMin + spacing))。padding(DS.Spacing.md) 两侧。
    private func computeColumnCount(width: CGFloat) -> Int {
        let gridWidth = width - 2 * DS.Spacing.md
        return max(1, Int((gridWidth + DS.Spacing.sm) / (cellMinWidth + DS.Spacing.sm)))
    }

    private let cellMinWidth: CGFloat = 140
    private let cellMaxWidth: CGFloat = 200
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
