import Foundation

public struct ComposerTrigger: Equatable, Sendable {
    public var kind: Character
    public var start: Int
    public var end: Int
    public var query: String
    public var quoted: Bool

    public init(kind: Character, start: Int, end: Int, query: String, quoted: Bool = false) {
        self.kind = kind
        self.start = start
        self.end = end
        self.query = query
        self.quoted = quoted
    }
}

public struct ComposerReference: Equatable, Sendable {
    public var start: Int
    public var end: Int
    public var canonical: String
    public var label: String
    public var kind: ComposerReferenceKind
    public var path: String?

    public init(start: Int, end: Int, canonical: String, label: String, kind: ComposerReferenceKind, path: String? = nil) {
        self.start = start
        self.end = end
        self.canonical = canonical
        self.label = label
        self.kind = kind
        self.path = path
    }
}

public enum ComposerReferenceKind: String, Sendable {
    case file, directory, session
}

private let quotedReferenceTrigger = try! NSRegularExpression(pattern: #"(?:^|\s)(@"([^"]*))$"#)
private let completedSessionMention = try! NSRegularExpression(pattern: #"@\[(?:\\.|[^\\\]])*\]\(dsh-session:[A-Za-z0-9_-]+\)"#)
private let referencePattern = try! NSRegularExpression(
    pattern: #"(?<!\S)@(?:\[((?:\\.|[^\\\]])*)\]\((dsh-session:[A-Za-z0-9_-]+)\)|"([^"\r\n]+)"|([^\s"\u0000-\u001f\u007f-\u009f]+))"#
)

/// Trigger only a token at the caret, never an email address or a slash inside a path.
public func composerTrigger(_ text: String, cursor: Int) -> ComposerTrigger? {
    let end = max(0, min(cursor, text.count))
    let prefix = substring(text, 0, end)
    let nsPrefix = prefix as NSString
    let prefixRange = NSRange(location: 0, length: nsPrefix.length)
    let caretUtf16 = nsPrefix.length
    let sessionHits = completedSessionMention.matches(in: prefix, options: [], range: prefixRange)
    if sessionHits.contains(where: { hit in
        let hitEnd = hit.range.location + hit.range.length
        return caretUtf16 > hit.range.location && caretUtf16 <= hitEnd
    }) {
        return nil
    }
    if let match = quotedReferenceTrigger.firstMatch(in: prefix, options: [], range: prefixRange),
       match.numberOfRanges >= 3,
       let token = nsString(prefix, match.range(at: 1)),
       let query = nsString(prefix, match.range(at: 2)) {
        return ComposerTrigger(kind: Character("@"), start: end - token.count, end: end, query: query, quoted: true)
    }
    var start = end
    while start > 0 && !isWhitespace(text, start - 1) { start -= 1 }
    if start == end { return nil }
    let kind = character(text, start)
    if kind != Character("@") && kind != Character("/") { return nil }
    if kind == Character("/") && !substring(text, 0, start).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return nil }
    let rest = substring(text, start + 1, end)
    if kind == Character("@") && (rest.hasPrefix("[") || rest.contains("\"")) { return nil }
    return ComposerTrigger(kind: kind, start: start, end: end, query: rest)
}

public func replaceComposerToken(
    _ text: String,
    cursor: Int,
    token: String,
    selectionStart: Int? = nil,
    appendSpace: Bool = true
) -> (text: String, cursor: Int) {
    let at = min(cursor, selectionStart ?? cursor)
    let clampedAt = max(0, min(at, text.count))
    let selectedEnd = max(0, min(max(cursor, selectionStart ?? cursor), text.count))
    let trigger = composerTrigger(text, cursor: clampedAt)
    let start = trigger?.start ?? clampedAt
    var end = max(trigger?.end ?? clampedAt, selectedEnd)
    if trigger?.quoted == true {
        let after = substring(text, trigger!.end, text.count)
        if let quote = after.firstIndex(of: "\"") {
            end = max(end, trigger!.end + after.distance(from: after.startIndex, to: quote) + 1)
        } else if let newline = after.firstIndex(of: "\n") {
            end = max(end, trigger!.end + after.distance(from: after.startIndex, to: newline))
        } else {
            end = max(end, text.count)
        }
    } else if trigger != nil {
        while end < text.count && !isWhitespace(text, end) { end += 1 }
    }
    let inserted: String
    if token.isEmpty {
        inserted = ""
    } else if token.hasPrefix("/") {
        inserted = token + ((!appendSpace || token.hasSuffix(" ")) ? "" : " ")
    } else {
        inserted = "@" + token.drop(while: { $0 == "@" }) + (appendSpace ? " " : "")
    }
    let result = substring(text, 0, start) + inserted + substring(text, end, text.count)
    return (result, start + inserted.count)
}

/// Match the official browser-safe file-reference grammar; unrepresentable paths are not candidates.
public func fileReferenceToken(_ path: String, directory: Bool, preserveQuote: Bool = false) -> String? {
    if path.contains("\"") || path.unicodeScalars.contains(where: { $0.value <= 31 || (127...159).contains($0.value) }) {
        return nil
    }
    let trimmed = path.hasSuffix("/") ? String(path.dropLast()) : path
    let value = trimmed + (directory ? "/" : "")
    return (preserveQuote || value.contains(where: \.isWhitespace)) ? "@\"\(value)\"" : "@\(value)"
}

public func composerReferences(_ text: String) -> [ComposerReference] {
    let ns = text as NSString
    let matches = referencePattern.matches(in: text, options: [], range: NSRange(location: 0, length: ns.length))
    return matches.compactMap { match -> ComposerReference? in
        let start = utf16ToOffset(text, match.range.location)
        let end = utf16ToOffset(text, match.range.location + match.range.length)
        let canonical = ns.substring(with: match.range)
        if match.numberOfRanges > 2, match.range(at: 2).location != NSNotFound {
            let title = unescapeReferenceLabel(nsString(text, match.range(at: 1)) ?? "")
            return ComposerReference(start: start, end: end, canonical: canonical, label: title, kind: .session)
        }
        if match.numberOfRanges > 3, match.range(at: 3).location != NSNotFound {
            let path = nsString(text, match.range(at: 3)) ?? ""
            return ComposerReference(
                start: start, end: end, canonical: canonical,
                label: mentionFileLabel(path),
                kind: path.hasSuffix("/") ? .directory : .file,
                path: path
            )
        }
        if match.numberOfRanges > 4, match.range(at: 4).location != NSNotFound {
            let path = nsString(text, match.range(at: 4)) ?? ""
            return ComposerReference(
                start: start, end: end, canonical: canonical,
                label: mentionFileLabel(path),
                kind: path.hasSuffix("/") ? .directory : .file,
                path: path
            )
        }
        return nil
    }
}

public func mentionFileRowLabel(_ path: String, directory: Bool) -> String {
    let trimmed = path.hasSuffix("/") ? String(path.dropLast()) : path
    let name = trimmed.split(separator: "/").last.map(String.init) ?? trimmed
    return directory ? name + "/" : name
}

private func mentionFileLabel(_ path: String) -> String {
    mentionFileRowLabel(path, directory: path.hasSuffix("/"))
}

private func unescapeReferenceLabel(_ value: String) -> String {
    value.replacingOccurrences(of: "\\", with: "")
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

private func nsString(_ text: String, _ range: NSRange) -> String? {
    if range.location == NSNotFound { return nil }
    return (text as NSString).substring(with: range)
}

private func utf16ToOffset(_ text: String, _ utf16: Int) -> Int {
    let idx = String.Index(utf16Offset: min(utf16, text.utf16.count), in: text)
    return text.distance(from: text.startIndex, to: idx)
}
