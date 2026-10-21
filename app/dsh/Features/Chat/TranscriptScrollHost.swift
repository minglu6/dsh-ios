import SwiftUI
import UIKit

/// A stable native owner keeps refresh and pan observation independent of layout updates.
struct TranscriptScrollHost: UIViewRepresentable {
    let onBegan: () -> Void
    let onEnded: () -> Void
    let onRefresh: () async -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onBegan: onBegan, onEnded: onEnded, onRefresh: onRefresh)
    }

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
        context.coordinator.onRefresh = onRefresh
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

    @MainActor final class Coordinator: NSObject {
        var onBegan: () -> Void
        var onEnded: () -> Void
        var onRefresh: () async -> Void
        private weak var scrollView: UIScrollView?
        private let refreshControl = UIRefreshControl()
        private var refreshTask: Task<Void, Never>?
        private var previousBounce = false

        init(onBegan: @escaping () -> Void, onEnded: @escaping () -> Void, onRefresh: @escaping () async -> Void) {
            self.onBegan = onBegan
            self.onEnded = onEnded
            self.onRefresh = onRefresh
            super.init()
            refreshControl.addTarget(self, action: #selector(refreshChanged), for: .valueChanged)
        }

        func attach(from view: UIView) {
            var ancestor = view.superview
            while let current = ancestor {
                if let scroll = current as? UIScrollView {
                    guard scroll !== scrollView else { return }
                    detach()
                    scrollView = scroll
                    previousBounce = scroll.alwaysBounceVertical
                    scroll.alwaysBounceVertical = true
                    scroll.refreshControl = refreshControl
                    scroll.panGestureRecognizer.addTarget(self, action: #selector(panChanged(_:)))
                    return
                }
                ancestor = current.superview
            }
        }

        func detach() {
            refreshTask?.cancel()
            refreshTask = nil
            refreshControl.endRefreshing()
            if let scroll = scrollView {
                scroll.panGestureRecognizer.removeTarget(self, action: #selector(panChanged(_:)))
                if scroll.refreshControl === refreshControl { scroll.refreshControl = nil }
                scroll.alwaysBounceVertical = previousBounce
            }
            scrollView = nil
        }

        @objc private func refreshChanged() {
            guard refreshTask == nil else { return }
            refreshTask = Task { @MainActor [weak self] in
                guard let self else { return }
                guard !Task.isCancelled else { return }
                await self.onRefresh()
                guard !Task.isCancelled else { return }
                self.refreshControl.endRefreshing()
                self.refreshTask = nil
            }
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
