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
        private var dragStartOffset: CGSize = .zero

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
            if event.clickCount == 2 {
                switch vm.zoomMode {
                case .fit: vm.resetToOneToOne()
                default:   vm.resetToFit()
                }
            } else {
                dragStartOffset = vm.offset
            }
        }

        // MARK: Drag → pan

        override func mouseDragged(with event: NSEvent) {
            guard let vm = viewModel, vm.canPan else { return }
            vm.offset = CGSize(
                width: dragStartOffset.width + event.deltaX * 2,
                height: dragStartOffset.height - event.deltaY * 2
            )
            // Re-accumulate drag delta
            dragStartOffset = CGSize(
                width: vm.offset.width - event.deltaX * 2,
                height: vm.offset.height + event.deltaY * 2
            )
        }
    }
}
