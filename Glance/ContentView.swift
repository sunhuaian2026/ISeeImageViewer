//
//  ContentView.swift
//  ISeeImageViewer
//

import SwiftUI

// QV 入口来源：用 enum 而非裸 Bool/Optional 让 dismiss 路由按 provenance 走，不依赖
// selectedImageIndex 是否 nil 当哨兵 — 这样 QV 方向键写 selectedImageIndex 同步 grid
// highlight + preview 时不会反向破坏 6da903c 修过的"双击 cell 进 QV 后退出回 grid 不进 preview"
private enum QuickViewerEntry {
    case grid     // 路径 1: grid 双击 cell 直接进 QV
    case preview  // 路径 2: grid → preview → 双击 → QV
}

struct ContentView: View {
    @EnvironmentObject var folderStore: FolderStore
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var indexStoreHolder: IndexStoreHolder
    @StateObject private var smartFolderStore = SmartFolderStore.placeholder()
    @State private var indexBridge: FolderStoreIndexBridge?
    @State private var didWire: Bool = false
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
        guard let idx = folderStore.selectedImageIndex,
              idx < folderStore.images.count else { return nil }
        return folderStore.images[idx]
    }

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 0) {
                SmartFolderListView()
                    .padding(.top, DS.Spacing.sm)
                    .padding(.horizontal, DS.Spacing.xs)

                Divider()
                    .padding(.vertical, DS.Spacing.xs)

                FolderSidebarView()
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
                    ImageInspectorView(url: inspectorURL)
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
                    images: folderStore.images,
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
                    }
                )
                .transition(.opacity)
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
            case .none:
                // 兜底：理论不应到这分支（onDoubleClick/onQuickView 总会设 entry）
                gridFocusTrigger = UUID()
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
        // V2 受管文件夹增删 → bridge sync + 当前 SF 重 query
        .onChange(of: folderStore.rootFolders) { _, newRoots in
            guard let bridge = indexBridge else { return }
            Task {
                await bridge.sync(with: newRoots)
                await smartFolderStore.refreshSelected()
            }
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
        .background {
            WindowAccessor(appState: appState)
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        if smartFolderStore.selected != nil {
            SmartFolderGridView()
        } else {
            v1MainContent
        }
    }

    @ViewBuilder
    private var v1MainContent: some View {
        ZStack {
            // ImageGridView 始终保留在层级里，避免返回时缩略图全部重载
            ImageGridView(
                gridFocusTrigger: gridFocusTrigger,
                onDoubleClick: { index in
                    // 双击时单击 handler 也会触发并设置 selectedImageIndex，
                    // 此处清除，确保 QuickViewer 关闭后回到列表页而非预览页。
                    folderStore.selectedImageIndex = nil
                    quickViewerEntry = .grid
                    quickViewerIndex = index
                }
            )

            // 收紧渲染条件：QV 期间 (quickViewerIndex != nil) 不渲染 ImagePreviewView，
            // 避免 QV 内方向键写 selectedImageIndex 时 .id(idx) 触发 preview 在后台重建/loadImage。
            // codex 标的盲点：.id(idx) 让 preview 在 selectedImageIndex 变化时整体重建（不只是 onChange）
            if let idx = folderStore.selectedImageIndex, quickViewerIndex == nil {
                ImagePreviewView(
                    vm: previewVM,
                    images: folderStore.images,
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
        indexBridge = FolderStoreIndexBridge(indexStore: store)
        await indexBridge?.sync(with: folderStore.rootFolders)

        if smartFolderStore.selected == nil {
            await smartFolderStore.select(BuiltInSmartFolders.allRecent)
        } else {
            await smartFolderStore.refreshSelected()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(FolderStore(bookmarkManager: BookmarkManager()))
        .environmentObject(AppState())
        .environmentObject(IndexStoreHolder())
}
