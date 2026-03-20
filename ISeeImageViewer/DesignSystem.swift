//
//  DesignSystem.swift
//  ISeeImageViewer
//
//  所有 UI 常量的唯一来源，遵循 specs/UI.md 规范。
//  使用方式：DS.Spacing.md、DS.Color.viewerBackground、DS.Animation.normal
//

import SwiftUI

enum DS {

    // MARK: - Spacing（8pt Grid）

    enum Spacing {
        static let xs: CGFloat = 4    // 极小：图标与文字
        static let sm: CGFloat = 8    // 小：列表行内部、缩略图间距
        static let md: CGFloat = 16   // 中：组件之间、侧边栏内边距
        static let lg: CGFloat = 24   // 大：区块之间
        static let xl: CGFloat = 32   // 超大：页面边距
    }

    // MARK: - Thumbnail

    enum Thumbnail {
        static let defaultSize: CGFloat = 160
        static let minSize: CGFloat = 80
        static let maxSize: CGFloat = 280
        static let spacing: CGFloat = 8
        static let cornerRadius: CGFloat = 4
    }

    // MARK: - Sidebar

    enum Sidebar {
        static let width: CGFloat = 220
        static let minWidth: CGFloat = 180
        static let maxWidth: CGFloat = 300
        static let rowHeight: CGFloat = 36
        static let rowPaddingH: CGFloat = 12
        static let iconSize: CGFloat = 16
    }

    // MARK: - Viewer

    enum Viewer {
        static let toolbarHeight: CGFloat = 52
        static let filmstripHeight: CGFloat = 76
        static let minZoom: CGFloat = 0.1
        static let maxZoom: CGFloat = 16.0
    }

    // MARK: - Animation

    enum Animation {
        /// 缩略图选中、小交互（0.1s）
        static let fast = SwiftUI.Animation.easeInOut(duration: 0.1)
        /// 工具栏显隐、控件过渡（0.2s）
        static let normal = SwiftUI.Animation.easeInOut(duration: 0.2)
        /// 图片切换（0.15s）
        static let imageCross = SwiftUI.Animation.easeInOut(duration: 0.15)
    }

    // MARK: - Color

    enum Color {
        /// 看图界面背景 #1A1A1A（不用纯黑）
        static let viewerBackground = SwiftUI.Color(red: 0.1, green: 0.1, blue: 0.1)
        /// 侧边栏背景 #262626
        static let sidebarBackground = SwiftUI.Color(red: 0.15, green: 0.15, blue: 0.15)
        /// 悬停态背景
        static let hoverBackground = SwiftUI.Color.white.opacity(0.08)
        /// 选中态背景
        static let selectedBackground = SwiftUI.Color.accentColor.opacity(0.15)
    }

    // MARK: - Icons（SF Symbols）

    enum Icon {
        static let folder = "folder"
        static let album = "photo.on.rectangle"
        static let add = "plus"
        static let trash = "trash"
        static let favorite = "heart"
        static let search = "magnifyingglass"
        static let previous = "arrow.left"
        static let next = "arrow.right"
        static let fullscreen = "arrow.up.left.and.arrow.down.right"
        static let info = "info.circle"
        static let infoFilled = "info.circle.fill"
        static let close = "xmark"
    }
}
