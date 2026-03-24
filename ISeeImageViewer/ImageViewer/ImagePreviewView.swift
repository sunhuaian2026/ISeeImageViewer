//
//  ImagePreviewView.swift
//  ISeeImageViewer
//
//  单击图片后显示的内嵌预览。双击图片进入 QuickViewerOverlay 全窗口模式。
//

import SwiftUI

struct ImagePreviewView: View {
    @EnvironmentObject var folderStore: FolderStore

    let images: [URL]
    let onDismiss: () -> Void
    let onQuickView: (Int) -> Void

    @State private var currentIndex: Int
    @State private var nsImage: NSImage?
    @State private var loadTask: Task<Void, Never>?

    init(images: [URL], startIndex: Int,
         onDismiss: @escaping () -> Void,
         onQuickView: @escaping (Int) -> Void) {
        self.images = images
        _currentIndex = State(initialValue: max(0, min(startIndex, images.count - 1)))
        self.onDismiss = onDismiss
        self.onQuickView = onQuickView
    }

    var body: some View {
        ZStack {
            DS.Color.appBackground.ignoresSafeArea()

            // 青绿光晕（右下角）
            RadialGradient(
                colors: [DS.Color.glowSecondary.opacity(0.12), .clear],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 400
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // 图片
            if let img = nsImage {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
                    .padding(DS.Spacing.xl)
                    .onTapGesture(count: 2) {
                        onQuickView(currentIndex)
                    }
            } else {
                ProgressView()
                    .controlSize(.large)
            }

            // 关闭按钮（左上角浮动）
            VStack {
                HStack {
                    Button(action: onDismiss) {
                        Image(systemName: DS.Icon.close)
                            .font(.body.weight(.semibold))
                            .foregroundColor(.primary.opacity(0.8))
                            .frame(width: 32, height: 32)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    // n/m 进度（右上角浮动）
                    Text("\(currentIndex + 1) / \(images.count)")
                        .font(.caption)
                        .foregroundColor(.primary)
                        .padding(.horizontal, DS.Spacing.sm + DS.Spacing.xs)
                        .padding(.vertical, DS.Spacing.xs + 2)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Spacing.sm))
                }
                .padding(DS.Spacing.md)
                Spacer()
            }

            // 左右导航
            HStack {
                navButton(systemImage: DS.Icon.previous, enabled: currentIndex > 0) {
                    navigate(by: -1)
                }
                Spacer()
                navButton(systemImage: DS.Icon.next, enabled: currentIndex < images.count - 1) {
                    navigate(by: +1)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)

            // 底部提示
            VStack {
                Spacer()
                Text("双击图片进入全屏查看")
                    .font(.caption)
                    .foregroundColor(.primary.opacity(0.35))
                    .padding(.bottom, DS.Spacing.md)
            }
        }
        .navigationTitle(images[currentIndex].lastPathComponent)
        .onAppear { loadImage() }
        .onKeyPress(.escape)     { onDismiss(); return .handled }
        .onKeyPress(.leftArrow)  { navigate(by: -1); return .handled }
        .onKeyPress(.rightArrow) { navigate(by: +1); return .handled }
        .onKeyPress(.space) { onQuickView(currentIndex); return .handled }
    }

    // MARK: - Navigation

    private func navigate(by delta: Int) {
        let next = currentIndex + delta
        guard next >= 0, next < images.count else { return }
        currentIndex = next
        folderStore.selectedImageIndex = next
        loadImage()
    }

    // MARK: - Image Loading

    private func loadImage() {
        let url = images[currentIndex]
        nsImage = nil
        loadTask?.cancel()
        loadTask = Task {
            let img: NSImage? = await Task.detached(priority: .userInitiated) {
                NSImage(contentsOf: url)
            }.value
            guard !Task.isCancelled else { return }
            nsImage = img
        }
    }

    // MARK: - Nav Button

    @ViewBuilder
    private func navButton(systemImage: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundColor(.primary.opacity(enabled ? 0.9 : 0.25))
                .frame(width: 44, height: 44)
                .background(enabled ? AnyShapeStyle(.regularMaterial) : AnyShapeStyle(.ultraThinMaterial))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}
