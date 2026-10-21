import SwiftUI
import UIKit

/// Touch adaptation: only the current row reveals; losing selection restores plain text.
struct SessionRecordTitle: View {
    let sessionId: String
    let title: String
    let color: Color
    let enabled: Bool
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        if enabled, scenePhase == .active {
            SessionRecordMarquee(sessionId: sessionId, title: title, color: color)
        } else {
            Text(title)
                .font(.body)
                .foregroundStyle(color)
                .lineLimit(1)
                .truncationMode(.tail)
                .accessibilityLabel(title)
                .accessibilityIdentifier("sessionRecordTitle.\(sessionId)")
                .accessibilityValue(UITestLaunch.isEnabled ? "resting" : "")
        }
    }
}

/// Core Animation moves only the label layer; no per-frame SwiftUI row layout.
private struct SessionRecordMarquee: UIViewRepresentable {
    let sessionId: String
    let title: String
    let color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.sizeCategory) private var sizeCategory

    func makeUIView(context: Context) -> SessionRecordTitleView { SessionRecordTitleView() }

    func updateUIView(_ view: SessionRecordTitleView, context: Context) {
        view.configure(
            sessionId: sessionId,
            title: title,
            color: UIColor(color),
            font: UIFont.preferredFont(forTextStyle: .body),
            reduceMotion: reduceMotion || UITestLaunch.sessionTitleReduceMotion
        )
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: SessionRecordTitleView, context: Context) -> CGSize? {
        let size = uiView.titleSize
        let proposed = proposal.width ?? size.width
        return CGSize(width: max(0, min(proposed, size.width)), height: size.height)
    }

    static func dismantleUIView(_ view: SessionRecordTitleView, coordinator: ()) { view.stopReveal() }
}

final class SessionRecordTitleView: UIView, CAAnimationDelegate {
    private let label = UILabel()
    private let fade = CAGradientLayer()
    private var sessionId = ""
    private var reduceMotion = false
    private var needsReveal = true
    private var lastSize = CGSize.zero
    private var generation = 0

    var titleSize: CGSize {
        label.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isAccessibilityElement = true
        accessibilityTraits = .staticText
        label.numberOfLines = 1
        label.lineBreakMode = .byClipping
        label.isAccessibilityElement = false
        addSubview(label)
        clipsToBounds = true
        fade.startPoint = CGPoint(x: 0, y: 0.5)
        fade.endPoint = CGPoint(x: 1, y: 0.5)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(sessionId: String, title: String, color: UIColor, font: UIFont, reduceMotion: Bool) {
        let changed = self.sessionId != sessionId || label.text != title || label.font != font
            || self.reduceMotion != reduceMotion
        self.sessionId = sessionId
        self.reduceMotion = reduceMotion
        label.text = title
        label.textColor = color
        label.font = font
        accessibilityLabel = title
        accessibilityIdentifier = "sessionRecordTitle.\(sessionId)"
        if changed {
            stopReveal()
            needsReveal = true
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    override var intrinsicContentSize: CGSize { titleSize }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        stopReveal()
        needsReveal = true
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if bounds.size != lastSize {
            stopReveal()
            lastSize = bounds.size
            needsReveal = true
        }
        guard needsReveal else { return }
        needsReveal = false
        let size = titleSize
        label.frame = CGRect(origin: .zero, size: CGSize(width: max(size.width, bounds.width), height: bounds.height))
        guard window != nil, bounds.width > 0 else { return }
        let range = max(0, size.width - bounds.width)
        guard range > 8 else {
            label.lineBreakMode = .byTruncatingTail
            label.frame.size.width = bounds.width
            setRevealState("resting")
            return
        }
        label.lineBreakMode = .byClipping
        fade.frame = bounds
        let edge = min(12 / bounds.width, 0.5)
        fade.locations = [0, NSNumber(value: Double(edge)), NSNumber(value: Double(1 - edge)), 1]
        layer.mask = fade
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        fade.colors = [UIColor.clear.cgColor, UIColor.black.cgColor, UIColor.black.cgColor, UIColor.black.cgColor]
        label.transform = CGAffineTransform(translationX: -range, y: 0)
        CATransaction.commit()
        guard !reduceMotion else {
            setRevealState("reducedMotion")
            return
        }
        fade.colors = [UIColor.clear.cgColor, UIColor.black.cgColor, UIColor.black.cgColor, UIColor.clear.cgColor]
        let animation = CABasicAnimation(keyPath: "transform.translation.x")
        animation.fromValue = 0
        animation.toValue = -range
        animation.duration = Double(range / 30)
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.delegate = self
        animation.setValue(generation, forKey: "generation")
        label.layer.add(animation, forKey: "titleReveal")
        setRevealState("moving")
    }

    func stopReveal() {
        generation += 1
        label.layer.removeAnimation(forKey: "titleReveal")
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        label.transform = .identity
        layer.mask = nil
        CATransaction.commit()
        setRevealState("resting")
    }

    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        guard flag, (anim.value(forKey: "generation") as? Int) == generation else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        fade.colors = [UIColor.clear.cgColor, UIColor.black.cgColor, UIColor.black.cgColor, UIColor.black.cgColor]
        CATransaction.commit()
        setRevealState("revealed")
    }

    private func setRevealState(_ state: String) {
        if UITestLaunch.isEnabled { accessibilityValue = state }
    }
}
