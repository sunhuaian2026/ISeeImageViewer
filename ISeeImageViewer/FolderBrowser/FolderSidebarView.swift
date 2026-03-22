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
                folderStore.rootFolders,
                children: \.children,
                selection: Binding<URL?>(
                    get: { folderStore.selectedFolder },
                    set: { url in
                        if let url { folderStore.selectFolder(url) }
                    }
                )
            ) { node in
                folderRow(node)
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

    // MARK: - 行视图

    @ViewBuilder
    private func folderRow(_ node: FolderNode) -> some View {
        let isRoot = folderStore.rootFolders.contains(where: { $0.url == node.url })
        let count = folderStore.imageCountByFolder[node.url]

        HStack {
            Label(node.url.lastPathComponent, systemImage: "folder")
            Spacer()
            if let count, count > 0 {
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
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: node.url.path)
            }
            if isRoot {
                Divider()
                Button("移除文件夹", role: .destructive) {
                    folderStore.removeFolder(node.url)
                }
            }
        }
    }
}
