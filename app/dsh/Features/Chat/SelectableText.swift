import SwiftUI
import UIKit

/// SwiftUI Text only offers whole-view copying on iOS 16–26.
struct SelectableText: UIViewRepresentable {
    let attributedText: NSAttributedString
    var identifier = "selectableText"
    @Environment(\.openURL) private var openURL
    init(attributedText: NSAttributedString, identifier: String = "selectableText") {
        self.attributedText = attributedText
        self.identifier = identifier
    }

    init(_ text: String, font: UIFont, color: UIColor, identifier: String = "selectableText") {
        self.init(attributedText: NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color]), identifier: identifier)
    }

    func makeCoordinator() -> Coordinator { Coordinator(openURL: openURL) }

    func makeUIView(context: Context) -> SelectableUITextView {
        let view = SelectableUITextView()
        view.delegate = context.coordinator
        return view
    }

    func updateUIView(_ view: SelectableUITextView, context: Context) {
        context.coordinator.openURL = openURL
        view.accessibilityIdentifier = identifier
        view.apply(attributedText)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: SelectableUITextView, context: Context) -> CGSize? {
        uiView.fittingSize(width: proposal.width)
    }

    @MainActor final class Coordinator: NSObject, UITextViewDelegate {
        var openURL: OpenURLAction

        init(openURL: OpenURLAction) { self.openURL = openURL }

        func textView(
            _ textView: UITextView,
            shouldInteractWith URL: URL,
            in characterRange: NSRange,
            interaction: UITextItemInteraction
        ) -> Bool {
            guard interaction == .invokeDefaultAction else { return true }
            openURL(URL)
            return false
        }
    }
}

@MainActor final class SelectableUITextView: UITextView {
    private var measuredWidth: CGFloat?
    private var measuredSize: CGSize?

    init() {
        super.init(frame: .zero, textContainer: nil)
        isEditable = false
        isSelectable = true
        isScrollEnabled = false
        backgroundColor = .clear
        textContainerInset = .zero
        textContainer.lineFragmentPadding = 0
        textContainer.lineBreakMode = .byWordWrapping
        linkTextAttributes = [:]
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Mutate only changed characters. Unrelated streaming updates must not
    /// dismiss the system selection or move its handles to the new tail.
    func apply(_ content: NSAttributedString) {
        guard !textStorage.isEqual(to: content) else { return }
        let oldText = textStorage.string as NSString
        let newText = content.string as NSString
        let oldLength = oldText.length
        let newLength = newText.length
        var prefix = 0
        while prefix < min(oldLength, newLength), oldText.character(at: prefix) == newText.character(at: prefix) {
            prefix += 1
        }
        if prefix > 0 {
            let oldBoundary = oldText.rangeOfComposedCharacterSequence(at: prefix - 1)
            let newBoundary = newText.rangeOfComposedCharacterSequence(at: prefix - 1)
            if NSMaxRange(oldBoundary) > prefix || NSMaxRange(newBoundary) > prefix {
                prefix = min(oldBoundary.location, newBoundary.location)
            }
        }
        var suffix = 0
        while suffix < min(oldLength, newLength) - prefix,
              oldText.character(at: oldLength - suffix - 1) == newText.character(at: newLength - suffix - 1) {
            suffix += 1
        }
        while suffix > 0 {
            let oldStart = oldLength - suffix
            let newStart = newLength - suffix
            let oldBoundary = oldText.rangeOfComposedCharacterSequence(at: oldStart)
            let newBoundary = newText.rangeOfComposedCharacterSequence(at: newStart)
            let oldSkip = oldBoundary.location < oldStart ? NSMaxRange(oldBoundary) - oldStart : 0
            let newSkip = newBoundary.location < newStart ? NSMaxRange(newBoundary) - newStart : 0
            let skip = max(oldSkip, newSkip)
            if skip == 0 { break }
            suffix -= skip
        }
        let removed = NSRange(location: prefix, length: oldLength - prefix - suffix)
        let inserted = NSRange(location: prefix, length: newLength - prefix - suffix)
        let selection = selectedRange
        let nextSelection: NSRange
        if selection.location != NSNotFound {
            func mapped(_ offset: Int) -> Int {
                if offset <= prefix { return min(offset, newLength) }
                if offset >= NSMaxRange(removed) { return min(offset + inserted.length - removed.length, newLength) }
                return prefix + min(offset - prefix, inserted.length)
            }
            let start = mapped(selection.location)
            let end = mapped(NSMaxRange(selection))
            nextSelection = NSRange(location: start, length: max(0, end - start))
        } else {
            nextSelection = NSRange(location: 0, length: 0)
        }
        textStorage.beginEditing()
        if removed.length > 0 || inserted.length > 0 {
            textStorage.replaceCharacters(in: removed, with: content.attributedSubstring(from: inserted))
        }
        content.enumerateAttributes(in: NSRange(location: 0, length: newLength)) { attributes, range, _ in
            var cursor = range.location
            while cursor < NSMaxRange(range) {
                var existingRange = NSRange()
                let existing = textStorage.attributes(at: cursor, longestEffectiveRange: &existingRange, in: range)
                if !NSDictionary(dictionary: existing).isEqual(to: attributes) {
                    textStorage.setAttributes(attributes, range: existingRange)
                }
                cursor = NSMaxRange(existingRange)
            }
        }
        textStorage.endEditing()
        if selectedRange != nextSelection { selectedRange = nextSelection }
        measuredSize = nil
        invalidateIntrinsicContentSize()
    }

    func fittingSize(width: CGFloat?) -> CGSize {
        let available = width.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
        if measuredSize != nil, measuredWidth == available { return measuredSize! }
        let limit = available ?? CGFloat.greatestFiniteMagnitude
        let bounds = textStorage.boundingRect(
            with: CGSize(width: limit, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        let fittedWidth = min(limit, max(1, ceil(bounds.width)))
        let fitted = sizeThatFits(CGSize(width: fittedWidth, height: .greatestFiniteMagnitude))
        let result = CGSize(width: fittedWidth, height: ceil(fitted.height))
        measuredWidth = available
        measuredSize = result
        return result
    }
}
