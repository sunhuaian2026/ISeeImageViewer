//
//  ContentView.swift
//  ISeeImageViewer
//

import SwiftUI
import SQLite3

// QV 入口来源：用 enum 而非裸 Bool/Optional 让 dismiss 路由按 provenance 走，不依赖
// selectedImageIndex 是否 nil 当哨兵 — 这样 QV 方向键写 selectedImageIndex 同步 grid
// highlight + preview 时不会反向破坏 6da903c 修过的"双击 cell 进 QV 后退出回 grid 不进 preview"
private enum QuickViewerEntry {
    case grid       // 路径 1: grid 双击 cell 直接进 QV
    case preview    // 路径 2: grid → preview → 双击 → QV
    case ephemeral  // 路径 3 (M2 Slice J): EphemeralResultView 双击 cell 进 QV → 退出直接回 baseGrid，不卡在 ephemeral 无焦点态
}

/// M2 Slice J — 临时结果视图请求。M2 仅支持 .similar；M3 加 .search。
/// banner 由 caller 计算（D14 部分库提示），nil = 不显示 banner。
private enum EphemeralRequest: Equatable {
    case similar(sourceUrl: URL, results: [URL], banner: String?)

    var title: String {
        switch self {
        case .similar(let url, _, _):
            return "类似于 \(url.lastPathComponent)"
        }
    }

    var urls: [URL] {
        switch self {
        case .similar(_, let r, _): return r
        }
    }

