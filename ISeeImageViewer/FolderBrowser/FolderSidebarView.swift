//
//  FolderSidebarView.swift
//  ISeeImageViewer
//

import SwiftUI

struct FolderSidebarView: View {
    @EnvironmentObject var folderStore: FolderStore

    var body: some View {
        List(
            folderStore.folders,
            id: \.self,
            selection: Binding<URL?>(
                get: { folderStore.selectedFolder },
                set: { url in
                    if let url { folderStore.selectFolder(url) }
                }
            )
        ) { url in
            Label(url.lastPathComponent, systemImage: "folder")
                .contextMenu {
                    Button("移除文件夹", role: .destructive) {
                        folderStore.removeFolder(url)
                    }
                }
        }
        .toolbar {
            ToolbarItem {
                Button {
                    folderStore.addFolder()
                } label: {
                    Label("添加文件夹", systemImage: "plus")
                }
            }
        }
        .navigationTitle("文件夹")
    }
}
