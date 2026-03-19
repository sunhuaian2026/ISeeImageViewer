//
//  ImageViewerViewModel.swift
//  ISeeImageViewer
//

import Foundation
import AppKit
import Combine

@MainActor
class ImageViewerViewModel: ObservableObject {
    @Published var currentIndex: Int
    @Published var scale: CGFloat = 1.0
    @Published var offset: CGSize = .zero
    @Published var currentNSImage: NSImage? = nil

    var baseScale: CGFloat = 1.0
    let images: [URL]

    private var imageLoadTask: Task<Void, Never>?

    init(images: [URL], startIndex: Int) {
        self.images = images
        self.currentIndex = max(0, min(startIndex, images.count - 1))
        loadCurrentImage()
    }

    // MARK: - Computed

    var currentImageURL: URL { images[currentIndex] }

    var progress: String { "\(currentIndex + 1) / \(images.count)" }

    var canGoBack: Bool { currentIndex > 0 }

    var canGoForward: Bool { currentIndex < images.count - 1 }

    // MARK: - Navigation

    func goBack() {
        guard canGoBack else { return }
        currentIndex -= 1
        resetZoom()
        loadCurrentImage()
    }

    func goForward() {
        guard canGoForward else { return }
        currentIndex += 1
        resetZoom()
        loadCurrentImage()
    }

    func goTo(index: Int) {
        guard index >= 0, index < images.count, index != currentIndex else { return }
        currentIndex = index
        resetZoom()
        loadCurrentImage()
    }

    func resetZoom() {
        scale = 1.0
        baseScale = 1.0
        offset = .zero
    }

    // MARK: - Image Loading

    private func loadCurrentImage() {
        let url = images[currentIndex]
        currentNSImage = nil
        imageLoadTask?.cancel()
        imageLoadTask = Task {
            let image: NSImage? = await Task.detached(priority: .userInitiated) {
                NSImage(contentsOf: url)
            }.value
            if !Task.isCancelled {
                currentNSImage = image
            }
        }
    }
}
