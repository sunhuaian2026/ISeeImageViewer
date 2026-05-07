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
            // 锁定 toolbar 与 title bar 融合（fused），首次渲染就避免 SwiftUI
            // NavigationSplitView 默认 separated/expanded 浅灰横条跟 preview 紫黑断层
            window.toolbarStyle = .unified
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
                // 幂等设置：SwiftUI 重建 representable 时也保持 fused，避免回退
                window.toolbarStyle = .unified
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