    var banner: String? {
        switch self {
        case .similar(_, _, let b): return b
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var folderStore: FolderStore
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var indexStoreHolder: IndexStoreHolder
    @StateObject private var smartFolderStore = SmartFolderStore.placeholder()
    @State private var indexBridge: FolderStoreIndexBridge?
    @State private var didWire: Bool = false
    /// V2 mode 下 preview / QuickViewer 的图片源（cell 单击/双击时从 queryResult 重建）。
    /// 不复用 folderStore.images，避免触发 .onChange(of: folderStore.images) 的保护性
    /// 关 QV 逻辑（那条 onChange 是给 V1 排序场景设计的）。
    @State private var v2Urls: [URL] = []
    /// M2 Slice J — 类似图查找结果视图状态。non-nil 时主区域换 EphemeralResultView 替代 baseGrid。
    @State private var currentEphemeral: EphemeralRequest?
    /// M2 Slice J — preview/QV 关闭后让 EphemeralResultView 重新拿焦点的 trigger。
    /// mirror previewFocusTrigger / gridFocusTrigger 模式。
    @State private var ephemeralFocusTrigger: UUID = UUID()
    @State private var showInspector = false
    @State private var quickViewerIndex: Int? = nil
    // QV 入口来源：onDoubleClick / onQuickView 设值，QV onDismiss 仲裁后清回 nil
    @State private var quickViewerEntry: QuickViewerEntry? = nil
    @State private var previewFocusTrigger: UUID = UUID()
    // QuickViewer / ImagePreviewView 关闭后让 grid 重新拿焦点的 trigger。变更通过
    // onChange(of: quickViewerIndex) 触发（覆盖 onDismiss 闭包 + onChange(of: images)
    // 强制关闭 两条路径），避免只挂 onDismiss 漏掉切换文件夹时关闭 QV 的场景
    @State private var gridFocusTrigger: UUID = UUID()
    // ImagePreviewView 上的 .id(idx) 会让它在每次方向键切换时整个重建；vm 提到 ContentView
    // 用 @StateObject 持有，跨重建保留 prefetchCache，方向键命中即时显示无 spinner
    @StateObject private var previewVM = ImagePreviewViewModel()

    private var inspectorURL: URL? {
        // mirror previewOverlay / QuickViewer .overlay 的 image source 选择：V2 mode 用
        // 本地 v2Urls，V1 mode 用 folderStore.images。前者是 commit 26c457a 拆出来的本地
        // @State，避免 V1 排序保护逻辑误关 V2 QV
        let images = smartFolderStore.selected != nil ? v2Urls : folderStore.images
        guard let idx = folderStore.selectedImageIndex,
              idx < images.count else { return nil }
        return images[idx]
    }

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 0) {
                SmartFolderListView()
                    .padding(.top, DS.Spacing.sm)
                    .padding(.horizontal, DS.Spacing.xs)

                Divider()
                    .padding(.vertical, DS.Spacing.xs)

                FolderSidebarView(
                    onToggleHide: { rootURL, nodeURL in
                        toggleHide(rootURL: rootURL, nodeURL: nodeURL)
                    },
                    isEffectivelyHidden: { rootURL, nodeURL in
                        effectivelyHidden(rootURL: rootURL, nodeURL: nodeURL)
                    },
                    isExplicitlyHidden: { rootURL, nodeURL in
                        explicitlyHidden(rootURL: rootURL, nodeURL: nodeURL)
                    }
                )
            }
            .navigationSplitViewColumnWidth(
                min: DS.Sidebar.minWidth,
                ideal: DS.Sidebar.width,
                max: DS.Sidebar.maxWidth
            )
            .environmentObject(smartFolderStore)
        } detail: {
            HStack(spacing: 0) {
                mainContent
                if showInspector {
                    // V1 已删独立 Divider（commit 086ade2 改用 Inspector 自带 leading overlay）
                    ImageInspectorView(
                        url: inspectorURL,
                        duplicatesProvider: { url in
                            guard let store = indexStoreHolder.store else { return [] }
                            return (try? store.fetchDuplicatesByFullPath(url.path)) ?? []
                        }
                    )
                        .frame(width: DS.Inspector.width)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .animation(DS.Anim.normal, value: showInspector)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        showInspector.toggle()
                    } label: {
                        Label("信息", systemImage: showInspector ? DS.Icon.infoFilled : DS.Icon.info)
                    }
                    .keyboardShortcut("i", modifiers: .command)
                    .disabled(folderStore.selectedImageIndex == nil)
                }
                ToolbarItem(placement: .automatic) {
                    Menu {
                        ForEach(AppearanceMode.allCases, id: \.self) { mode in
                            Button {
                                appState.appearanceMode = mode
                            } label: {
                                if appState.appearanceMode == mode {
                                    Label(mode.label, systemImage: "checkmark")
                                } else {
                                    Text(mode.label)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "circle.lefthalf.filled")
                    }
                }
            }
            .environmentObject(smartFolderStore)
        }
        // QuickViewerOverlay 用 .overlay 挂在 NavigationSplitView 上，确保铺满整个内容区
        .overlay {
            if let idx = quickViewerIndex {
                QuickViewerOverlay(
                    images: smartFolderStore.selected != nil ? v2Urls : folderStore.images,
                    startIndex: idx,
                    onDismiss: {
                        withAnimation(DS.Anim.normal) {
                            quickViewerIndex = nil
                        }
                        // 关闭后焦点路由迁移到 onChange(of: quickViewerIndex)，统一覆盖
                        // onDismiss + onChange(of: images) 强制关闭 两条路径
                    },
                    onIndexChange: { newIdx in
                        // QV 内 nav button / filmstrip / 方向键 任意路径切图都触发 viewModel.currentIndex 变 →
                        // QuickViewerOverlay 一处 onChange(of: viewModel.currentIndex) 上报这里
                        // → 写 selectedImageIndex → ImageGridView b44a175 onChange non-nil 分支自动同步 highlightedURL
                        // → ESC 退 QV 后 grid highlight (路径 1) / preview (路径 2) 都跟到 Z
                        folderStore.selectedImageIndex = newIdx
                    },
                    onFindSimilar: { sourceUrl in
                        handleFindSimilar(sourceUrl: sourceUrl)
                    },
                    currentSupportsFeaturePrint: currentSupportsFeaturePrint(at: idx)
                )
                .transition(.asymmetric(insertion: .identity, removal: .opacity))
            }
        }
        .animation(DS.Anim.normal, value: quickViewerIndex)
        // QuickViewer 关闭的真源出口：按 quickViewerEntry provenance 仲裁焦点路由，不依赖
        // selectedImageIndex 是否 nil 当哨兵 — 因为 QV 方向键已经在写 selectedImageIndex
        .onChange(of: quickViewerIndex) { oldValue, newValue in
            guard oldValue != nil, newValue == nil else { return }
            switch quickViewerEntry {
            case .grid:
                // 路径 1：双击 grid cell 进 QV → ESC 后回 grid（保 6da903c 行为）
                // QV 期间方向键写过的 selectedImageIndex 这里清回 nil 防止 preview 反弹
                // mount。highlightedURL 已在 QV 期间被 ImageGridView onChange 同步到 Z 不变
                folderStore.selectedImageIndex = nil
                gridFocusTrigger = UUID()
            case .preview:
                // 路径 2：preview 进 QV → ESC 退回 preview（selectedImageIndex 仍 = Z，
                // ImagePreviewView 通过 .id(idx) 重建显示 Z）
                previewFocusTrigger = UUID()
            case .ephemeral:
                // M2 Slice J 路径 3：EphemeralResultView 双击进 QV → ESC 退 QV 回 ephemeral
                // （而不是清 ephemeral 跳 baseGrid）。EphemeralResultView 已有键盘方向键 +
                // focusTrigger 焦点恢复机制，原"无焦点死状态"trade-off 不再必要。对齐
                // Photos.app / Finder Quick Look：QV → ESC 回上一层（ephemeral），再 ESC
                // 才回 baseGrid（走 ContentView 兜底状态机）。
                // QV 期间方向键写过的 selectedImageIndex 这里清回 nil 防止 previewOverlay
                // 反弹 mount（mirror case .grid 行为）— ephemeral 的 highlightedURL 已被
                // ephemeral.onChange(of: selectedImageIndex) non-nil 分支同步到 Z 不丢
                folderStore.selectedImageIndex = nil
                ephemeralFocusTrigger = UUID()
            case .none:
                // 路径 4（M2 Slice J）：handleFindSimilar 在 QV 内点找类似时主动清 entry，
                // QV 关闭走这里。currentEphemeral 已 set，刷 ephemeralFocusTrigger 拿焦
                // 否则保 grid 兜底行为
                if currentEphemeral != nil {
                    ephemeralFocusTrigger = UUID()
                } else {
                    gridFocusTrigger = UUID()
                }
            }
            quickViewerEntry = nil
        }
        .toolbar(quickViewerIndex != nil ? .hidden : .visible, for: .windowToolbar)
        // 隐藏 window toolbar 的 background material 绘制层，让 toolbar items（文件名 / ⓘ /
        // 外观切换）直接坐在 NSWindow title bar 上，避免 NavigationSplitView 默认 separated
        // 浅灰底色横条跟下方 ImagePreviewView 紫黑底色 (appBackground #121217) 断层。
        // 绘制层 ≠ NSWindow.toolbarStyle 布局层，AppKit 桥设 toolbarStyle 不生效（已验证）
        .toolbarBackground(.hidden, for: .windowToolbar)
        // 切换文件夹或取消图片选择时，自动关闭 Inspector
        .onChange(of: folderStore.selectedFolder) { _, _ in
            withAnimation(DS.Anim.normal) { showInspector = false }
            previewVM.clearCache()
        }
        .onChange(of: folderStore.selectedImageIndex) { _, newValue in
            if newValue == nil {
                withAnimation(DS.Anim.normal) { showInspector = false }
                previewVM.clearCache()
                // M2 Slice J 修复 Scenario 2：preview 关闭归 nil 时若 ephemeral 还显示
                // 且 QV 不在 → ephemeral 需要重新拿焦点（preview 抢焦后没机制还回去）
                // quickViewerIndex == nil 保护避开 ephemeral→QV 路径的 spurious fire
                if currentEphemeral != nil && quickViewerIndex == nil {
                    ephemeralFocusTrigger = UUID()
                }
            }
        }
        // 排序导致 images 数组变化时，关闭 QuickViewer 防止旧索引错位
        .onChange(of: folderStore.images) { _, _ in
            if quickViewerIndex != nil {
                quickViewerIndex = nil
            }
            previewVM.clearCache()
        }
        // V2 wire-up：IndexStore async ready 后挂载 engine + bridge + 默认选中"全部最近"
        .onAppear {
            Task { await wireIfReady() }
        }
        .onChange(of: indexStoreHolder.isReady) { _, ready in
            guard ready else { return }
            Task { await wireIfReady() }
        }
        // V2 受管文件夹增删 → bridge sync。bridge 内部 registerAndScan / unregister 末尾
        // 都跑 triggerDedupFullPass → onIndexChanged → refreshSelected，所以这里不再
        // 主动 refreshSelected，避免启动时 rootFolders 异步还原触发的"双 loading 闪屏"。
        .onChange(of: folderStore.rootFolders) { _, newRoots in
            guard let bridge = indexBridge else { return }
            Task { await bridge.sync(with: newRoots) }
        }
        // V2 selection 互斥：smart folder 选中 → 清 V1；反之亦然
        .onChange(of: folderStore.selectedFolder) { _, newFolder in
            if newFolder != nil && smartFolderStore.selected != nil {
                Task { await smartFolderStore.select(nil) }
            }
        }
        .onChange(of: smartFolderStore.selected) { _, newSF in
            if newSF != nil && folderStore.selectedFolder != nil {
                folderStore.selectedFolder = nil
                folderStore.images = []
                folderStore.selectedImageIndex = nil
            }
        }
        // M2 Slice J — 兜底 ESC 状态机（codex:rescue 确认根因：ZStack 同层多 @FocusState
        // race，preview/ephemeral 谁拿焦点不确定，依赖 view 自己的 onKeyPress 不可靠）。
        // 按 modal layer 顺序拨开：QV > preview > ephemeral > baseGrid。每次 ESC 只关一层。
        .onKeyPress(.escape) {
            if quickViewerIndex != nil {
                return .ignored  // QV 自己 onKeyPress 处理
            }
            if folderStore.selectedImageIndex != nil {
                // preview 是当前最顶层 modal → 先关 preview（不动 ephemeral）
                folderStore.selectedImageIndex = nil
                return .handled
            }
            if currentEphemeral != nil {
                // preview 已关 → 第二次 ESC 关 ephemeral
                withAnimation(DS.Anim.normal) { currentEphemeral = nil }
                return .handled
            }
            return .ignored
        }
        .background {
            WindowAccessor(appState: appState)
        }
    }

