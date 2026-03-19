//
//  ImageViewerView.swift
//  ISeeImageViewer
//

import SwiftUI

struct ImageViewerView: View {
    @StateObject private var viewModel: ImageViewerViewModel
    let onDismiss: () -> Void

    @FocusState private var isFocused: Bool
    @State private var controlsVisible = true
    @State private var hideTask: Task<Void, Never>?

    init(images: [URL], startIndex: Int, onDismiss: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: ImageViewerViewModel(images: images, startIndex: startIndex))
        self.onDismiss = onDismiss
    }

    var body: some View {
        ZStack {
            // Image
            if let nsImage = viewModel.currentNSImage {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.5), radius: 24, x: 0, y: 8)
                    .padding(.horizontal, 40)
                    .padding(.top, 40)
                    .padding(.bottom, 92)
                    .scaleEffect(viewModel.scale)
                    .offset(viewModel.offset)
                    .gesture(magnificationGesture)
            } else {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
            }

            // Navigation buttons
            HStack {
                navButton(systemImage: "chevron.left", enabled: viewModel.canGoBack) {
                    viewModel.goBack()
                }
                Spacer()
                navButton(systemImage: "chevron.right", enabled: viewModel.canGoForward) {
                    viewModel.goForward()
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 76)
            .opacity(controlsVisible ? 1 : 0)

            // Top bar
            VStack {
                HStack {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 32, height: 32)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(16)
                    Spacer()
                    Text(viewModel.progress)
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                        .padding(12)
                }
                Spacer()
            }
            .opacity(controlsVisible ? 1 : 0)

            // Filmstrip
            VStack(spacing: 0) {
                Spacer()
                filmstrip
            }
            .opacity(controlsVisible ? 1 : 0)
        }
        .background(.regularMaterial)
        .environment(\.colorScheme, .dark)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(8)
        .onContinuousHover { phase in
            switch phase {
            case .active:
                showControlsTemporarily()
            case .ended:
                scheduleHide(after: 1.0)
            }
        }
        .focusable()
        .focused($isFocused)
        .onAppear {
            isFocused = true
            showControlsTemporarily()
        }
        .onDisappear {
            hideTask?.cancel()
        }
        .onKeyPress(.leftArrow) { viewModel.goBack(); return .handled }
        .onKeyPress(.rightArrow) { viewModel.goForward(); return .handled }
        .onKeyPress(.escape) { onDismiss(); return .handled }
    }

    // MARK: - Filmstrip

    @ViewBuilder
    private var filmstrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 6) {
                    ForEach(Array(viewModel.images.enumerated()), id: \.element) { index, url in
                        FilmstripCell(url: url, isSelected: index == viewModel.currentIndex)
                            .id(index)
                            .onTapGesture { viewModel.goTo(index: index) }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .frame(height: 76)
            .background(.ultraThinMaterial)
            .onChange(of: viewModel.currentIndex) { _, newIndex in
                withAnimation(.spring(duration: 0.3)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
            .onAppear {
                proxy.scrollTo(viewModel.currentIndex, anchor: .center)
            }
        }
    }

    // MARK: - Controls Auto-hide

    private func showControlsTemporarily() {
        withAnimation(.easeIn(duration: 0.15)) { controlsVisible = true }
        scheduleHide(after: 2.0)
    }

    private func scheduleHide(after seconds: Double) {
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.4)) { controlsVisible = false }
            }
        }
    }

    // MARK: - Nav Button

    @ViewBuilder
    private func navButton(systemImage: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title)
                .foregroundColor(.white.opacity(enabled ? 0.9 : 0.25))
                .frame(width: 44, height: 44)
                .background(enabled ? AnyShapeStyle(.regularMaterial) : AnyShapeStyle(.ultraThinMaterial))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    // MARK: - Gestures

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let newScale = viewModel.baseScale * value
                viewModel.scale = max(0.5, min(5.0, newScale))
            }
            .onEnded { _ in
                viewModel.baseScale = viewModel.scale
            }
    }
}

// MARK: - FilmstripCell

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
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 56, height: 56)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(isSelected ? Color.white : Color.clear, lineWidth: 2)
        )
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(.spring(duration: 0.2), value: isSelected)
        .task { thumbnail = await loadThumbnail(url: url, maxPixelSize: 80) }
    }
}
