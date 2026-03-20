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
            .animation(DS.Animation.normal, value: showInspector)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        showInspector.toggle()
                    } label: {
                        Label("信息", systemImage: showInspector ? DS.Icon.infoFilled : DS.Icon.info)
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
                        withAnimation(DS.Animation.normal) {
                            folderStore.selectedImageIndex = nil
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.97).combined(with: .opacity),
                    removal:   .scale(scale: 0.97).combined(with: .opacity)
                ))
            } else {
                ImageGridView()
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(DS.Animation.normal, value: folderStore.selectedImageIndex)
    }
}

#Preview {
    ContentView()
        .environmentObject(FolderStore(bookmarkManager: BookmarkManager()))
}
