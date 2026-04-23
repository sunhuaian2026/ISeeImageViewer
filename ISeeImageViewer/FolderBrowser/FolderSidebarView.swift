//
//  FolderSidebarView.swift
//  ISeeImageViewer
//

import SwiftUI

struct FolderSidebarView: View {
    @EnvironmentObject var folderStore: FolderStore
    @State private var isDropTargeted: Bool = false

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
            .scrollContentBackground(.hidden)
            .background(DS.Color.appBackground)
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
        // Finder 拖拽入口：整个 sidebar 接 URL，filter 目录后走 FolderStore 批量入口
        .dropDestination(for: URL.self) { urls, _ in
            folderStore.addFolders(from: urls)
            return true
        } isTargeted: { hovering in
            withAnimation(DS.Anim.fast) { isDropTargeted = hovering }
        }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: DS.Sidebar.dropBorderCornerRadius)
                    .strokeBorder(
                        DS.Color.glowPrimary.opacity(DS.Sidebar.dropBorderOpacity),
                        lineWidth: DS.Sidebar.dropBorderWidth
                    )
                    .padding(DS.Sidebar.dropBorderPadding)
                    .allowsHitTesting(false)
            }
        }
    }

    // MARK: - 行视图

    @ViewBuilder
    private func folderRow(_ node: FolderNode) -> some View {
        let isRoot = folderStore.rootFolders.contains(where: { $0.url == node.url })
        let count = folderStore.imageCountByFolder[node.url]
        let isSelected = folderStore.selectedFolder == node.url

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
        .listRowBackground(Group {
            if isSelected {
                Color.clear
            } else {
                DS.Color.appBackground
            }
        })
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
