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
                    Divider()
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
                        // 若关闭后仍在预览页，重新触发 ImagePreviewView 获取焦点
                        if folderStore.selectedImageIndex != nil {
                            previewFocusTrigger = UUID()
                        }
                    }
                )
                .transition(.opacity)
            }
        }
        .animation(DS.Anim.normal, value: quickViewerIndex)
        .toolbar(quickViewerIndex != nil ? .hidden : .visible, for: .windowToolbar)
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
            ImageGridView(onDoubleClick: { index in
                // 双击时单击 handler 也会触发并设置 selectedImageIndex，
                // 此处清除，确保 QuickViewer 关闭后回到列表页而非预览页。
                folderStore.selectedImageIndex = nil
                quickViewerIndex = index
            })

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
