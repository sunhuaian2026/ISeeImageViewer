//
//  AboutWindowController.swift
//  Glance
//
//  纯 AppKit 单例 NSWindow 管理"关于"窗口。
//  替代 SwiftUI Window scene，原因：SwiftUI Window 不暴露"显示前定位" hook，
//  导致挪动主窗口后打开关于面板会有 A→B 位置跳跃（用户先看到默认位置 A，下一帧
//  才被 setFrameOrigin 到 B）。改用 NSWindow + NSHostingView，在
//  makeKeyAndOrderFront 之前就 setFrameOrigin 到主窗口中心，零跳跃。
//

import AppKit
import SwiftUI

final class AboutWindowController {
    static let shared = AboutWindowController()

    private var window: NSWindow?

    private init() {}

    func show() {
        if window == nil {
            createWindow()
        }
        guard let win = window else { return }
        centerOverMainWindow(win)
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func createWindow() {
        let hosting = NSHostingView(rootView: AboutView())
        let size = hosting.fittingSize
        let win = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = "关于一眼"
        win.contentView = hosting
        win.isReleasedWhenClosed = false  // 关闭后保留实例，下次 show 复用同一 window
        win.standardWindowButton(.miniaturizeButton)?.isHidden = true
        win.standardWindowButton(.zoomButton)?.isHidden = true
        window = win
    }

    private func centerOverMainWindow(_ aboutWindow: NSWindow) {
        guard let mainWindow = NSApp.windows.first(where: {
            $0 !== aboutWindow && $0.isVisible && $0.canBecomeMain
        }) else {
            aboutWindow.center()  // fallback: 屏幕中心
            return
        }
        let mainFrame = mainWindow.frame
        let aboutSize = aboutWindow.frame.size
        let x = mainFrame.origin.x + (mainFrame.width - aboutSize.width) / 2
        let y = mainFrame.origin.y + (mainFrame.height - aboutSize.height) / 2
        aboutWindow.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
