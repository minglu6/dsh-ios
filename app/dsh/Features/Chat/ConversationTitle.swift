import SwiftUI
import UIKit
import DSHProtocol

/// Touch counterpart of the desktop full-title hover content. A UIKit popover
/// keeps the title anchored even on iOS 16.0–16.3, where SwiftUI adapts to a sheet.
struct ConversationTitle: UIViewRepresentable {
    let sessionId: String
    let title: String
    let metadata: ConversationTitleMetadata
    var color: Color = T.ink

    func makeUIView(context: Context) -> ConversationTitleButton {
        ConversationTitleButton(frame: .zero)
    }

    func updateUIView(_ view: ConversationTitleButton, context: Context) {
        view.configure(sessionId: sessionId, title: title, metadata: metadata, color: UIColor(color))
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
    private var metadata: ConversationTitleMetadata?
    private weak var titlePopover: FullConversationTitleController?

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

    func configure(sessionId: String, title: String, metadata: ConversationTitleMetadata, color: UIColor) {
        if self.sessionId != sessionId || fullTitle != title { dismissTitle() }
        self.sessionId = sessionId
        fullTitle = title
        self.metadata = metadata
        titlePopover?.update(metadata: metadata)
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
        guard let metadata else { return }
        let detail = FullConversationTitleController(title: fullTitle, metadata: metadata, availableSize: window?.bounds.size ?? bounds.size)
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
    private let scroll = UIScrollView()
    private let label = UILabel()
    private let timeLabel = UILabel()
    private let statusLabel = UILabel()
    private let stack = UIStackView()
    private var metadata: ConversationTitleMetadata

    init(title: String, metadata: ConversationTitleMetadata, availableSize: CGSize) {
        fullTitle = title
        self.metadata = metadata
        self.availableSize = availableSize
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(T.tooltipBg)
        view.accessibilityIdentifier = "conversationTitlePopover"
        scroll.contentInsetAdjustmentBehavior = .never
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        label.text = fullTitle
        label.font = UIFontMetrics(forTextStyle: .subheadline).scaledFont(for: .systemFont(ofSize: 14))
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.textColor = .white
        label.accessibilityLabel = fullTitle
        label.accessibilityIdentifier = "conversationTitleFull"
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(label)
        for (detail, identifier) in [(timeLabel, "conversationTitleTime"), (statusLabel, "conversationTitleStatus")] {
            detail.font = UIFontMetrics(forTextStyle: .caption1).scaledFont(for: .systemFont(ofSize: 12))
            detail.adjustsFontForContentSizeCategory = true
            detail.numberOfLines = 0
            detail.lineBreakMode = .byWordWrapping
            detail.textColor = UIColor.white.withAlphaComponent(0.8)
            detail.accessibilityIdentifier = identifier
            stack.addArrangedSubview(detail)
        }
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            // The popover's bounds include its arrow; text belongs inside the body.
            scroll.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -12),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -32),
        ])
        updateLabels()
        updatePreferredSize()
    }

    func update(metadata: ConversationTitleMetadata) {
        guard self.metadata != metadata else { return }
        self.metadata = metadata
        guard isViewLoaded else { return }
        updateLabels()
        updatePreferredSize()
    }

    private func updateLabels() {
        timeLabel.text = metadata.time
        timeLabel.isHidden = metadata.time == nil
        statusLabel.text = metadata.status
        statusLabel.isHidden = metadata.status == nil
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updatePreferredSize()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory {
            updatePreferredSize()
        }
    }

    private func updatePreferredSize() {
        let availableSize = presentingViewController?.view.window.map {
            $0.bounds.inset(by: $0.safeAreaInsets).size
        } ?? self.availableSize
        let maximumWidth = min(244, max(1, availableSize.width - 32))
        let visibleLabels = [label, timeLabel, statusLabel].filter { !$0.isHidden }
        let naturalWidth = visibleLabels.map {
            $0.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)).width
        }.max() ?? 0
        let width = min(maximumWidth, ceil(naturalWidth) + 32)
        let textWidth = scroll.bounds.width > 0 ? scroll.bounds.width - 32 : width - 32
        let height = visibleLabels.reduce(CGFloat(24)) {
            $0 + ceil($1.sizeThatFits(CGSize(width: max(1, textWidth), height: .greatestFiniteMagnitude)).height)
        } + CGFloat(max(0, visibleLabels.count - 1)) * stack.spacing
        let size = CGSize(width: width, height: min(height, max(1, availableSize.height - 80)))
        if preferredContentSize != size { preferredContentSize = size }
    }
}
