//
//  DesignSystem.swift
//  Glance
//
//  所有 UI 常量的唯一来源，遵循 specs/UI.md 规范。
//  使用方式：DS.Spacing.md、DS.Color.appBackground、DS.Anim.normal
//

import SwiftUI

enum DS {

    // MARK: - Spacing（8pt Grid）

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }

    // MARK: - Thumbnail

    enum Thumbnail {
        static let defaultSize: CGFloat = 180
        static let minSize: CGFloat = 80
        static let maxSize: CGFloat = 280
        static let spacing: CGFloat = 12
        static let cornerRadius: CGFloat = 8
    }

    // MARK: - Sidebar

    enum Sidebar {
        static let width: CGFloat = 220
        static let minWidth: CGFloat = 180
        static let maxWidth: CGFloat = 300
        static let rowHeight: CGFloat = 36
        static let rowPaddingH: CGFloat = 8
        static let iconSize: CGFloat = 16
        // 拖拽添加文件夹 drop target 高亮
        static let dropBorderWidth: CGFloat = 2
        static let dropBorderPadding: CGFloat = 4
        static let dropBorderCornerRadius: CGFloat = 10
        static let dropBorderOpacity: Double = 0.45
    }

    // MARK: - Viewer

    enum Viewer {
        static let filmstripHeight: CGFloat = 72
        static let filmstripThumbSize: CGFloat = 56
        // ImageIO 加载请求的最大像素尺寸（独立于 SwiftUI 渲染 frame，
        // 略大于 thumbSize 允许 retina 时不糊）。Int 类型对齐 loadThumbnail
        // 的 maxPixelSize 参数
        static let filmstripThumbLoadSize: Int = 80
        static let cardCornerRadius: CGFloat = 16
        static let cardPadding: CGFloat = 12
        // 缩放范围（QuickViewerViewModel 依赖）
        static let minZoom: CGFloat = 0.1
        static let maxZoom: CGFloat = 16.0
        // 原生 1:1 scale sentinel（视图不做任何变换，按图片原生像素尺寸呈现）
        static let nativeScale: CGFloat = 1.0
        // 适合窗口缩放：大图缩到窗口 fitPadding 占比，四周留呼吸边；小图 (≤ 窗口) 保 nativeScale 不上采样
        static let fitPadding: CGFloat = 0.9
    }

    // MARK: - About

    enum About {
        static let windowWidth: CGFloat = 320
        static let appIconSize: CGFloat = 96
        static let toastMaxWidth: CGFloat = 280
        static let toastDurationSeconds: TimeInterval = 1.5
    }

    // MARK: - Inspector

    enum Inspector {
        static let width: CGFloat = 260
        static let previewHeight: CGFloat = 120
        static let previewCornerRadius: CGFloat = 10
        // leading 边线宽度（macOS HiDPI 下 0.5pt = 1 物理像素，跟系统 separator 一致）
        static let separatorWidth: CGFloat = 0.5
    }

    // MARK: - Toolbar

    enum Toolbar {
        static let height: CGFloat = 44
        static let cornerRadius: CGFloat = 12
    }

    // MARK: - SectionHeader（V2 时间分段 chip）

    enum SectionHeader {
        // chip strokeBorder hairline（参考 macOS Calendar.app / Mail.app sidebar items）
        // 0.5pt 在 HiDPI 下对应 1 物理像素；opacity 0.12 跟系统 separator 视觉强度一致
        static let chipBorderWidth: CGFloat = 0.5
        static let chipBorderOpacity: Double = 0.12
    }

    // MARK: - Animation

    enum Anim {
        static let fast   = SwiftUI.Animation.easeInOut(duration: 0.15)
        static let normal = SwiftUI.Animation.easeInOut(duration: 0.2)
        static let slow   = SwiftUI.Animation.easeInOut(duration: 0.35)
    }

    // MARK: - Color

    enum Color {
        // 背景层（AdaptiveColor，响应 SwiftUI per-view colorScheme 环境）
        static let appBackground  = AdaptiveColor(
            light: SwiftUI.Color(red: 0.95, green: 0.95, blue: 0.97),  // #F2F2F7
            dark:  SwiftUI.Color(red: 0.07, green: 0.07, blue: 0.09)   // #121217
        )
        static let gridBackground = AdaptiveColor(
            light: SwiftUI.Color.white,                                // #FFFFFF（内容区焦点，跟 Finder/Notes 一致）
            dark:  SwiftUI.Color(red: 0.08, green: 0.08, blue: 0.11)   // #141419
        )

        // 悬停/交互（AdaptiveColor）
        static let hoverOverlay   = AdaptiveColor(
            light: SwiftUI.Color.black.opacity(0.05),
            dark:  SwiftUI.Color.white.opacity(0.06)
        )
        static let separatorColor = AdaptiveColor(
            light: SwiftUI.Color.black.opacity(0.08),
            dark:  SwiftUI.Color.white.opacity(0.08)
        )

        // 环境光（Liquid Glass 光晕，两种模式均适用，保持 SwiftUI.Color）
        static let glowPrimary    = SwiftUI.Color(red: 0.49, green: 0.42, blue: 1.0)  // 紫
        static let glowSecondary  = SwiftUI.Color(red: 0.2,  green: 0.6,  blue: 0.5)  // 青绿

        // 次级文本（标题之外的描述/版本号/copyright 等），alias 到 SwiftUI 标准
        // 语义色 .secondary，自动响应 colorScheme
        static let secondaryText: SwiftUI.Color = .secondary
    }

    // MARK: - Icons（SF Symbols）

    enum Icon {
        static let folder     = "folder"
        static let album      = "photo.on.rectangle"
        static let add        = "plus"
        static let trash      = "trash"
        static let favorite   = "heart"
        static let search     = "magnifyingglass"
        static let previous   = "arrow.left"
        static let next       = "arrow.right"
        static let fullscreen = "arrow.up.left.and.arrow.down.right"
        static let info       = "info.circle"
        static let infoFilled = "info.circle.fill"
        static let close      = "xmark"
    }
}

// MARK: - AdaptiveColor
// 通过 ShapeStyle.resolve(in:) 从 EnvironmentValues 读取 colorScheme，
// 正确响应 SwiftUI per-view preferredColorScheme 覆盖（如 QuickViewerOverlay 的强制深色）。

struct AdaptiveColor: ShapeStyle, View {
    let light: SwiftUI.Color
    let dark: SwiftUI.Color

    /// ShapeStyle 路径：由 SwiftUI 渲染时注入完整 EnvironmentValues，colorScheme 已反映视图级覆盖
    func resolve(in environment: EnvironmentValues) -> some ShapeStyle {
        environment.colorScheme == .dark ? dark : light
    }

    /// View 路径：通过独立 View 读取 @Environment(\.colorScheme)，供 .ignoresSafeArea() 等 View 修饰符使用
    var body: some View {
        _AdaptiveColorBody(light: light, dark: dark)
    }
}

private struct _AdaptiveColorBody: View {
    let light: SwiftUI.Color
    let dark: SwiftUI.Color
    @Environment(\.colorScheme) private var colorScheme
    var body: some View { colorScheme == .dark ? dark : light }
}
