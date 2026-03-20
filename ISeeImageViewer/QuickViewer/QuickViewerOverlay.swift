//
//  QuickViewerOverlay.swift
//  ISeeImageViewer
//

import SwiftUI

struct QuickViewerOverlay: View {
    @StateObject private var viewModel: QuickViewerViewModel
    let onDismiss: () -> Void

    @FocusState private var isFocused: Bool
    @State private var controlsVisible = true
    @State private var hideTask: Task<Void, Never>?

    init(images: [URL], startIndex: Int, onDismiss: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: QuickViewerViewModel(images: images, startIndex: startIndex))
        self.onDismiss = onDismiss
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 背景
                DS.Color.viewerBackground
                    .ignoresSafeArea()

                // 图片 + 缩放层
                ZoomScrollView(viewModel: viewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay {
                        imageLayer
                    }

                // 顶部状态栏
                VStack {
                    topBar
                    Spacer()
                }
                .opacity(controlsVisible ? 1 : 0)

                // 左右导航
                HStack {
                    navButton(systemImage: DS.Icon.previous, enabled: viewModel.canGoBack) {
                        viewModel.goBack()
                    }
                    Spacer()
                    navButton(systemImage: DS.Icon.next, enabled: viewModel.canGoForward) {
                        viewModel.goForward()
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Viewer.filmstripHeight)
                .opacity(controlsVisible ? 1 : 0)

                // 底部：工具栏 + 胶片条
                VStack(spacing: 0) {
                    Spacer()
                    bottomToolbar
                        .opacity(controlsVisible ? 1 : 0)
                    filmstrip
                        .opacity(controlsVisible ? 1 : 0)
                }
            }
            .onAppear {
                viewModel.applyViewportSize(geo.size)
                isFocused = true
                showControlsTemporarily()
            }
            .onChange(of: geo.size) { _, newSize in
                viewModel.applyViewportSize(newSize)
            }
        }
        .preferredColorScheme(.dark)
        .focusable()
        .focused($isFocused)
        .onDisappear { hideTask?.cancel() }
        .onContinuousHover { phase in
            switch phase {
            case .active: showControlsTemporarily()
            case .ended:  scheduleHide(after: 1.0)
            }
        }
        // 键盘快捷键
        .onKeyPress(.escape)     { onDismiss(); return .handled }
        .onKeyPress(.space)      { onDismiss(); return .handled }
        .onKeyPress(.leftArrow)  { viewModel.goBack(); return .handled }
        .onKeyPress(.rightArrow) { viewModel.goForward(); return .handled }
        .onKeyPress(.init("0"), phases: .down) { _ in
            if NSEvent.modifierFlags.contains(.command) {
                viewModel.resetToFit()
            } else {
                viewModel.resetToOneToOne()
            }
            return .handled
        }
        .onKeyPress(.init("="), phases: .down) { _ in
            if NSEvent.modifierFlags.contains(.command) { viewModel.zoomIn() }
            return .handled
        }
        .onKeyPress(.init("-"), phases: .down) { _ in
            if NSEvent.modifierFlags.contains(.command) { viewModel.zoomOut() }
            return .handled
        }
        // 捏合手势
        .gesture(
            MagnificationGesture()
                .onChanged { value in
                    let newScale = viewModel.baseScale * value
                    viewModel.scale = max(DS.Viewer.minZoom, min(DS.Viewer.maxZoom, newScale))
                    viewModel.zoomMode = .custom
                }
                .onEnded { _ in
                    viewModel.baseScale = viewModel.scale
                }
        )
    }

    // MARK: - Image Layer

    @ViewBuilder
    private var imageLayer: some View {
        if let nsImage = viewModel.currentNSImage {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFit()
                .scaleEffect(viewModel.scale)
                .offset(viewModel.offset)
                .animation(nil, value: viewModel.scale)
                .animation(nil, value: viewModel.offset)
                .allowsHitTesting(false)
        } else {
            ProgressView()
                .controlSize(.large)
                .tint(.white)
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: DS.Icon.close)
                    .font(.body.weight(.semibold))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 32, height: 32)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            if let url = viewModel.images[safe: viewModel.currentIndex] {
                Text(url.lastPathComponent)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            HStack(spacing: DS.Spacing.sm) {
                Text(viewModel.zoomPercent)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                Text(viewModel.progress)
                    .font(.caption)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, DS.Spacing.sm + DS.Spacing.xs)
            .padding(.vertical, DS.Spacing.xs + 2)
            .background(.ultraThinMaterial)
            .cornerRadius(DS.Spacing.sm)
        }
        .padding(.horizontal, DS.Spacing.md)
        .frame(height: DS.Viewer.toolbarHeight)
        .background(.ultraThinMaterial)
    }

    // MARK: - Bottom Toolbar

    private var bottomToolbar: some View {
        HStack(spacing: DS.Spacing.sm) {
            toolbarButton(title: "适合", systemImage: "arrow.up.left.and.down.right.magnifyingglass") {
                viewModel.resetToFit()
            }
            toolbarButton(title: "1:1", systemImage: "1.magnifyingglass") {
                viewModel.resetToOneToOne()
            }
            toolbarButton(title: "缩小", systemImage: "minus.magnifyingglass") {
                viewModel.zoomOut()
            }
            Text(viewModel.zoomPercent)
                .font(.caption)
                .foregroundColor(.white)
                .frame(minWidth: 44)
                .padding(.horizontal, DS.Spacing.xs)
                .frame(height: 32)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            toolbarButton(title: "放大", systemImage: "plus.magnifyingglass") {
                viewModel.zoomIn()
            }
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.xs)
    }

    // MARK: - Filmstrip

    private var filmstrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: DS.Spacing.xs + 2) {
                    ForEach(Array(viewModel.images.enumerated()), id: \.element) { index, url in
                        FilmstripCell(url: url, isSelected: index == viewModel.currentIndex)
                            .id(index)
                            .onTapGesture { viewModel.goTo(index: index) }
                    }
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm + DS.Spacing.xs)
            }
            .frame(height: DS.Viewer.filmstripHeight)
            .background(.ultraThinMaterial)
            .onChange(of: viewModel.currentIndex) { _, newIndex in
                withAnimation(DS.Animation.fast) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
            .onAppear {
                proxy.scrollTo(viewModel.currentIndex, anchor: .center)
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func navButton(systemImage: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundColor(.white.opacity(enabled ? 0.9 : 0.25))
                .frame(width: 44, height: 44)
                .background(enabled ? AnyShapeStyle(.regularMaterial) : AnyShapeStyle(.ultraThinMaterial))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    @ViewBuilder
    private func toolbarButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body)
                .foregroundColor(.white.opacity(0.85))
                .frame(width: 32, height: 32)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .help(title)
    }

    // MARK: - Auto-hide

    private func showControlsTemporarily() {
        withAnimation(DS.Animation.normal) { controlsVisible = true }
        scheduleHide(after: 2.0)
    }

    private func scheduleHide(after seconds: Double) {
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(DS.Animation.normal) { controlsVisible = false }
            }
        }
    }
}

// MARK: - Array safe subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - FilmstripCell（迁移自 ImageViewerView）

struct FilmstripCell: View {
    let url: URL
    let isSelected: Bool
    @State private var thumbnail: NSImage?

    var body: some View {
        ZStack {
            if let img = thumbnail {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipped()
            } else {
                Rectangle()
                    .fill(DS.Color.hoverBackground)
                    .frame(width: 56, height: 56)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: DS.Thumbnail.cornerRadius + DS.Spacing.xs))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Thumbnail.cornerRadius + DS.Spacing.xs)
                .stroke(isSelected ? Color.white : Color.clear, lineWidth: 2)
        )
        .scaleEffect(isSelected ? 1.08 : 1.0)
        .animation(DS.Animation.fast, value: isSelected)
        .task { thumbnail = await loadThumbnail(url: url, maxPixelSize: 80) }
    }
}
