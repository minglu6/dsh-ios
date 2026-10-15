import Foundation

public enum MdBlock: Equatable, Sendable {
    case paragraph([MdSpan])
    case heading(level: Int, spans: [MdSpan])
    case bulletList(items: [[MdBlock]], tight: Bool)
    case orderedList(items: [[MdBlock]], start: Int, tight: Bool)
    case quote([MdBlock])
    case code(language: String?, literal: String, incomplete: Bool)
    case table(headers: [[[MdSpan]]], rows: [[[MdSpan]]])
    case rule
}

public enum MdSpan: Equatable, Sendable {
    case text(String, bold: Bool, italic: Bool)
    case code(String)
    case link(text: String, dest: String)
    case fileChip(path: String, label: String)
}

public let sampleMarkdown = """
**模型配置** (来自 [cordis.patch.yml](cordis.patch.yml))：

| 配置项 | 值 |
| --- | --- |
| Provider | `qoder-cn` |
| Model | `auto` |
| Reasoning | `high` |
| VPC Instance | `sungrow-of-enterprise` |

解读：

- `model: auto` —— 由路由自动选择模型
- `provider: qoder-cn` —— 国内提供方
- `reasoningEffort` 为 `high`

当 `model` 为 `auto` 时，`reasoningEffort` 影响深度。
"""

public func parseMarkdown(_ source: String, streaming: Bool = false) -> [MdBlock] {
    if source.isEmpty { return [] }
    let split = splitStreamingFence(source, streaming: streaming)
    var parser = MarkdownBlockParser(split.stable.isEmpty ? "\n" : split.stable)
    var blocks = parser.parseBlocks()
    if let live = split.liveFence {
        let firstLineEnd = live.firstIndex(of: "\n")
        let langLine = firstLineEnd.map { String(live[..<$0]) } ?? live
        let lang = langLine.trimmingCharacters(in: .whitespaces)
        let language = (!lang.isEmpty && !lang.contains(" ") && firstLineEnd != nil) ? lang : nil
        let body = firstLineEnd.map { String(live[live.index(after: $0)...]) } ?? live
        blocks.append(.code(language: language, literal: body, incomplete: true))
    }
    return blocks
}

public func splitStreamingFence(_ source: String, streaming: Bool) -> (stable: String, liveFence: String?) {
    if !streaming { return (source, nil) }
    var i = source.startIndex
    var openAt: String.Index?
    while i < source.endIndex {
        if source[i...].hasPrefix("```") && (i == source.startIndex || source[source.index(before: i)] == "\n") {
            let lineEnd = source[i...].firstIndex(of: "\n") ?? source.endIndex
            if openAt == nil {
                openAt = i
                i = lineEnd == source.endIndex ? source.endIndex : source.index(after: lineEnd)
            } else {
                openAt = nil
                i = lineEnd == source.endIndex ? source.endIndex : source.index(after: lineEnd)
            }
        } else if let next = source[i...].firstIndex(of: "\n") {
            i = source.index(after: next)
        } else {
            i = source.endIndex
        }
    }
    guard let open = openAt else { return (source, nil) }
    let fenceStart = source.index(open, offsetBy: 3, limitedBy: source.endIndex) ?? source.endIndex
    let fenceBody = String(source[fenceStart...])
    return (String(source[..<open]).trimmingCharacters(in: .whitespacesAndNewlines), fenceBody)
}

