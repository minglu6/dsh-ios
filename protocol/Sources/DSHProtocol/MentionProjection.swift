import Foundation

public struct MentionDisplaySpan: Equatable, Sendable {
    public var reference: ComposerReference
    public var displayStart: Int
    public var displayEnd: Int

    public init(reference: ComposerReference, displayStart: Int, displayEnd: Int) {
        self.reference = reference
        self.displayStart = displayStart
        self.displayEnd = displayEnd
    }
}

public struct MentionProjection: Equatable, Sendable {
    public var original: String
    public var display: String
    public var references: [MentionDisplaySpan]

    public init(original: String, display: String, references: [MentionDisplaySpan]) {
        self.original = original
        self.display = display
        self.references = references
    }

    public func originalToDisplay(_ offset: Int) -> Int {
        let at = min(max(offset, 0), original.count)
        var delta = 0
        for span in references {
            let ref = span.reference
            if at <= ref.start { break }
            if at < ref.end { return at - ref.start < ref.end - at ? span.displayStart : span.displayEnd }
            delta += (span.displayEnd - span.displayStart) - (ref.end - ref.start)
        }
        return at + delta
    }

    public func displayToOriginal(_ offset: Int) -> Int {
        let at = min(max(offset, 0), display.count)
        var delta = 0
        for span in references {
            if at <= span.displayStart { break }
            if at < span.displayEnd {
                return at - span.displayStart < span.displayEnd - at ? span.reference.start : span.reference.end
            }
            delta += (span.reference.end - span.reference.start) - (span.displayEnd - span.displayStart)
        }
        return at + delta
    }
}

private struct MentionEdit {
    var start: Int
    var oldEnd: Int
    var newEnd: Int
}

private func mentionEdit(before: String, after: String) -> MentionEdit {
    var start = 0
    while start < before.count && start < after.count && character(before, start) == character(after, start) {
        start += 1
    }
    var oldEnd = before.count
    var newEnd = after.count
    while oldEnd > start && newEnd > start && character(before, oldEnd - 1) == character(after, newEnd - 1) {
        oldEnd -= 1
        newEnd -= 1
    }
    return MentionEdit(start: start, oldEnd: oldEnd, newEnd: newEnd)
}

/// Project committed `@` references to short chip labels. A live `@` query
/// stays editable text. Desktop / Android keep the wire draft as the canonical
/// `@[title](dsh-session:id)` / `@path` form.
public func mentionProjection(
    _ text: String,
    cursor: Int,
    previous: MentionProjection? = nil,
    composing: Range<Int>? = nil
) -> MentionProjection {
    let edit = previous.map { mentionEdit(before: $0.original, after: text) }
    let retained: [Int: String] = {
        guard let previous, let edit else { return [:] }
        var map: [Int: String] = [:]
        for span in previous.references {
            let ref = span.reference
            let nextStart: Int?
            if ref.end <= edit.start {
                nextStart = ref.start
            } else if ref.start >= edit.oldEnd {
                nextStart = ref.start + edit.newEnd - edit.oldEnd
            } else {
                nextStart = nil
            }
            if let nextStart { map[nextStart] = ref.canonical }
        }
        return map
    }()
    let active = composerTrigger(text, cursor: min(max(cursor, 0), text.count))?.takeIf { $0.kind == Character("@") }
    let refs = composerReferences(text)
    var spans: [MentionDisplaySpan] = []
    var display = ""
    var copied = 0
    for ref in refs {
        if ref.kind != .session, ref.path?.hasPrefix("[") == true { continue }
        if ref.kind != .session, ref.end < text.count, !isWhitespace(text, ref.end) { continue }
        if let active, active.start == ref.start, ref.kind != .session,
           (!active.quoted || ref.canonical.hasPrefix("@\"")),
           retained[ref.start] != ref.canonical {
            continue
        }
        if let composing, composing.lowerBound < ref.end && composing.upperBound > ref.start {
            continue
        }
        display += substring(text, copied, ref.start)
        let displayStart = display.count
        display += mentionChipDisplayLabel(ref)
        spans.append(MentionDisplaySpan(reference: ref, displayStart: displayStart, displayEnd: display.count))
        copied = ref.end
    }
    display += substring(text, copied, text.count)
    return MentionProjection(original: text, display: display, references: spans)
}

public func mentionChipDisplayLabel(_ ref: ComposerReference) -> String {
    ref.label
}

