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

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        let bm = BookmarkManager()
        _bookmarkManager = StateObject(wrappedValue: bm)
        _folderStore = StateObject(wrappedValue: FolderStore(bookmarkManager: bm))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(bookmarkManager)
                .environmentObject(folderStore)
                .environmentObject(appState)
                .preferredColorScheme(
                    appState.appearanceMode == .system ? nil :
                    appState.appearanceMode == .dark   ? .dark : .light
                )
                .onAppear {
                    folderStore.loadSavedFolders()
                }
        }
        .defaultSize(width: 1280, height: 800)
        .commands {
            // 替换标准"关于"菜单：弹自定义 AboutView 支持点击复制
            CommandGroup(replacing: .appInfo) {
                AboutMenuButton()
            }
        }

        Window("关于一眼", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)
    }
}

private struct AboutMenuButton: View {
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Button("关于一眼") {
            openWindow(id: "about")
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