    // MARK: - Main Content

    /// 主区 = baseGrid（V1 ImageGridView 或 V2 SmartFolderGridView，互斥）+ previewOverlay
    /// （共享给两种 grid 模式，selectedImageIndex 非 nil 时 fade in）。
    /// V1 / V2 共享同一个 ImagePreviewView + folderStore.images 数组：
    /// - V1 模式：V1 selectFolder 把 folder 内图 URL 灌进 folderStore.images
    /// - V2 模式：cell 单击/双击时 populateImagesFromV2() 从 queryResult 重建 URL 灌进
    @ViewBuilder
    private var mainContent: some View {
        ZStack(alignment: .top) {
            if let req = currentEphemeral {
                EphemeralResultView(
                    title: req.title,
                    urls: req.urls,
                    bannerText: req.banner,
                    onClose: {
                        withAnimation(DS.Anim.normal) { currentEphemeral = nil }
                        // 修复 C：清 selectedImageIndex 防止 ephemeral 关闭后 preview 残留重现
                        folderStore.selectedImageIndex = nil
                    },
                    onSingleClick: { idx in
                        // 类似图结果单击 → 进 preview（v2Urls 路径，复用 V2 mode）；
                        // previewOverlay 现在挂在 ZStack 外层（修复 1），ephemeral 上方 fade in
                        v2Urls = req.urls
                        folderStore.selectedImageIndex = idx
                    },
                    onDoubleClick: { idx in
                        v2Urls = req.urls
                        folderStore.selectedImageIndex = nil
                        // 修复 2：用 .ephemeral provenance，QV 关闭时清 ephemeral 直接回 baseGrid
                        // （避免卡在「ephemeral 无焦点 + QV 已关」死状态）
                        quickViewerEntry = .ephemeral
                        quickViewerIndex = idx
                    },
                    focusTrigger: ephemeralFocusTrigger
                )
            } else {
                baseGrid
            }
            // previewOverlay 始终渲染（ephemeral 模式也用 → ephemeral 单击进 preview 才看得见）
            previewOverlay
            VStack(spacing: DS.Spacing.xs) {
                // Slice I.1 — 扫描进度 chip overlay（仅 V2 mode 扫描进行中显示，扫完自动消失）
                if let progress = indexStoreHolder.progress {
                    IndexingProgressView(progress: progress, onCancel: {
                        indexStoreHolder.cancelCurrentScan?()
                    })
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                // M2 Slice J — feature print 索引进度 chip（紫色调区分扫描 chip）
                if let fpProgress = indexStoreHolder.featurePrintProgress {
                    FeaturePrintProgressView(progress: fpProgress, onCancel: {
                        indexStoreHolder.cancelFeaturePrintIndexing?()
                    })
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                // Slice I.2 — 错误 banner（扫描失败 / dedup 失败 → holder.lastError 非 nil）
                if let err = indexStoreHolder.lastError {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(DS.Color.errorAccent)
                        Text(err)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .truncationMode(.tail)
                        Spacer(minLength: DS.Spacing.xs)
                        Button {
                            indexStoreHolder.lastError = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(DS.Color.secondaryText)
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.xs)
                    .background(.thickMaterial, in: Capsule())
                    .overlay(
                        Capsule().strokeBorder(
                            DS.Color.errorAccent.opacity(DS.IndexingProgress.errorBorderOpacity),
                            lineWidth: DS.SectionHeader.chipBorderWidth
                        )
                    )
                    .padding(.horizontal, DS.Spacing.md)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.top, DS.Spacing.sm)
        }
        .animation(DS.Anim.fast, value: indexStoreHolder.progress)
        .animation(DS.Anim.fast, value: indexStoreHolder.lastError)
        .animation(DS.Anim.fast, value: indexStoreHolder.featurePrintProgress)
    }

    @ViewBuilder
    private var baseGrid: some View {
        if smartFolderStore.selected != nil {
            SmartFolderGridView(
                onSingleClick: { idx in
                    v2Urls = computeV2Urls()
                    folderStore.selectedImageIndex = idx
                },
                onDoubleClick: { idx in
                    v2Urls = computeV2Urls()
                    // 双击时单击 handler 也会触发并设置 selectedImageIndex，此处清除，确保 QuickViewer
                    // 关闭后回到列表页而非预览页（同 V1 ImageGridView onDoubleClick 逻辑）
                    folderStore.selectedImageIndex = nil
                    quickViewerEntry = .grid
                    quickViewerIndex = idx
                },
                gridFocusTrigger: gridFocusTrigger
            )
        } else {
            // V1 ImageGridView 始终保留在层级里，避免返回时缩略图全部重载
            ImageGridView(
                gridFocusTrigger: gridFocusTrigger,
                onDoubleClick: { index in
                    folderStore.selectedImageIndex = nil
                    quickViewerEntry = .grid
                    quickViewerIndex = index
                }
            )
        }
    }

    @ViewBuilder
    private var previewOverlay: some View {
        // 收紧渲染条件：QV 期间 (quickViewerIndex != nil) 不渲染 ImagePreviewView，
        // 避免 QV 内方向键写 selectedImageIndex 时 .id(idx) 触发 preview 在后台重建/loadImage
        if let idx = folderStore.selectedImageIndex, quickViewerIndex == nil {
            ImagePreviewView(
                vm: previewVM,
                images: smartFolderStore.selected != nil ? v2Urls : folderStore.images,
                startIndex: idx,
                focusTrigger: previewFocusTrigger,
                onDismiss: {
                    folderStore.selectedImageIndex = nil
                },
                onQuickView: { index in
                    quickViewerEntry = .preview
                    quickViewerIndex = index
                }
            )
            .id(idx)
            .transition(.asymmetric(
                insertion: .scale(scale: 0.97).combined(with: .opacity),
                removal:   .scale(scale: 0.97).combined(with: .opacity)
            ))
        }
    }

    /// 把当前 SmartFolderStore.queryResult 转成 V1 风格的 URL 数组（snapshot 在 cell 单击/
    /// 双击时计算），让 ImagePreviewView / QuickViewerOverlay 两条 V1 通路复用。
    /// URL = resolve(image.urlBookmark = root bookmark) + appendingPathComponent(relative_path)。
    /// 子 URL 通过 V1 BookmarkManager 已 startAccessing 的 root scope 隐式访问，NSImage /
    /// CGImageSourceCreateWithURL 都能读。**返回数组而非写入 folderStore.images**，避免触发
    /// `.onChange(of: folderStore.images)` 的保护性 close-QV 逻辑（那条是给 V1 排序场景设的）。
    private func computeV2Urls() -> [URL] {
        smartFolderStore.queryResult.compactMap { image in
            var stale = false
            guard let rootURL = try? URL(
                resolvingBookmarkData: image.urlBookmark,
                options: [.withSecurityScope],
                bookmarkDataIsStale: &stale
            ) else { return nil }
            return rootURL.appendingPathComponent(image.relativePath)
        }
    }

    // MARK: - V2 Wire-up

    /// 幂等 wire-up：IndexStore ready 后初始化 engine + bridge + 默认选中"全部最近"。
    /// 同时被 .onAppear 和 .onChange(of: indexStoreHolder.isReady) 调，
    /// didWire flag 守卫防重入；任何一条到达都成功 — race 消除。
    private func wireIfReady() async {
        guard !didWire, let store = indexStoreHolder.store else { return }
        didWire = true

        let engine = SmartFolderEngine(store: store)
        smartFolderStore.attach(engine: engine)
        let bridge = FolderStoreIndexBridge(indexStore: store)
        // Slice G.2 — FSEvents 派发的索引更新（add/remove/modify）触发 grid 重 query
        let storeRef = smartFolderStore  // class 引用 capture 安全
        bridge.onIndexChanged = {
            Task { await storeRef.refreshSelected() }
        }
        // Slice I.1 — 扫描进度推到 IndexStoreHolder 让 ContentView overlay 显示
        let holderRef = indexStoreHolder
        bridge.onScanProgress = { progress in
            holderRef.progress = progress
        }
        // Slice I.2 — 扫描错误回调 → holder.lastError → ContentView banner
        bridge.onScanError = { msg in
            holderRef.lastError = msg
        }
        // Slice I.2 — holder.cancelCurrentScan 转发给 bridge（progress chip X 按钮点击时调）
        let bridgeRef = bridge
        holderRef.cancelCurrentScan = {
            bridgeRef.cancelCurrentScan()
        }
        indexBridge = bridge
        await bridge.sync(with: folderStore.rootFolders)

        if smartFolderStore.selected == nil {
            await smartFolderStore.select(BuiltInSmartFolders.allRecent)
        } else {
            await smartFolderStore.refreshSelected()
        }

        // M2 Slice J — feature print indexer 启动 + 回调挂载
        let indexer = FeaturePrintIndexer(store: store)
        let holderRef2 = indexStoreHolder  // shadow capture（指针不变 capture 安全）
        indexer.onProgress = { progress in
            holderRef2.featurePrintProgress = progress
        }
        indexer.onError = { msg in
            holderRef2.lastError = msg
        }
        holderRef2.featurePrintIndexer = indexer
        holderRef2.cancelFeaturePrintIndexing = { [weak indexer] in
            indexer?.cancel()
        }
        bridge.setFeaturePrintIndexer(indexer)
        indexer.start()
    }

    // MARK: - M2 Slice J — Similarity query

    /// M2 Slice J — 触发"找类似"：源 URL → IndexStore 反查 fp → SimilarityService 算 top-30
    /// → fetch URLs → 切 EphemeralResultView。
    /// D14：feature print 全库未抽完 → banner 提示已索引 X / Y。
    private func handleFindSimilar(sourceUrl: URL) {
        guard let store = indexStoreHolder.store else { return }
        let holderRef = indexStoreHolder
        Task {
            // 1. 反查源图 fp
            guard let (sourceId, sourceArchive) = try? store.fetchFeaturePrintByFullPath(sourceUrl.path) else {
                await MainActor.run {
                    holderRef.lastError = "「\(sourceUrl.lastPathComponent)」尚未索引或不支持类似图查找"
                }
                return
            }
            // 2. 反序列化源 observation
            guard let sourceObs = try? SimilarityService.unarchive(sourceArchive) else {
                await MainActor.run {
                    holderRef.lastError = "源图特征向量损坏，请稍后重试"
                }
                return
            }
            // 3. 拉所有候选 fp（D14: 部分库 ok）
            guard let candidates = try? store.fetchAllFeaturePrintsForCosine() else {
                await MainActor.run {
                    holderRef.lastError = "类似图查找数据库读取失败"
                }
                return
            }
            // 4. cosine top-30 (D13)
            let topN = SimilarityService.queryTopN(
                source: sourceObs,
                candidates: candidates,
                excludingId: sourceId,
                n: DS.Similarity.topNResults
            )
            let topIds = topN.map { $0.id }
            // 5. ids → URLs
            let urls = (try? store.fetchUrlsByIds(topIds)) ?? []

            // 6. D14 banner：检查 fp 索引覆盖率
            let banner = ContentView.computeBanner(
                store: store,
                indexedCount: candidates.count
            )

            await MainActor.run {
                self.currentEphemeral = .similar(sourceUrl: sourceUrl, results: urls, banner: banner)
                // 修复 2：清 selectedImageIndex 防止 QV 关闭后 previewOverlay 渲染条件成立，
                // preview 弹回压在 ephemeral 上方（Scenario 1 根因）
                self.folderStore.selectedImageIndex = nil
                // 修复 D：清 quickViewerEntry，让 QV close onChange 走 .none 分支不动 currentEphemeral
                // （否则若上一次 entry == .ephemeral，新设的 currentEphemeral 会被抹掉）
                self.quickViewerEntry = nil
                // 关闭 QV（让 ephemeral 视图占主区）
                self.quickViewerIndex = nil
            }
        }
    }

    /// 算 D14 部分库 banner 字符串。100% 覆盖 → nil；否则返回提示。
    private static func computeBanner(store: IndexStore, indexedCount: Int) -> String? {
        let total = (try? store.sync { db -> Int in
            let stmt = try db.prepare("SELECT COUNT(*) FROM images WHERE supports_feature_print = 1;")
            defer { sqlite3_finalize(stmt) }
            guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
            return Int(sqlite3_column_int(stmt, 0))
        }) ?? 0
        guard total > 0 else { return nil }
        if indexedCount >= total { return nil }
        return "已索引 \(indexedCount) / \(total) 张，结果为部分库"
    }

    /// M2 Slice J — 查 idx 处图片的 supports_feature_print。读不到（idx 越界 / 行不存在）→ true 默认（不主动 disable，让用户点了再失败提示）。
    private func currentSupportsFeaturePrint(at idx: Int) -> Bool {
        let images = smartFolderStore.selected != nil ? v2Urls : folderStore.images
        guard idx < images.count, let store = indexStoreHolder.store else { return true }
        let url = images[idx]
        return (try? store.sync { db -> Bool in
            let stmt = try db.prepare("""
                SELECT i.supports_feature_print FROM images i
                JOIN folders f ON i.folder_id = f.id
                WHERE f.root_path || '/' || i.relative_path = ? LIMIT 1;
            """)
            defer { sqlite3_finalize(stmt) }
            _ = sqlite3_bind_text(stmt, 1, (url.path as NSString).utf8String, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            guard sqlite3_step(stmt) == SQLITE_ROW else { return true }
            return sqlite3_column_int(stmt, 0) == 1
        }) ?? true
    }

    // MARK: - Slice D — hide toggle 路由（ContentView 拼桥：sidebar URL → IndexStore id+relativePath）

    /// 把 V1 (rootURL, nodeURL) 翻译成 IndexStore 的 (rootId, relativePath)。
    /// nodeURL == rootURL → root 节点，relativePath = ""；否则 nodeURL.path 去掉 rootURL.path 前缀。
    private func resolveFolderCoord(rootURL: URL, nodeURL: URL) -> (rootId: Int64, relativePath: String)? {
        guard let store = indexStoreHolder.store else { return nil }
        let rootPath = rootURL.standardizedFileURL.path
        let nodePath = nodeURL.standardizedFileURL.path
        guard let rootId = try? store.folderIdForRootPath(rootPath) else { return nil }

        if rootPath == nodePath {
            return (rootId, "")
        }
        let prefix = rootPath + "/"
        guard nodePath.hasPrefix(prefix) else { return nil }
        let relativePath = String(nodePath.dropFirst(prefix.count))
        return (rootId, relativePath)
    }

    private func toggleHide(rootURL: URL, nodeURL: URL) {
        guard let store = indexStoreHolder.store,
              let coord = resolveFolderCoord(rootURL: rootURL, nodeURL: nodeURL) else { return }
        let currentlyHidden = (try? store.effectiveHidden(rootId: coord.rootId, relativePath: coord.relativePath)) ?? false
        let target = !currentlyHidden
        do {
            if coord.relativePath.isEmpty {
                try store.setRootHidden(rootId: coord.rootId, hidden: target)
            } else {
                try store.upsertSubfolderHide(rootId: coord.rootId, relativePath: coord.relativePath, hidden: target)
            }
        } catch {
            print("[Slice D] toggleHide FAILED: \(error)")
            return
        }
        Task { await smartFolderStore.refreshSelected() }
    }

    private func effectivelyHidden(rootURL: URL, nodeURL: URL) -> Bool {
        guard let store = indexStoreHolder.store,
              let coord = resolveFolderCoord(rootURL: rootURL, nodeURL: nodeURL) else { return false }
        return (try? store.effectiveHidden(rootId: coord.rootId, relativePath: coord.relativePath)) ?? false
    }

    /// 仅当 row 自己显式 hide=1 才返 true（不含继承）。给 sidebar 决定显 eye.slash 图标。
    private func explicitlyHidden(rootURL: URL, nodeURL: URL) -> Bool {
        guard let store = indexStoreHolder.store,
              let coord = resolveFolderCoord(rootURL: rootURL, nodeURL: nodeURL) else { return false }
        return (try? store.isExplicitlyHidden(rootId: coord.rootId, relativePath: coord.relativePath)) ?? false
    }
}

#Preview {
    ContentView()
        .environmentObject(FolderStore(bookmarkManager: BookmarkManager()))
        .environmentObject(AppState())
        .environmentObject(IndexStoreHolder())
}
