//
//  AboutView.swift
//  Glance
//
//  自定义"关于"窗口（替换 macOS 系统标准 NSAboutPanel）。
//  原因：标准面板的 NSHumanReadableCopyright 字段不可点击，无法挂复制 handler；
//  改用 SwiftUI 自定义 view 让两行 contact 信息支持点击复制 + toast 提示。
//

import SwiftUI
import AppKit

struct AboutView: View {
    private static let line1 = "© 2026 孙红军 · 16414766@qq.com"
    private static let line2 = "小红书 382336617"

    @State private var toastMessage: String? = nil
    @State private var toastTask: Task<Void, Never>? = nil

    private var versionLabel: String {
        let info = Bundle.main.infoDictionary
        let marketing = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "版本 \(marketing) (\(build))"
    }

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            if let icon = NSApplication.shared.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: DS.About.appIconSize, height: DS.About.appIconSize)
            }

            Text("一眼")
                .font(.title2.weight(.semibold))

            Text(versionLabel)
                .font(.callout)
                .foregroundStyle(DS.Color.secondaryText)
                .textSelection(.enabled)

            Divider()
                .padding(.horizontal, DS.Spacing.lg)

            VStack(spacing: DS.Spacing.xs) {
                copyableLine(Self.line1)
                copyableLine(Self.line2)
            }
        }
        .padding(DS.Spacing.lg + DS.Spacing.xs)
        .frame(width: DS.About.windowWidth)
        .overlay(alignment: .bottom) {
            if let msg = toastMessage {
                Text(msg)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, DS.Spacing.sm + DS.Spacing.xs)
                    .padding(.vertical, DS.Spacing.xs)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, DS.Spacing.sm)
                    .frame(maxWidth: DS.About.toastMaxWidth)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(DS.Anim.fast, value: toastMessage)
    }

    @ViewBuilder
    private func copyableLine(_ text: String) -> some View {
        Button {
            copyToPasteboard(text)
        } label: {
            Text(text)
                .font(.caption)
                .foregroundStyle(DS.Color.secondaryText)
                .multilineTextAlignment(.center)
        }
        .buttonStyle(.plain)
        .pointingHandCursorOnHover()
        .help("点击复制")
    }

    private func copyToPasteboard(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        showToast("已复制：\(text)")
    }

    private func showToast(_ msg: String) {
        toastTask?.cancel()
        toastMessage = msg
        toastTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(DS.About.toastDurationSeconds))
            guard !Task.isCancelled else { return }
            withAnimation(DS.Anim.fast) { toastMessage = nil }
        }
    }
}

private extension View {
    // 鼠标 hover 时显示手指 pointer cursor，强化"可点击"暗示
    func pointingHandCursorOnHover() -> some View {
        self.onHover { hovering in
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}

#Preview {
    AboutView()
}
