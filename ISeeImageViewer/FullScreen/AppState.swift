//
//  AppState.swift
//  ISeeImageViewer
//

import AppKit
import Combine

class AppState: ObservableObject {
    @Published var isFullScreen = false
    weak var window: NSWindow?

    func toggleFullScreen() {
        window?.toggleFullScreen(nil)
    }

    func exitFullScreenIfNeeded() {
        guard isFullScreen else { return }
        window?.toggleFullScreen(nil)
    }
}
