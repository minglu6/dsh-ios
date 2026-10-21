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

final class SessionRecordTitleView: UIView {
    private let label = UILabel()
    private let fade = CAGradientLayer()
    private var sessionId = ""
    private var reduceMotion = false
    private var needsReveal = true
    private var lastSize = CGSize.zero

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

    // UI tests sample the actual presentation layer, not animation configuration alone.
    override var accessibilityValue: String? {
        get {
            guard UITestLaunch.isEnabled else { return super.accessibilityValue }
            let offset = label.layer.presentation()?.transform.m41 ?? label.layer.transform.m41
            let range = max(0, label.bounds.width - bounds.width)
            let duration = label.layer.animation(forKey: "titleReveal")?.duration ?? 0
            return "\(super.accessibilityValue ?? "resting")|\(offset)|\(range)|\(duration)"
        }
        set { super.accessibilityValue = newValue }
    }

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
        let head = [UIColor.black.cgColor, UIColor.black.cgColor, UIColor.black.cgColor, UIColor.clear.cgColor]
        let tail = [UIColor.clear.cgColor, UIColor.black.cgColor, UIColor.black.cgColor, UIColor.black.cgColor]
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        fade.colors = reduceMotion ? tail : head
        label.transform = reduceMotion ? CGAffineTransform(translationX: -range, y: 0) : .identity
        CATransaction.commit()
        guard !reduceMotion else {
            setRevealState("reducedMotion")
            return
        }
        let pause = 0.75
        let travel = Double(range / 30)
        let duration = travel + 2 * pause
        let keyTimes: [NSNumber] = [0, NSNumber(value: pause / duration), NSNumber(value: (pause + travel) / duration), 1]
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.values = [0, 0, -range, -range]
        animation.keyTimes = keyTimes
        animation.duration = duration
        animation.calculationMode = .linear
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.repeatCount = .infinity
        let maskAnimation = CAKeyframeAnimation(keyPath: "colors")
        maskAnimation.values = [head, head, tail, tail]
        maskAnimation.keyTimes = keyTimes
        maskAnimation.duration = duration
        maskAnimation.calculationMode = .linear
        maskAnimation.timingFunction = CAMediaTimingFunction(name: .linear)
        maskAnimation.repeatCount = .infinity
        // The model stays at the beginning; both layers wrap together after the tail pause.
        CATransaction.begin()
        label.layer.add(animation, forKey: "titleReveal")
        fade.add(maskAnimation, forKey: "titleReveal")
        CATransaction.commit()
        setRevealState("moving")
    }

    func stopReveal() {
        label.layer.removeAnimation(forKey: "titleReveal")
        fade.removeAnimation(forKey: "titleReveal")
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        label.transform = .identity
        layer.mask = nil
        CATransaction.commit()
        setRevealState("resting")
    }


    private func setRevealState(_ state: String) {
        if UITestLaunch.isEnabled { accessibilityValue = state }
    }
}
