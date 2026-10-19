import Foundation

/// Gate for UIKit `markedTextRange`. While composing, rewriting
/// `text` / `attributedText` / `selectedRange` or parsing `@` mentions
/// commits the marked text and hides the CJK candidate bar.
public enum ImeComposition {
    public static func shouldRewriteText(isMarked: Bool) -> Bool {
        !isMarked
    }

    public static func shouldParseMentions(isMarked: Bool) -> Bool {
        !isMarked
    }

    /// First Pinyin letter arrives with `markedTextRange == nil`.
    /// Intercepting a non-empty replacement (`return false` + set text)
    /// prevents IME from starting. Deletions may still be intercepted
    /// for atomic mention chips. Return is intercepted only for menus.
    public static func shouldLetSystemApplyReplacement(
        isMarked: Bool,
        replacement: String,
        interceptReturn: Bool
    ) -> Bool {
        if isMarked { return true }
        if interceptReturn && replacement == "\n" { return false }
        return !replacement.isEmpty
    }
}

public enum ComposerImeError: Error, Equatable, Sendable {
    case rewriteWhileComposing
}

/// Testable composer IME + mention pipeline. UIKit `setMarkedText` /
/// `unmarkText` map onto these methods. Mention parsing and chip
/// projection read only committed text; marked letters stay out of
/// the wire draft until composition ends.
public struct ComposerImeSession: Equatable, Sendable {
    public private(set) var committedText: String
    public private(set) var cursor: Int
    public private(set) var markedText: String?

    public init(text: String = "", cursor: Int? = nil) {
        committedText = text
        self.cursor = cursor ?? text.count
        markedText = nil
    }

    public var isComposing: Bool { markedText != nil }

    public var visibleText: String {
        guard let markedText else { return committedText }
        return slice(committedText, 0, cursor) + markedText + slice(committedText, cursor, committedText.count)
    }

    public var projection: MentionProjection {
        mentionProjection(committedText, cursor: cursor)
    }

    public var mentionQuery: String? {
        guard ImeComposition.shouldParseMentions(isMarked: isComposing) else { return nil }
        return mentionMenuTrigger(committedText, cursor: cursor)?.query
    }

    public mutating func setMarkedText(_ text: String) {
        markedText = text
    }

    public mutating func unmarkText() {
        guard let marked = markedText else { return }
        committedText = slice(committedText, 0, cursor) + marked + slice(committedText, cursor, committedText.count)
        cursor += marked.count
        markedText = nil
    }

    public mutating func applyCommitted(text: String, cursor: Int) throws {
        guard ImeComposition.shouldRewriteText(isMarked: isComposing) else {
            throw ComposerImeError.rewriteWhileComposing
        }
        committedText = text
        self.cursor = cursor
    }
}

private func slice(_ text: String, _ start: Int, _ end: Int) -> String {
    if start >= end || start >= text.count { return "" }
    let lower = text.index(text.startIndex, offsetBy: max(0, start))
    let upper = text.index(text.startIndex, offsetBy: min(text.count, end))
    return String(text[lower..<upper])
}
