//
//  QuickViewerViewModel.swift
//  ISeeImageViewer
//

import Foundation
import AppKit
import Combine

enum ZoomMode {
    case fit
    case oneToOne
    case custom
}

class QuickViewerViewModel: ObservableObject {
    // 数据
    let images: [URL]
    @Published var currentIndex: Int
    @Published var currentNSImage: NSImage?

    // 缩放
    @Published var zoomMode: ZoomMode = .fit
    @Published var scale: CGFloat = 1.0
    @Published var offset: CGSize = .zero

    // 辅助
    var baseScale: CGFloat = 1.0
    var viewportSize: CGSize = .zero

    private var imageLoadTask: Task<Void, Never>?

    init(images: [URL], startIndex: Int) {
        self.images = images
        self.currentIndex = max(0, min(startIndex, images.count - 1))
        loadCurrentImage()
    }

    // MARK: - Computed

    var progress: String { "\(currentIndex + 1) / \(images.count)" }

    var zoomPercent: String { "\(Int(scale * 100))%" }

    var canGoBack: Bool { currentIndex > 0 }

    var canGoForward: Bool { currentIndex < images.count - 1 }

    var canPan: Bool {
        guard let image = currentNSImage, viewportSize != .zero else { return false }
        return scale > fitScale(for: image, in: viewportSize)
    }

    // MARK: - Navigation

    func goBack() {
        guard canGoBack else { return }
        currentIndex -= 1
        resetToFit()
        loadCurrentImage()
    }

    func goForward() {
        guard canGoForward else { return }
        currentIndex += 1
        resetToFit()
        loadCurrentImage()
    }

    func goTo(index: Int) {
        guard index >= 0, index < images.count, index != currentIndex else { return }
        currentIndex = index
        resetToFit()
        loadCurrentImage()
    }

    // MARK: - Zoom

    func resetToFit() {
        zoomMode = .fit
        if let image = currentNSImage, viewportSize != .zero {
            scale = fitScale(for: image, in: viewportSize)
        } else {
            scale = 1.0
        }
        offset = .zero
        baseScale = scale
    }

    func resetToOneToOne() {
        zoomMode = .oneToOne
        scale = 1.0
        offset = .zero
        baseScale = 1.0
    }

    func zoomIn() {
        let newScale = min(scale * 1.25, DS.Viewer.maxZoom)
        scale = newScale
        zoomMode = .custom
        baseScale = scale
        clampOffset()
    }

    func zoomOut() {
        let newScale = max(scale / 1.25, DS.Viewer.minZoom)
        scale = newScale
        zoomMode = .custom
        baseScale = scale
        clampOffset()
    }

    func setScale(_ s: CGFloat, anchor: CGPoint, viewSize: CGSize) {
        let clamped = max(DS.Viewer.minZoom, min(DS.Viewer.maxZoom, s))
        let ratio = clamped / scale

        // 以光标为中心调整 offset
        let anchorOffsetX = anchor.x - viewSize.width / 2
        let anchorOffsetY = anchor.y - viewSize.height / 2
        offset = CGSize(
            width: (offset.width + anchorOffsetX) * ratio - anchorOffsetX,
            height: (offset.height + anchorOffsetY) * ratio - anchorOffsetY
        )

        scale = clamped
        zoomMode = .custom
        clampOffset()
    }

    func applyViewportSize(_ size: CGSize) {
        guard size != viewportSize else { return }
        viewportSize = size
        if zoomMode == .fit, let image = currentNSImage {
            scale = fitScale(for: image, in: size)
            baseScale = scale
        }
    }

    func onImageLoaded(_ image: NSImage) {
        if zoomMode == .fit, viewportSize != .zero {
            scale = fitScale(for: image, in: viewportSize)
            baseScale = scale
        }
        offset = .zero
    }

    // MARK: - Private

    func fitScale(for image: NSImage, in viewport: CGSize) -> CGFloat {
        guard image.size.width > 0, image.size.height > 0 else { return 1.0 }
        let scaleW = viewport.width / image.size.width
        let scaleH = viewport.height / image.size.height
        return min(scaleW, scaleH, 1.0)
    }

    private func clampOffset() {
        guard let image = currentNSImage, viewportSize != .zero else {
            offset = .zero
            return
        }
        let scaledW = image.size.width * scale
        let scaledH = image.size.height * scale
        let maxOffsetX = max(0, (scaledW - viewportSize.width) / 2)
        let maxOffsetY = max(0, (scaledH - viewportSize.height) / 2)
        offset = CGSize(
            width: max(-maxOffsetX, min(maxOffsetX, offset.width)),
            height: max(-maxOffsetY, min(maxOffsetY, offset.height))
        )
    }

    private func loadCurrentImage() {
        let url = images[currentIndex]
        currentNSImage = nil
        imageLoadTask?.cancel()
        imageLoadTask = Task {
            let image: NSImage? = await Task.detached(priority: .userInitiated) {
                NSImage(contentsOf: url)
            }.value
            guard !Task.isCancelled else { return }
            currentNSImage = image
            if let image {
                onImageLoaded(image)
            }
        }
    }
}
