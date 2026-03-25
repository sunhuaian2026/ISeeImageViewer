//
//  AppState.swift
//  ISeeImageViewer
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
        guard !isFullScreen else { return }
        [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton].forEach {
            window?.standardWindowButton($0)?.isHidden = false
        }
    }
}
