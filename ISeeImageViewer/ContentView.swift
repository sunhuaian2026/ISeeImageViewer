//
//  ContentView.swift
//  ISeeImageViewer
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var folderStore: FolderStore
    @State private var showInspector = false

    private var currentImageURL: URL? {
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
                    InspectorPlaceholderView(url: currentImageURL)
                        .frame(width: 260)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .animation(.spring(duration: 0.25), value: showInspector)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        showInspector.toggle()
                    } label: {
                        Label("信息", systemImage: showInspector ? "info.circle.fill" : "info.circle")
                    }
                    .keyboardShortcut("i", modifiers: .command)
                }
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        Group {
            if let idx = folderStore.selectedImageIndex {
                ImageViewerView(
                    images: folderStore.images,
                    startIndex: idx,
                    onDismiss: {
                        withAnimation(.spring(duration: 0.3)) {
                            folderStore.selectedImageIndex = nil
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.96).combined(with: .opacity),
                    removal: .scale(scale: 0.96).combined(with: .opacity)
                ))
            } else {
                ImageGridView()
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(duration: 0.3), value: folderStore.selectedImageIndex)
    }
}

#Preview {
    ContentView()
        .environmentObject(FolderStore(bookmarkManager: BookmarkManager()))
}
