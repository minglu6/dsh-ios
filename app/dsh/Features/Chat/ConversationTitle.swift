import SwiftUI
import UIKit

/// Touch counterpart of the desktop full-title hover content. A UIKit popover
/// keeps the title anchored even on iOS 16.0–16.3, where SwiftUI adapts to a sheet.
struct ConversationTitle: UIViewRepresentable {
    let sessionId: String
    let title: String
    var color: Color = T.ink

    func makeUIView(context: Context) -> ConversationTitleButton {
        ConversationTitleButton(frame: .zero)
    }

    func updateUIView(_ view: ConversationTitleButton, context: Context) {
        view.configure(sessionId: sessionId, title: title, color: UIColor(color))
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: ConversationTitleButton, context: Context) -> CGSize? {
        let intrinsic = uiView.intrinsicContentSize
        return CGSize(width: min(proposal.width ?? intrinsic.width, intrinsic.width), height: intrinsic.height)
    }

    static func dismantleUIView(_ view: ConversationTitleButton, coordinator: ()) {
        view.dismissTitle()
    }
}

final class ConversationTitleButton: UIButton, UIPopoverPresentationControllerDelegate {
    private var sessionId = ""
    private var fullTitle = ""
    private weak var titlePopover: UIViewController?

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentHorizontalAlignment = .leading
        titleLabel?.lineBreakMode = .byTruncatingTail
        titleLabel?.numberOfLines = 1
        titleLabel?.adjustsFontForContentSizeCategory = true
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        accessibilityIdentifier = "conversationHeaderTitle"
        addTarget(self, action: #selector(toggleTitle), for: .touchUpInside)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(sessionId: String, title: String, color: UIColor) {
        if self.sessionId != sessionId || fullTitle != title { dismissTitle() }
        self.sessionId = sessionId
        fullTitle = title
        if self.title(for: .normal) != title { setTitle(title, for: .normal) }
        titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        setTitleColor(color, for: .normal)
        accessibilityLabel = title
        accessibilityHint = L.t("查看会话完整标题", "Show full conversation title")
        invalidateIntrinsicContentSize()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { dismissTitle() }
    }

    func dismissTitle() {
        titlePopover?.dismiss(animated: false)
        titlePopover = nil
    }

    @objc private func toggleTitle() {
        if titlePopover != nil {
            dismissTitle()
            return
        }
        var responder: UIResponder? = self
        while responder != nil, !(responder is UIViewController) { responder = responder?.next }
        guard let presenter = responder as? UIViewController, presenter.presentedViewController == nil else { return }
        let detail = FullConversationTitleController(title: fullTitle, availableSize: window?.bounds.size ?? bounds.size)
        detail.loadViewIfNeeded()
        detail.modalPresentationStyle = .popover
        guard let popover = detail.popoverPresentationController else { return }
        popover.sourceView = self
        popover.sourceRect = bounds
        popover.permittedArrowDirections = [.up, .down]
        popover.backgroundColor = UIColor(T.tooltipBg)
        popover.delegate = self
        titlePopover = detail
        presenter.present(detail, animated: !UIAccessibility.isReduceMotionEnabled)
    }

    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle { .none }

    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle { .none }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        titlePopover = nil
    }
}

private final class FullConversationTitleController: UIViewController {
    private let fullTitle: String
    private let availableSize: CGSize

    init(title: String, availableSize: CGSize) {
        fullTitle = title
        self.availableSize = availableSize
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(T.tooltipBg)
        view.accessibilityIdentifier = "conversationTitlePopover"
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        let label = UILabel()
        label.text = fullTitle
        label.font = UIFontMetrics(forTextStyle: .subheadline).scaledFont(for: .systemFont(ofSize: 14))
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        label.lineBreakMode = .byCharWrapping
        label.textColor = .white
        label.accessibilityLabel = fullTitle
        label.accessibilityIdentifier = "conversationTitleFull"
        label.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(label)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: view.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            label.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -16),
            label.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 12),
            label.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -12),
            label.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -32),
        ])
        let width = min(244, max(1, availableSize.width - 32))
        let height = label.sizeThatFits(CGSize(width: max(1, width - 32), height: .greatestFiniteMagnitude)).height + 24
        preferredContentSize = CGSize(width: width, height: min(height, max(1, availableSize.height - 80)))
    }
}
