import SwiftUI
import UIKit

/// Programmatic IME dismiss. Composer uses a UIKit `UITextView` whose
/// `lockFirstResponder` (slash-menu key routing) otherwise swallows
/// `resignFirstResponder`, so SwiftUI overlays cannot hide the keyboard
/// by themselves.
enum Keyboard {
    static let dismissNotification = Notification.Name("dshDismissKeyboard")

    static var allowsResign = false
    private static var inFlight = false

    static func dismiss() {
        if inFlight { return }
        inFlight = true
        allowsResign = true
        NotificationCenter.default.post(name: dismissNotification, object: nil)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        allowsResign = false
        DispatchQueue.main.async { inFlight = false }
    }

    static func shouldAllowResign(window: UIWindow?) -> Bool {
        if allowsResign { return true }
        guard let window else { return false }
        return window.dsh_isScrollViewTracking
    }
}

extension View {
    /// iOS 16 `scrollDismissesKeyboard(.immediately)` plus a tap that does
    /// not cancel button hits (`cancelsTouchesInView = false`). `.interactively`
    /// only drops the IME when the drag reaches the keyboard, so scrolling
    /// a transcript that is already at the bottom left it stuck (Round 58 CI).
    func dshDismissesKeyboardOnScrollAndTap() -> some View {
        self
            .scrollDismissesKeyboard(.immediately)
            .background(KeyboardDismissTapInstaller())
    }
}

/// Attaches to the scroll view this modifier decorates so tapping inside the
/// list resigns the composer without stealing pin / archive / message-action
/// taps. `.background` puts the probe beside the `UIScrollView`, not inside
/// it, so the target is the scroll view whose window frame matches the
/// probe. Never falls back to the window: a window-wide tap would also drop
/// the IME on Send, `+`, and slash-menu rows.
private struct KeyboardDismissTapInstaller: UIViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> ProbeView {
        let view = ProbeView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        let coordinator = context.coordinator
        view.onLayout = { [weak coordinator] probe in coordinator?.install(from: probe) }
        return view
    }

    func updateUIView(_ view: ProbeView, context: Context) {
        context.coordinator.install(from: view)
    }

    static func dismantleUIView(_ view: ProbeView, coordinator: Coordinator) {
        view.onLayout = nil
        coordinator.remove()
    }

    final class ProbeView: UIView {
        var onLayout: ((ProbeView) -> Void)?

        override func layoutSubviews() {
            super.layoutSubviews()
            onLayout?(self)
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            onLayout?(self)
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private weak var host: UIScrollView?
        private weak var recognizer: UITapGestureRecognizer?
        private var installing = false

        func install(from probe: UIView) {
            if recognizer != nil || installing { return }
            installing = true
            DispatchQueue.main.async { [weak self, weak probe] in
                guard let self else { return }
                defer { self.installing = false }
                if self.recognizer != nil { return }
                guard let probe, let host = Self.target(for: probe) else { return }
                let tap = UITapGestureRecognizer(target: self, action: #selector(self.tapped))
                tap.cancelsTouchesInView = false
                tap.delegate = self
                host.addGestureRecognizer(tap)
                self.host = host
                self.recognizer = tap
            }
        }

        private static func target(for probe: UIView) -> UIScrollView? {
            guard let window = probe.window else { return nil }
            let frame = probe.convert(probe.bounds, to: window)
            guard frame.width > 1, frame.height > 1 else { return nil }
            var match: UIScrollView?
            window.dsh_visitScrollViews { scroll in
                if scroll is UITextView { return }
                guard let parent = scroll.superview else { return }
                let candidate = parent.convert(scroll.frame, to: window)
                if abs(candidate.minX - frame.minX) < 1, abs(candidate.minY - frame.minY) < 1,
                   abs(candidate.width - frame.width) < 1, abs(candidate.height - frame.height) < 1 {
                    match = scroll
                }
            }
            return match
        }

        func remove() {
            if let recognizer, let host {
                host.removeGestureRecognizer(recognizer)
            }
            recognizer = nil
            host = nil
        }

        @objc private func tapped() {
            Keyboard.dismiss()
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            var view = touch.view
            while let current = view {
                if current is UITextView || current is UITextField { return false }
                view = current.superview
            }
            return true
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}

private extension UIView {
    var dsh_isScrollViewTracking: Bool {
        if let scroll = self as? UIScrollView, scroll.isTracking || scroll.isDragging || scroll.isDecelerating {
            return true
        }
        return subviews.contains { $0.dsh_isScrollViewTracking }
    }

    func dsh_visitScrollViews(_ visit: (UIScrollView) -> Void) {
        if let scroll = self as? UIScrollView { visit(scroll) }
        for sub in subviews { sub.dsh_visitScrollViews(visit) }
    }
}
