import SwiftUI
import UIKit

/// Observe the native pan without installing a second recognizer over pull-to-refresh.
struct TranscriptPanObserver: UIViewRepresentable {
    let onBegan: () -> Void
    let onEnded: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onBegan: onBegan, onEnded: onEnded) }

    func makeUIView(context: Context) -> Probe {
        let view = Probe()
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = false
        view.coordinator = context.coordinator
        return view
    }

    func updateUIView(_ view: Probe, context: Context) {
        context.coordinator.onBegan = onBegan
        context.coordinator.onEnded = onEnded
        context.coordinator.attach(from: view)
    }

    static func dismantleUIView(_ view: Probe, coordinator: Coordinator) { coordinator.detach() }

    final class Probe: UIView {
        weak var coordinator: Coordinator?
        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window == nil { coordinator?.detach() }
            else { coordinator?.attach(from: self) }
        }
        override func layoutSubviews() {
            super.layoutSubviews()
            coordinator?.attach(from: self)
        }
    }

    final class Coordinator: NSObject {
        var onBegan: () -> Void
        var onEnded: () -> Void
        private weak var scrollView: UIScrollView?

        init(onBegan: @escaping () -> Void, onEnded: @escaping () -> Void) {
            self.onBegan = onBegan
            self.onEnded = onEnded
        }

        func attach(from view: UIView) {
            var ancestor = view.superview
            while let current = ancestor {
                if let scroll = current as? UIScrollView {
                    guard scroll !== scrollView else { return }
                    detach()
                    scrollView = scroll
                    scroll.panGestureRecognizer.addTarget(self, action: #selector(panChanged(_:)))
                    return
                }
                ancestor = current.superview
            }
        }

        func detach() {
            scrollView?.panGestureRecognizer.removeTarget(self, action: #selector(panChanged(_:)))
            scrollView = nil
        }

        @objc private func panChanged(_ recognizer: UIPanGestureRecognizer) {
            switch recognizer.state {
            case .began: onBegan()
            case .ended, .cancelled, .failed: onEnded()
            default: break
            }
        }
    }
}
