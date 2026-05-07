//
//  GlanceApp.swift
//  Glance
//
//  Created by 孙红军 on 2026/3/16.
//

import SwiftUI

@main
struct GlanceApp: App {
    @StateObject private var bookmarkManager: BookmarkManager
    @StateObject private var folderStore: FolderStore
    @StateObject private var appState = AppState()
    @StateObject private var indexStoreHolder: IndexStoreHolder

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        let bm = BookmarkManager()
        _bookmarkManager = StateObject(wrappedValue: bm)
        _folderStore = StateObject(wrappedValue: FolderStore(bookmarkManager: bm))
        _indexStoreHolder = StateObject(wrappedValue: IndexStoreHolder())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(bookmarkManager)
                .environmentObject(folderStore)
                .environmentObject(appState)
                .environmentObject(indexStoreHolder)
                .onAppear {
                    folderStore.loadSavedFolders()
                }
        }
        .defaultSize(width: 1280, height: 800)
        .commands {
            // 替换标准"关于"菜单：弹自定义 AboutView 支持点击复制
            // 通过 AboutWindowController（纯 AppKit）显示，避免 SwiftUI Window scene
            // 无法在显示前定位导致的 A→B 跳跃问题
            CommandGroup(replacing: .appInfo) {
                AboutMenuButton()
            }
        }
    }
}

private struct AboutMenuButton: View {
    var body: some View {
        Button("关于一眼") {
            AboutWindowController.shared.show()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var accessedURLs: [URL] = []

    func applicationWillTerminate(_ notification: Notification) {
        for url in accessedURLs {
            url.stopAccessingSecurityScopedResource()
        }
    }
}
