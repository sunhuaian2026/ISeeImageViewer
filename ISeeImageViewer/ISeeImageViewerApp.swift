//
//  ISeeImageViewerApp.swift
//  ISeeImageViewer
//
//  Created by 孙红军 on 2026/3/16.
//

import SwiftUI

@main
struct ISeeImageViewerApp: App {
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
