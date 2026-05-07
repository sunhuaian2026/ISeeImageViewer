//
//  SmartFolderListView.swift
//  Glance
//
//  Sidebar 智能文件夹区。M1 仅显示一个内置 SmartFolder「全部最近」；
//  M3+ 加用户自定义 SmartFolder 时此 view 自动展开（数据来自
//  SmartFolderStore.availableSmartFolders）。
//

import SwiftUI

struct SmartFolderListView: View {

    @EnvironmentObject var smartFolderStore: SmartFolderStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(smartFolderStore.availableSmartFolders) { folder in
                SmartFolderRow(
                    folder: folder,
                    isSelected: smartFolderStore.selected?.id == folder.id
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    Task { await smartFolderStore.select(folder) }
                }
            }
        }
    }
}

private struct SmartFolderRow: View {
    let folder: SmartFolder
    let isSelected: Bool

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            Text(folder.displayName)
                .font(.body)
                .foregroundStyle(isSelected ? Color.primary : Color.primary.opacity(0.85))
            Spacer()
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.xs)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
    }
}
