//
//  FolderSidebarView.swift
//  ISeeImageViewer
//

import SwiftUI

struct FolderSidebarView: View {
    @EnvironmentObject var folderStore: FolderStore

    var body: some View {
        ZStack(alignment: .topLeading) {
            // 紫色环境光光晕
            RadialGradient(
                colors: [DS.Color.glowPrimary.opacity(0.18), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 300
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

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
            HStack {
                Label(url.lastPathComponent, systemImage: "folder")
                Spacer()
                if let count = folderStore.imageCountByFolder[url] {
                    Text("\(count)")
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.ultraThinMaterial, in: Capsule())
                }
            }
            .contextMenu {
                    Button("在 Finder 中显示") {
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
                    }
                    Divider()
                    Button("移除文件夹", role: .destructive) {
                        folderStore.removeFolder(url)
                    }
                }
        }
        .listStyle(.sidebar)
        .background(.ultraThinMaterial)
        .environment(\.colorScheme, .dark)
        .contextMenu {
            Button("添加文件夹…") { folderStore.addFolder() }
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
        } // ZStack
    }
}
