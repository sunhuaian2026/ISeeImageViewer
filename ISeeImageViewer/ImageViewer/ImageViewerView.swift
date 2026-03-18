//
//  ImageViewerView.swift
//  ISeeImageViewer
//

import SwiftUI

struct ImageViewerView: View {
    @StateObject private var viewModel: ImageViewerViewModel
    let onDismiss: () -> Void

    @FocusState private var isFocused: Bool

    init(images: [URL], startIndex: Int, onDismiss: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: ImageViewerViewModel(images: images, startIndex: startIndex))
        self.onDismiss = onDismiss
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Image
            if let nsImage = viewModel.currentNSImage {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(viewModel.scale)
                    .offset(viewModel.offset)
                    .gesture(magnificationGesture)
            } else {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
            }

            // Navigation buttons overlay
            HStack {
                navButton(systemImage: "chevron.left", enabled: viewModel.canGoBack) {
                    viewModel.goBack()
                }
                Spacer()
                navButton(systemImage: "chevron.right", enabled: viewModel.canGoForward) {
                    viewModel.goForward()
                }
            }
            .padding(.horizontal, 16)

            // Progress indicator
            VStack {
                HStack {
                    Spacer()
                    Text(viewModel.progress)
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(8)
                        .padding(12)
                }
                Spacer()
            }
        }
        .focusable()
        .focused($isFocused)
        .onAppear { isFocused = true }
        .onKeyPress(.leftArrow) { viewModel.goBack(); return .handled }
        .onKeyPress(.rightArrow) { viewModel.goForward(); return .handled }
        .onKeyPress(.escape) { onDismiss(); return .handled }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func navButton(systemImage: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title)
                .foregroundColor(.white.opacity(enabled ? 0.9 : 0.25))
                .frame(width: 44, height: 44)
                .background(Color.black.opacity(enabled ? 0.4 : 0.15))
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