public func mentionNormalizeEdit(
    beforeText: String,
    beforeCursor: Int,
    beforeSelectionStart: Int,
    afterText: String,
    afterCursor: Int,
    afterSelectionStart: Int,
    projection: MentionProjection
) -> (text: String, cursor: Int, selectionStart: Int) {
    let refs = projection.references.map(\.reference)
    if beforeText == afterText {
        func boundary(_ at: Int, upper: Bool) -> Int {
            refs.first { at > $0.start && at < $0.end }.map { upper ? $0.end : $0.start } ?? at
        }
        if afterCursor == afterSelectionStart {
            let forward = afterCursor > beforeCursor
            let at = boundary(afterCursor, upper: forward)
            return (afterText, at, at)
        }
        let low = boundary(min(afterCursor, afterSelectionStart), upper: false)
        let high = boundary(max(afterCursor, afterSelectionStart), upper: true)
        if afterSelectionStart > afterCursor {
            return (afterText, low, high)
        }
        return (afterText, high, low)
    }
    let selectionMin = min(beforeCursor, beforeSelectionStart)
    let selectionMax = max(beforeCursor, beforeSelectionStart)
    let suffixLength = beforeText.count - selectionMax
    let replacesSelection = selectionMin != selectionMax
        && afterText.count >= selectionMin + suffixLength
        && afterText.hasPrefix(substring(beforeText, 0, selectionMin))
        && afterText.hasSuffix(substring(beforeText, selectionMax, beforeText.count))
    let edit = replacesSelection
        ? MentionEdit(start: selectionMin, oldEnd: selectionMax, newEnd: afterText.count - suffixLength)
        : mentionEdit(before: beforeText, after: afterText)
    var start = edit.start
    var end = edit.oldEnd
    for ref in refs {
        let overlaps = edit.start == edit.oldEnd
            ? edit.start > ref.start && edit.start < ref.end
            : ref.start < edit.oldEnd && ref.end > edit.start
        if overlaps {
            start = min(start, ref.start)
            end = max(end, ref.end)
        }
    }
    let inserted = substring(afterText, edit.start, edit.newEnd)
    if start == edit.start && end == edit.oldEnd {
        if edit.start == edit.oldEnd && !inserted.isEmpty {
            let leading = !inserted.first!.isWhitespace && refs.contains(where: { $0.end == start }) ? " " : ""
            let trailing = !inserted.last!.isWhitespace && refs.contains(where: { $0.start == start }) ? " " : ""
            if !leading.isEmpty || !trailing.isEmpty {
                func moved(_ at: Int) -> Int {
                    if at < edit.start { return at }
                    if at <= edit.newEnd { return at + leading.count }
                    return at + leading.count + trailing.count
                }
                return (
                    substring(beforeText, 0, start) + leading + inserted + trailing + substring(beforeText, end, beforeText.count),
                    moved(afterCursor),
                    moved(afterSelectionStart)
                )
            }
        }
        return (afterText, afterCursor, afterSelectionStart)
    }
    let text = substring(beforeText, 0, start) + inserted + substring(beforeText, end, beforeText.count)
    func mapped(_ at: Int) -> Int {
        let value: Int
        if at <= edit.start {
            value = min(at, start)
        } else if at < edit.newEnd {
            value = start + at - edit.start
        } else {
            value = start + inserted.count + max(0, at - edit.newEnd - (end - edit.oldEnd))
        }
        return min(max(value, 0), text.count)
    }
    return (text, mapped(afterCursor), mapped(afterSelectionStart))
}

public func mentionKeyEdit(
    text: String,
    cursor: Int,
    selectionStart: Int,
    projection: MentionProjection,
    backspace: Bool,
    deleteForward: Bool,
    moveLeft: Bool,
    moveRight: Bool,
    shift: Bool
) -> (text: String, cursor: Int, selectionStart: Int)? {
    let collapsed = cursor == selectionStart
    if !collapsed && !shift && (moveLeft || moveRight) { return nil }
    if (backspace || deleteForward) && (!collapsed || shift) { return nil }
    let caret = cursor
    let backwards = moveLeft || backspace
    let ref = projection.references.first {
        backwards ? $0.reference.end == caret : $0.reference.start == caret
    }?.reference
    guard let ref else { return nil }
    if backspace || deleteForward {
        let next = substring(text, 0, ref.start) + substring(text, ref.end, text.count)
        return (next, ref.start, ref.start)
    }
    let target = backwards ? ref.start : ref.end
    return (text, target, shift ? selectionStart : target)
}

private extension ComposerTrigger {
    func takeIf(_ predicate: (ComposerTrigger) -> Bool) -> ComposerTrigger? {
        predicate(self) ? self : nil
    }
}

private func substring(_ text: String, _ start: Int, _ end: Int) -> String {
    if start >= end || start >= text.count { return "" }
    let lower = text.index(text.startIndex, offsetBy: max(0, start))
    let upper = text.index(text.startIndex, offsetBy: min(text.count, end))
    return String(text[lower..<upper])
}

private func character(_ text: String, _ index: Int) -> Character {
    text[text.index(text.startIndex, offsetBy: index)]
}

private func isWhitespace(_ text: String, _ index: Int) -> Bool {
    character(text, index).isWhitespace
}
