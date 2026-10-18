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
    /// iOS 16 `scrollDismissesKeyboard(.interactively)` plus a tap that does
    /// not cancel button hits (`cancelsTouchesInView = false`).
    func dshDismissesKeyboardOnScrollAndTap() -> some View {
        self
            .scrollDismissesKeyboard(.interactively)
            .background(KeyboardDismissTapInstaller())
    }
}

/// Attaches to the enclosing scroll view (or window) so tapping blank space
/// resigns the composer without stealing pin / archive / message-action taps.
private struct KeyboardDismissTapInstaller: UIViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        context.coordinator.install(from: view)
    }

    static func dismantleUIView(_ view: UIView, coordinator: Coordinator) {
        coordinator.remove()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private weak var host: UIView?
        private weak var recognizer: UITapGestureRecognizer?
        private var installing = false

        func install(from probe: UIView) {
            if recognizer != nil || installing { return }
            installing = true
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                defer { self.installing = false }
                if self.recognizer != nil { return }
                let host = probe.dsh_enclosingScrollView ?? probe.window
                guard let host else { return }
                let tap = UITapGestureRecognizer(target: self, action: #selector(tapped))
                tap.cancelsTouchesInView = false
                tap.delegate = self
                host.addGestureRecognizer(tap)
                self.host = host
                self.recognizer = tap
            }
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

    var dsh_enclosingScrollView: UIScrollView? {
        var view: UIView? = self
        while let current = view {
            if let scroll = current as? UIScrollView { return scroll }
            view = current.superview
        }
        return nil
    }
}
