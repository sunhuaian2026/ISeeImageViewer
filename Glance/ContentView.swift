//
//  ContentView.swift
//  ISeeImageViewer
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var folderStore: FolderStore
    @EnvironmentObject var appState: AppState
    @State private var showInspector = false
    @State private var quickViewerIndex: Int? = nil
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
            FolderSidebarView()
        } detail: {
            HStack(spacing: 0) {
                mainContent
                if showInspector {
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
                    }
                )
                .transition(.opacity)
            }
        }
        .animation(DS.Anim.normal, value: quickViewerIndex)
        // QuickViewer 关闭的真源出口：根据 selectedImageIndex 仲裁焦点回 grid 还是 preview
        .onChange(of: quickViewerIndex) { oldValue, newValue in
            guard oldValue != nil, newValue == nil else { return }
            if folderStore.selectedImageIndex != nil {
                previewFocusTrigger = UUID()
            } else {
                gridFocusTrigger = UUID()
            }
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
        .background {
            WindowAccessor(appState: appState)
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        ZStack {
            // ImageGridView 始终保留在层级里，避免返回时缩略图全部重载
            ImageGridView(
                gridFocusTrigger: gridFocusTrigger,
                onDoubleClick: { index in
                    // 双击时单击 handler 也会触发并设置 selectedImageIndex，
                    // 此处清除，确保 QuickViewer 关闭后回到列表页而非预览页。
                    folderStore.selectedImageIndex = nil
                    quickViewerIndex = index
                }
            )

            if let idx = folderStore.selectedImageIndex {
                ImagePreviewView(
                    vm: previewVM,
                    images: folderStore.images,
                    startIndex: idx,
                    focusTrigger: previewFocusTrigger,
                    onDismiss: {
                        folderStore.selectedImageIndex = nil
                    },
                    onQuickView: { index in
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
}

#Preview {
    ContentView()
        .environmentObject(FolderStore(bookmarkManager: BookmarkManager()))
        .environmentObject(AppState())
}
