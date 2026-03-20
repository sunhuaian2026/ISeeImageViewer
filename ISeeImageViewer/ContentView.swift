//
//  ContentView.swift
//  ISeeImageViewer
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var folderStore: FolderStore
    @EnvironmentObject var appState: AppState
    @State private var showInspector = false

    private var currentImageURL: URL? {
        guard let idx = folderStore.selectedImageIndex,
              idx < folderStore.images.count else { return nil }
        return folderStore.images[idx]
    }

    var body: some View {
        ZStack {
            WindowAccessor(appState: appState)
                .frame(width: 0, height: 0)

            NavigationSplitView {
                FolderSidebarView()
            } detail: {
                HStack(spacing: 0) {
                    ImageGridView()
                    if showInspector {
                        Divider()
                        ImageInspectorView(url: currentImageURL)
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

            if let idx = folderStore.selectedImageIndex {
                QuickViewerOverlay(
                    images: folderStore.images,
                    startIndex: idx,
                    onDismiss: {
                        withAnimation(DS.Animation.normal) {
                            folderStore.selectedImageIndex = nil
                        }
                    }
                )
                .transition(.opacity)
                .animation(DS.Animation.normal, value: folderStore.selectedImageIndex)
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(FolderStore(bookmarkManager: BookmarkManager()))
}