public func parseFileLink(_ destination: String) -> String? {
    let dest: String
    if let hash = destination.firstIndex(of: "#") {
        dest = String(destination[..<hash])
    } else {
        dest = destination
    }
    if dest.contains("?") { return nil }
    guard let path = dest.removingPercentEncoding, !path.isEmpty else { return nil }
    if path.unicodeScalars.contains(where: { $0.value <= 0x1F || $0.value == 0x7F }) { return nil }
    if path.hasPrefix("//") || path.hasPrefix("\\\\") { return nil }
    let scheme = try! NSRegularExpression(pattern: #"^[a-z][a-z\d+.-]*:"#, options: [.caseInsensitive])
    let windows = try! NSRegularExpression(pattern: #"^[a-z]:[\\/]"#, options: [.caseInsensitive])
    let nsPath = path as NSString
    if scheme.firstMatch(in: path, range: NSRange(location: 0, length: nsPath.length)) != nil,
       windows.firstMatch(in: path, range: NSRange(location: 0, length: nsPath.length)) == nil {
        return nil
    }
    return path
}

public struct HighlightSpan: Equatable, Sendable {
    public var range: Range<Int>
    public var kind: String
}

public struct HighlightedCode: Equatable, Sendable {
    public var text: String
    public var spans: [HighlightSpan]
    public var isEmpty: Bool { text.isEmpty }
    public var spanStyles: [HighlightSpan] { spans }
}

public func highlightCode(_ source: String, _ language: String?) -> HighlightedCode {
    var spans: [HighlightSpan] = []
    let keywords = Set(["const", "let", "var", "function", "return", "if", "else", "for", "while", "class", "import", "export", "from", "async", "await", "true", "false", "null", "undefined"])
    var i = source.startIndex
    while i < source.endIndex {
        if source[i] == "/" && source[i...].hasPrefix("//") {
            let start = source.distance(from: source.startIndex, to: i)
            i = source.endIndex
            spans.append(HighlightSpan(range: start..<source.count, kind: "comment"))
            break
        }
        if source[i] == "\"" || source[i] == "'" {
            let quote = source[i]
            let start = source.distance(from: source.startIndex, to: i)
            i = source.index(after: i)
            while i < source.endIndex && source[i] != quote {
                if source[i] == "\\" && source.index(after: i) < source.endIndex {
                    i = source.index(i, offsetBy: 2)
                } else {
                    i = source.index(after: i)
                }
            }
            if i < source.endIndex { i = source.index(after: i) }
            let end = source.distance(from: source.startIndex, to: i)
            spans.append(HighlightSpan(range: start..<end, kind: "string"))
            continue
        }
        if source[i].isLetter || source[i] == "_" {
            let startIndex = i
            while i < source.endIndex && (source[i].isLetter || source[i].isNumber || source[i] == "_") {
                i = source.index(after: i)
            }
            let word = String(source[startIndex..<i])
            if keywords.contains(word) {
                let start = source.distance(from: source.startIndex, to: startIndex)
                let end = source.distance(from: source.startIndex, to: i)
                spans.append(HighlightSpan(range: start..<end, kind: "keyword"))
            }
            continue
        }
        i = source.index(after: i)
    }
    return HighlightedCode(text: source, spans: spans)
}

private struct MarkdownBlockParser {
    var lines: [String]
    var index = 0

    init(_ source: String) {
        lines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }

    mutating func parseBlocks(stopQuote: Bool = false) -> [MdBlock] {
        var blocks: [MdBlock] = []
        while index < lines.count {
            let line = lines[index]
            if stopQuote && !line.hasPrefix(">") && !line.trimmingCharacters(in: .whitespaces).isEmpty && !isIndented(line) {
                break
            }
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                index += 1
                continue
            }
            if let heading = parseHeading() { blocks.append(heading); continue }
            if parseRule() { blocks.append(.rule); continue }
            if let fence = parseFence() { blocks.append(fence); continue }
            if let table = parseTable() { blocks.append(table); continue }
            if let quote = parseQuote() { blocks.append(quote); continue }
            if let list = parseList() { blocks.append(list); continue }
            if let indented = parseIndentedCode() { blocks.append(indented); continue }
            blocks.append(parseParagraph())
        }
        return blocks
    }

    mutating func parseHeading() -> MdBlock? {
        let line = lines[index].trimmingCharacters(in: .whitespaces)
        guard line.hasPrefix("#") else { return nil }
        var level = 0
        for ch in line {
            if ch == "#" { level += 1 } else { break }
        }
        guard (1...6).contains(level), line.count > level, line[line.index(line.startIndex, offsetBy: level)] == " " else {
            return nil
        }
        index += 1
        let text = String(line.dropFirst(level + 1))
        return .heading(level: level, spans: parseInline(text))
    }

    mutating func parseRule() -> Bool {
        let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
        let chars = Set(trimmed)
        if trimmed.count >= 3 && (chars == ["-"] || chars == ["*"] || chars == ["_"]) {
            index += 1
            return true
        }
        return false
    }

    mutating func parseFence() -> MdBlock? {
        let line = lines[index]
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("```") else { return nil }
        let info = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        let language = info.isEmpty ? nil : String(info.split(separator: " ").first ?? Substring(info))
        index += 1
        var body: [String] = []
        while index < lines.count {
            let current = lines[index]
            if current.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                index += 1
                break
            }
            body.append(current)
            index += 1
        }
        return .code(language: language, literal: body.joined(separator: "\n"), incomplete: false)
    }

    mutating func parseIndentedCode() -> MdBlock? {
        guard lines[index].hasPrefix("    ") || lines[index].hasPrefix("\t") else { return nil }
        var body: [String] = []
        while index < lines.count {
            let line = lines[index]
            if line.hasPrefix("    ") {
                body.append(String(line.dropFirst(4)))
            } else if line.hasPrefix("\t") {
                body.append(String(line.dropFirst()))
            } else if line.trimmingCharacters(in: .whitespaces).isEmpty {
                body.append("")
            } else {
                break
            }
            index += 1
        }
        while body.last?.isEmpty == true { body.removeLast() }
        return .code(language: nil, literal: body.joined(separator: "\n"), incomplete: false)
    }

    mutating func parseTable() -> MdBlock? {
        guard index + 1 < lines.count else { return nil }
        let header = lines[index]
        let divider = lines[index + 1]
        guard header.contains("|"), isTableDivider(divider) else { return nil }
        let headers = [tableCells(header).map(parseInline)]
        index += 2
        var rows: [[[MdSpan]]] = []
        while index < lines.count, lines[index].contains("|"), !lines[index].trimmingCharacters(in: .whitespaces).isEmpty {
            if isTableDivider(lines[index]) { index += 1; continue }
            rows.append(tableCells(lines[index]).map(parseInline))
            index += 1
        }
        return .table(headers: headers, rows: rows)
    }

    mutating func parseQuote() -> MdBlock? {
        guard lines[index].trimmingCharacters(in: .whitespaces).hasPrefix(">") else { return nil }
        var inner: [String] = []
        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix(">") {
                var rest = String(trimmed.dropFirst())
                if rest.hasPrefix(" ") { rest = String(rest.dropFirst()) }
                inner.append(rest)
                index += 1
            } else if trimmed.isEmpty {
                break
            } else {
                break
            }
        }
        var nested = MarkdownBlockParser(inner.joined(separator: "\n"))
        return .quote(nested.parseBlocks())
    }

    mutating func parseList() -> MdBlock? {
        guard let marker = listMarker(lines[index]) else { return nil }
        let ordered = marker.ordered
        let start = marker.start
        var items: [[MdBlock]] = []
        var tight = true
        while index < lines.count, let current = listMarker(lines[index]), current.ordered == ordered {
            let itemIndent = current.indent + current.markerWidth
            var itemLines: [String] = [current.rest]
            index += 1
            while index < lines.count {
                let line = lines[index]
                if line.trimmingCharacters(in: .whitespaces).isEmpty {
                    if index + 1 < lines.count {
                        let next = lines[index + 1]
                        if listMarker(next) != nil && leadingSpaces(next) <= marker.indent {
                            break
                        }
                        if leadingSpaces(next) >= itemIndent || next.trimmingCharacters(in: .whitespaces).isEmpty {
                            tight = false
                            itemLines.append("")
                            index += 1
                            continue
                        }
                    }
                    break
                }
                if listMarker(line) != nil && leadingSpaces(line) <= marker.indent { break }
                if leadingSpaces(line) >= itemIndent {
                    itemLines.append(String(line.dropFirst(min(itemIndent, line.count))))
                    index += 1
                } else {
                    break
                }
            }
            var nested = MarkdownBlockParser(itemLines.joined(separator: "\n"))
            let children = nested.parseBlocks()
            items.append(children.isEmpty ? [.paragraph(parseInline(current.rest))] : children)
        }
        return ordered ? .orderedList(items: items, start: start, tight: tight) : .bulletList(items: items, tight: tight)
    }

    mutating func parseParagraph() -> MdBlock {
        var parts: [String] = []
        while index < lines.count {
            let line = lines[index]
            if line.trimmingCharacters(in: .whitespaces).isEmpty { break }
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("#") { break }
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") { break }
            if line.contains("|") && index + 1 < lines.count && isTableDivider(lines[index + 1]) { break }
            if listMarker(line) != nil { break }
            if line.trimmingCharacters(in: .whitespaces).hasPrefix(">") { break }
            if parseRulePeek() { break }
            parts.append(line.trimmingCharacters(in: .whitespaces))
            index += 1
        }
        return .paragraph(parseInline(parts.joined(separator: "\n")))
    }

    func parseRulePeek() -> Bool {
        let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
        let chars = Set(trimmed)
        return trimmed.count >= 3 && (chars == ["-"] || chars == ["*"] || chars == ["_"])
    }
}

