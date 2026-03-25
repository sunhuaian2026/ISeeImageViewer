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
        }
        .onChange(of: folderStore.selectedImageIndex) { _, newValue in
            if newValue == nil {
                withAnimation(DS.Anim.normal) { showInspector = false }
            }
        }
        .background {
            WindowAccessor(appState: appState)
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        if let idx = folderStore.selectedImageIndex {
            ImagePreviewView(
                images: folderStore.images,
                startIndex: idx,
                onDismiss: {
                    folderStore.selectedImageIndex = nil
                },
                onQuickView: { index in
                    quickViewerIndex = index
                }
            )
            .transition(.asymmetric(
                insertion: .scale(scale: 0.97).combined(with: .opacity),
                removal:   .scale(scale: 0.97).combined(with: .opacity)
            ))
        } else {
            ImageGridView(onDoubleClick: { index in
                // 双击时单击 handler 也会触发并设置 selectedImageIndex，
                // 此处清除，确保 QuickViewer 关闭后回到列表页而非预览页。
                folderStore.selectedImageIndex = nil
                quickViewerIndex = index
            })
            .transition(.opacity)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(FolderStore(bookmarkManager: BookmarkManager()))
        .environmentObject(AppState())
}
