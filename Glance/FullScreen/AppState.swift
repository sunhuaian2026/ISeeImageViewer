//
//  AppState.swift
//  Glance
//

import AppKit
import Combine

enum AppearanceMode: String, CaseIterable {
    case system = "system"
    case light  = "light"
    case dark   = "dark"

    var label: String {
        switch self {
        case .system: return "跟随系统"
        case .light:  return "浅色"
        case .dark:   return "深色"
        }
    }
}

class AppState: ObservableObject {
    @Published var isFullScreen = false
    weak var window: NSWindow?

    @Published var appearanceMode: AppearanceMode {
        didSet {
            UserDefaults.standard.set(appearanceMode.rawValue, forKey: "appearanceMode")
        }
    }

    // isFullScreen 默认 false，window 默认 nil，无需显式赋值
    init() {
        let raw = UserDefaults.standard.string(forKey: "appearanceMode") ?? "system"
        self.appearanceMode = AppearanceMode(rawValue: raw) ?? .system
    }

    func toggleFullScreen() {
        window?.toggleFullScreen(nil)
    }

    func exitFullScreenIfNeeded() {
        guard isFullScreen else { return }
        window?.toggleFullScreen(nil)
    }

    func hideTrafficLights() {
        guard !isFullScreen else { return }
        [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton].forEach {
            window?.standardWindowButton($0)?.isHidden = true
        }
    }

    func showTrafficLights() {
        // 不加 isFullScreen guard：全屏下系统靠 hover 显示 traffic light，
        // 但前提是 isHidden == false。若之前显式隐藏过，此处必须恢复，否则按钮永久消失。
        [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton].forEach {
            window?.standardWindowButton($0)?.isHidden = false
        }
    }
}
