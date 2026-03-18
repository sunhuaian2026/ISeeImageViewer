//
//  ContentView.swift
//  ISeeImageViewer
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var folderStore: FolderStore

    var body: some View {
        NavigationSplitView {
            FolderSidebarView()
        } detail: {
            if let idx = folderStore.selectedImageIndex {
                ImageViewerView(
                    images: folderStore.images,
                    startIndex: idx,
                    onDismiss: { folderStore.selectedImageIndex = nil }
                )
            } else {
                ImageGridView()
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(FolderStore(bookmarkManager: BookmarkManager()))
}
