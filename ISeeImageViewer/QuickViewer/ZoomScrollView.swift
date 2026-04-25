//
//  ZoomScrollView.swift
//  ISeeImageViewer
//

import SwiftUI
import AppKit

struct ZoomScrollView: NSViewRepresentable {
    var viewModel: QuickViewerViewModel

    func makeNSView(context: Context) -> ZoomView {
        let view = ZoomView()
        view.viewModel = viewModel
        return view
    }

    func updateNSView(_ nsView: ZoomView, context: Context) {
        nsView.viewModel = viewModel
    }

    // MARK: - ZoomView

    class ZoomView: NSView {
        var viewModel: QuickViewerViewModel?

        override var acceptsFirstResponder: Bool { true }

        // MARK: Scroll wheel → zoom at cursor

        override func scrollWheel(with event: NSEvent) {
            guard let vm = viewModel else { return }
            guard event.deltaY != 0 else { return }

            let delta = event.deltaY
            let factor = delta > 0 ? 1.0 / 1.05 : 1.05
            let newScale = vm.scale * factor

            let locationInView = convert(event.locationInWindow, from: nil)
            let anchor = CGPoint(x: locationInView.x, y: bounds.height - locationInView.y)
            let viewSize = CGSize(width: bounds.width, height: bounds.height)

            vm.setScale(newScale, anchor: anchor, viewSize: viewSize)
        }

        // MARK: Double click → toggle fit / 1:1

        override func mouseDown(with event: NSEvent) {
            guard let vm = viewModel else { return }
            guard event.clickCount == 2 else { return }
            switch vm.zoomMode {
            case .fit: vm.resetToOneToOne()
            default:   vm.resetToFit()
            }
        }

        // MARK: Drag → pan
        //
        // event.deltaX/Y 是 NSEvent 自上次 mouseDragged 以来的 incremental 位移，
        // 直接累加到 vm.offset。NSEvent.mouseDragged 的 deltaY 跟 SwiftUI .offset
        // 同向（y↓ 为正：鼠标向下 deltaY > 0），不需要取反 —— 早期注释写"AppKit y↑
        // → SwiftUI y↓ 取反"是错的，那是 view 坐标的语义，mouseDragged.delta 是
        // device/screen 坐标。VM.panBy 内部 clampOffset 兜底边界。
        override func mouseDragged(with event: NSEvent) {
            guard let vm = viewModel, vm.canPan else { return }
            vm.panBy(deltaX: event.deltaX, deltaY: event.deltaY)
        }
    }
}