private struct ListMarker {
    var ordered: Bool
    var start: Int
    var indent: Int
    var markerWidth: Int
    var rest: String
}

private func leadingSpaces(_ line: String) -> Int {
    line.prefix { $0 == " " }.count
}

private func isIndented(_ line: String) -> Bool {
    leadingSpaces(line) >= 4 || line.hasPrefix("\t")
}

private func listMarker(_ line: String) -> ListMarker? {
    let indent = leadingSpaces(line)
    let restLine = String(line.dropFirst(indent))
    if restLine.hasPrefix("- ") || restLine.hasPrefix("* ") || restLine.hasPrefix("+ ") {
        return ListMarker(ordered: false, start: 1, indent: indent, markerWidth: 2, rest: String(restLine.dropFirst(2)))
    }
    var digits = 0
    for ch in restLine {
        if ch.isNumber { digits += 1 } else { break }
    }
    guard digits > 0, digits < restLine.count else { return nil }
    let after = restLine.index(restLine.startIndex, offsetBy: digits)
    guard restLine[after] == ".", restLine.index(after: after) < restLine.endIndex, restLine[restLine.index(after: after)] == " " else {
        return nil
    }
    let number = Int(restLine.prefix(digits)) ?? 1
    return ListMarker(ordered: true, start: number, indent: indent, markerWidth: digits + 2, rest: String(restLine.dropFirst(digits + 2)))
}

