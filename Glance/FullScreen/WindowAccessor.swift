//
//  WindowAccessor.swift
//  Glance
//

import SwiftUI
import AppKit

struct WindowAccessor: NSViewRepresentable {
    let appState: AppState

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            appState.window = window
            window.delegate = context.coordinator
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                appState.window = window
                if window.delegate == nil {
                    window.delegate = context.coordinator
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(appState: appState)
    }

    class Coordinator: NSObject, NSWindowDelegate {
        let appState: AppState

        init(appState: AppState) {
            self.appState = appState
        }

        func windowDidEnterFullScreen(_ notification: Notification) {
            appState.isFullScreen = true
        }

        func windowDidExitFullScreen(_ notification: Notification) {
            appState.isFullScreen = false
        }
    }
}
