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
            // Image
            if let nsImage = viewModel.currentNSImage {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.5), radius: 24, x: 0, y: 8)
                    .padding(40)
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
            .padding(.horizontal, 24)

            // Top bar: close button (left) + progress indicator (right)
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
        }
        .background(.regularMaterial)
        .environment(\.colorScheme, .dark)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(8)
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