private func isTableDivider(_ line: String) -> Bool {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    guard trimmed.contains("|") || trimmed.contains("-") else { return false }
    let body = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "|"))
    let cells = body.split(separator: "|")
    return !cells.isEmpty && cells.allSatisfy { cell in
        let t = cell.trimmingCharacters(in: .whitespaces)
        return t.contains("-") && t.allSatisfy { $0 == "-" || $0 == ":" || $0 == " " }
    }
}

private func tableCells(_ line: String) -> [String] {
    var raw = line.trimmingCharacters(in: .whitespaces)
    if raw.hasPrefix("|") { raw.removeFirst() }
    if raw.hasSuffix("|") { raw.removeLast() }
    return raw.split(separator: "|", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }.map(String.init)
}

func parseInline(_ text: String) -> [MdSpan] {
    var spans: [MdSpan] = []
    var i = text.startIndex
    var buffer = ""
    var bold = false
    var italic = false
    func flush() {
        if !buffer.isEmpty {
            spans.append(.text(buffer, bold: bold, italic: italic))
            buffer = ""
        }
    }
    while i < text.endIndex {
        if text[i...].hasPrefix("**") {
            flush()
            bold.toggle()
            i = text.index(i, offsetBy: 2)
            continue
        }
        if text[i] == "*" {
            flush()
            italic.toggle()
            i = text.index(after: i)
            continue
        }
        if text[i] == "`" {
            flush()
            i = text.index(after: i)
            let start = i
            while i < text.endIndex && text[i] != "`" { i = text.index(after: i) }
            spans.append(.code(String(text[start..<i])))
            if i < text.endIndex { i = text.index(after: i) }
            continue
        }
        if text[i] == "[" {
            if let close = text[i...].firstIndex(of: "]"),
               close < text.endIndex,
               text.index(after: close) < text.endIndex,
               text[text.index(after: close)] == "(",
               let destEnd = text[text.index(after: close)...].firstIndex(of: ")") {
                flush()
                let label = String(text[text.index(after: i)..<close])
                let destStart = text.index(text.index(after: close), offsetBy: 1)
                let dest = String(text[destStart..<destEnd])
                if let file = parseFileLink(dest) {
                    let chipLabel = label.isEmpty ? (file.split(whereSeparator: { $0 == "/" || $0 == "\\" }).last).map(String.init) ?? file : label
                    spans.append(.fileChip(path: file, label: chipLabel))
                } else {
                    spans.append(.link(text: label.isEmpty ? dest : label, dest: dest))
                }
                i = text.index(after: destEnd)
                continue
            }
        }
        buffer.append(text[i])
        i = text.index(after: i)
    }
    flush()
    return spans
}
