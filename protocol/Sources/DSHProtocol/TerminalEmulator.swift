import Foundation

public struct TermCell: Equatable, Sendable {
    public var ch: String
    public var fg: Int
    public var bg: Int
    public var bold: Bool
    public var dim: Bool
    public var underline: Bool
    public var inverse: Bool
    public var wide: Bool
    public var spacer: Bool

    public init(
        ch: String = " ",
        fg: Int = -1,
        bg: Int = -1,
        bold: Bool = false,
        dim: Bool = false,
        underline: Bool = false,
        inverse: Bool = false,
        wide: Bool = false,
        spacer: Bool = false
    ) {
        self.ch = ch
        self.fg = fg
        self.bg = bg
        self.bold = bold
        self.dim = dim
        self.underline = underline
        self.inverse = inverse
        self.wide = wide
        self.spacer = spacer
    }

    public func fgColor(defaultForeground: TermRGB) -> TermRGB {
        let base: TermRGB
        if (0...15).contains(fg) {
            base = Tango.ansi[fg]
        } else if (16...255).contains(fg) {
            base = xterm256(fg)
        } else {
            base = defaultForeground
        }
        return dim ? base.withAlpha(0.65) : base
    }

    public func bgColor(defaultBackground: TermRGB) -> TermRGB {
        if (0...15).contains(bg) { return Tango.ansi[bg] }
        if (16...255).contains(bg) { return xterm256(bg) }
        return defaultBackground
    }
}

/// Immutable selection snapshot: output arriving during a drag cannot change copied text.
public final class TerminalGrid: @unchecked Sendable {
    public let cells: [[TermCell]]
    public let wrapped: [Int]
    public var rows: Int { cells.count }
    public var cols: Int { cells.first?.count ?? 0 }

    public init(cells: [[TermCell]], wrapped: [Int]) {
        self.cells = cells
        self.wrapped = wrapped
    }

    public func cell(_ row: Int, _ col: Int) -> TermCell {
        guard row >= 0, row < rows, col >= 0, col < cols else { return TermCell() }
        return cells[row][col]
    }

    public func position(row: Int, col: Int) -> Int {
        let r = min(max(row, 0), max(rows - 1, 0))
        var c = min(max(col, 0), max(cols - 1, 0))
        if cells[r][c].spacer, c > 0 { c -= 1 }
        return r * cols + c
    }

    public func wordAt(_ position: Int) -> ClosedRange<Int> {
        let row = position / cols
        var start = position % cols
        var end = start
        func word(_ c: Int) -> Bool {
            let index = cells[row][c].spacer && c > 0 ? c - 1 : c
            return cells[row][index].ch.contains { $0.isLetter || $0.isNumber || $0 == "_" }
        }
        if word(start) {
            while start > 0, word(start - 1) { start -= 1 }
            while end + 1 < cols, word(end + 1) { end += 1 }
        }
        return (row * cols + start)...(row * cols + end)
    }

    public func selectedText(anchor: Int, end: Int) -> String {
        let first = min(anchor, end)
        let last = max(anchor, end)
        var out = ""
        let firstRow = first / cols
        let lastRow = last / cols
        if firstRow > lastRow { return "" }
        for r in firstRow...lastRow {
            let left = r == firstRow ? first % cols : 0
            let right = r == lastRow ? last % cols : cols - 1
            var line = ""
            let wrap = wrapped[safe: r] ?? 0
            let contentEnd = wrap > 0 ? min(right, wrap - 1) : right
            if left <= contentEnd {
                for c in left...contentEnd where !cells[r][c].spacer {
                    line.append(cells[r][c].ch)
                }
            }
            out.append(right == cols - 1 && wrap == 0 ? line.trailingSpacesTrimmed : line)
            if r < lastRow && wrap == 0 { out.append("\n") }
        }
        return out
    }
}

/// Fixed-grid VT100 / xterm-ish emulator for host PTY streams.
public final class AnsiTerminal: @unchecked Sendable {
    public private(set) var cols: Int
    public private(set) var rows: Int
    public private(set) var revision: Int64 = 0
    public private(set) var alternateScreen = false
    public private(set) var cursorX = 0
    public private(set) var cursorY = 0

    private var cells: [[TermCell]]
    private var wrapped: [Int]
    private var primaryScreen: TerminalGrid?
    private var primaryX = 0
    private var primaryY = 0
    private var primarySavedX = 0
    private var primarySavedY = 0
    // Rows displaced by a primary-screen resize are retained, not horizontally clipped.
    // This is bounded local history, not a scrollback UI or a replacement for host replay.
    private static let retainedRowLimit = 1_000
    private var precedingCells: [[TermCell]] = []
    private var precedingWrapped: [Int] = []
    private var followingCells: [[TermCell]] = []
    private var followingWrapped: [Int] = []
    private var mouseMode = 0
    private var sgrMouse = false
    private var savedX = 0
    private var savedY = 0
    private var fg = -1
    private var bg = -1
    private var bold = false
    private var dim = false
    private var underline = false
    private var inverse = false
    private var originMode = false
    private var autoWrap = true
    private var insertMode = false
    private var cursorVisible = true
    private var scrollTop = 0
    private var scrollBottom: Int
    private enum State { case ground, esc, csi, osc, dcs, sosPmApc }
    private var state = State.ground
    private var params = ""
    private var csiPrivate = false
    private var osc = ""
    private var pendingHigh: Character?
    private var skipCharset = false

    public init(cols: Int = 80, rows: Int = 24) {
        self.cols = max(cols, 2)
        self.rows = max(rows, 1)
        self.cells = Self.blank(cols: self.cols, rows: self.rows)
        self.wrapped = Array(repeating: 0, count: self.rows)
        self.scrollBottom = self.rows - 1
    }

    public func cell(_ row: Int, _ col: Int) -> TermCell {
        guard row >= 0, row < rows, col >= 0, col < cols else { return TermCell() }
        return cells[row][col]
    }

    public func isCursorVisible() -> Bool { cursorVisible }

    public func snapshot() -> TerminalGrid {
        TerminalGrid(cells: cells, wrapped: wrapped)
    }

    /// A tap is a click in mouse-aware apps, otherwise horizontal movement on this row only.
    public func tapInput(row: Int, column: Int) -> String? {
        guard row >= 0, row < rows, column >= 0, column < cols else { return nil }
        if mouseMode != 0 {
            let x = column + 1
            let y = row + 1
            if sgrMouse {
                return "\u{001b}[<0;\(x);\(y)M" + (mouseMode == 9 ? "" : "\u{001b}[<0;\(x);\(y)m")
            }
            if x > 95 || y > 95 { return nil }
            let position = "\(Character(UnicodeScalar(x + 32)!))\(Character(UnicodeScalar(y + 32)!))"
            return "\u{001b}[M \(position)" + (mouseMode == 9 ? "" : "\u{001b}[M#\(position)")
        }
        if alternateScreen || row != cursorY { return nil }
        var end = (cells[row].lastIndex(where: { !$0.spacer && $0.ch != " " }) ?? -1) + 1
        if end > 0, cells[row][end - 1].wide { end += 1 }
        end = min(max(end, cursorX), cols)
        var target = min(column, end)
        if target < cols, cells[row][target].spacer { target -= 1 }
        let start = min(max(cursorX, 0), cols)
        let lo = min(start, target)
        let hi = max(start, target)
        guard lo < hi else { return nil }
        let distance = (lo..<hi).filter { !cells[row][$0].spacer }.count
        if distance == 0 { return nil }
        return String(repeating: target < start ? "\u{001b}[D" : "\u{001b}[C", count: distance)
    }

    public func plainText() -> String {
        var lines: [String] = []
        for r in 0..<rows {
            var line = ""
            var c = 0
            while c < cols {
                let cell = cells[r][c]
                if cell.spacer { c += 1; continue }
                line.append(cell.ch)
                c += cell.wide ? 2 : 1
            }
            lines.append(line.trailingSpacesTrimmed)
        }
        return lines.joined(separator: "\n").trailingNewlinesTrimmed
    }

    public func resize(newCols: Int, newRows: Int) {
        let nc = max(newCols, 2)
        let nr = max(newRows, 1)
        if nc == cols && nr == rows { return }
        if alternateScreen {
            let alternateCells = cells
            let alternateWrapped = wrapped
            let alternateX = cursorX
            let alternateY = cursorY
            let alternateSavedX = savedX
            let alternateSavedY = savedY
            if let primaryScreen {
                cells = primaryScreen.cells
                wrapped = primaryScreen.wrapped
                cursorX = primaryX
                cursorY = primaryY
                savedX = primarySavedX
                savedY = primarySavedY
                reflowPrimary(cols: nc, rows: nr)
                self.primaryScreen = snapshot()
                primaryX = cursorX
                primaryY = cursorY
                primarySavedX = savedX
                primarySavedY = savedY
            }
            // Full-screen applications own their layout: crop/pad, never reflow.
            cells = Self.blank(cols: nc, rows: nr)
            wrapped = Array(repeating: 0, count: nr)
            for r in 0..<min(rows, nr) {
                for c in 0..<min(cols, nc) {
                    cells[r][c] = alternateCells[r][c]
                }
                if cells[r][nc - 1].wide { cells[r][nc - 1] = TermCell() }
                wrapped[r] = min(alternateWrapped[r], nc)
            }
            cursorX = min(alternateX, nc - 1)
            cursorY = min(alternateY, nr - 1)
            savedX = min(alternateSavedX, nc - 1)
            savedY = min(alternateSavedY, nr - 1)
        } else {
            reflowPrimary(cols: nc, rows: nr)
        }
        cols = nc
        rows = nr
        scrollTop = 0
        scrollBottom = rows - 1
        bump()
    }

    private func reflowPrimary(cols newCols: Int, rows newRows: Int) {
        let source = precedingCells + cells + followingCells
        let sourceWrapped = precedingWrapped + wrapped + followingWrapped
        let cursorRow = precedingCells.count + cursorY
        let savedRow = precedingCells.count + savedY
        let blank = TermCell()
        // Ignore unused bottom padding, but keep explicit blank lines before content/cursors.
        var end = source.count
        while end > max(cursorRow, savedRow) + 1,
              sourceWrapped[end - 1] == 0,
              source[end - 1].allSatisfy({ $0 == blank }) {
            end -= 1
        }
        var output: [[TermCell]] = []
        var outputWrapped: [Int] = []
        var line = Array(repeating: blank, count: newCols)
        var column = 0
        var mappedCursor: (x: Int, y: Int)?
        var mappedSaved: (x: Int, y: Int)?
        func appendLine(wrap: Int) {
            output.append(line)
            outputWrapped.append(wrap)
            line = Array(repeating: blank, count: newCols)
            column = 0
        }
        for r in 0..<end {
            let sourceLine = source[r]
            let soft = sourceWrapped[r] > 0
            var length = soft ? min(sourceWrapped[r], sourceLine.count)
                : (sourceLine.lastIndex(where: { $0 != blank }).map { $0 + 1 } ?? 0)
            if r == cursorRow { length = max(length, min(cursorX, sourceLine.count)) }
            if r == savedRow { length = max(length, min(savedX, sourceLine.count)) }
            var c = 0
            while c < length {
                var cell = sourceLine[c]
                // A spacer is emitted only with its lead; never carry an orphan across a resize.
                if cell.spacer { cell = blank }
                let width = cell.wide ? 2 : 1
                if column + width > newCols { appendLine(wrap: column) }
                if r == cursorRow, cursorX == c { mappedCursor = (column, output.count) }
                if r == savedRow, savedX == c { mappedSaved = (column, output.count) }
                line[column] = cell
                if width == 2 {
                    line[column + 1] = TermCell(spacer: true)
                    if r == cursorRow, cursorX == c + 1 { mappedCursor = (column + 1, output.count) }
                    if r == savedRow, savedX == c + 1 { mappedSaved = (column + 1, output.count) }
                }
                column += width
                c += width
            }
            // Keep the delayed-wrap position (x == cols), rather than moving it left.
            if r == cursorRow, mappedCursor == nil { mappedCursor = (column, output.count) }
            if r == savedRow, mappedSaved == nil { mappedSaved = (column, output.count) }
            if !soft { appendLine(wrap: 0) }
        }
        if column > 0 { appendLine(wrap: 0) }
        let cursor = mappedCursor ?? (x: 0, y: 0)
        let saved = mappedSaved ?? (x: 0, y: 0)
        // Prefer the bottom content, but never move the active cursor outside the viewport.
        let start = min(max(output.count - newRows, 0), cursor.y)
        let stop = min(start + newRows, output.count)
        let historyStart = max(start - Self.retainedRowLimit, 0)
        precedingCells = Array(output[historyStart..<start])
        precedingWrapped = Array(outputWrapped[historyStart..<start])
        let followingEnd = min(stop + Self.retainedRowLimit, output.count)
        followingCells = Array(output[stop..<followingEnd])
        followingWrapped = Array(outputWrapped[stop..<followingEnd])
        cells = Array(output[start..<stop])
        wrapped = Array(outputWrapped[start..<stop])
        if cells.count < newRows {
            let padding = newRows - cells.count
            cells.append(contentsOf: Self.blank(cols: newCols, rows: padding))
            wrapped.append(contentsOf: Array(repeating: 0, count: padding))
        }
        cursorX = cursor.x
        cursorY = cursor.y - start
        savedX = saved.x
        savedY = min(max(saved.y - start, 0), newRows - 1)
    }

    public func clear() {
        cells = Self.blank(cols: cols, rows: rows)
        wrapped = Array(repeating: 0, count: rows)
        alternateScreen = false
        primaryScreen = nil
        precedingCells.removeAll()
        precedingWrapped.removeAll()
        followingCells.removeAll()
        followingWrapped.removeAll()
        mouseMode = 0
        sgrMouse = false
        savedX = 0
        savedY = 0
        originMode = false
        autoWrap = true
        insertMode = false
        cursorVisible = true
        skipCharset = false
        cursorX = 0
        cursorY = 0
        fg = -1
        bg = -1
        bold = false
        dim = false
        underline = false
        inverse = false
        state = .ground
        params = ""
        osc = ""
        pendingHigh = nil
        csiPrivate = false
        scrollTop = 0
        scrollBottom = rows - 1
        bump()
    }

    public func applySnapshot(_ screen: String) {
        clear()
        write(screen)
    }

    public func write(_ data: String) {
        var i = data.startIndex
        while i < data.endIndex {
            let ch = data[i]
            let next = data.index(after: i)
            if skipCharset {
                skipCharset = false
                i = next
                continue
            }
            switch state {
            case .ground:
                switch ch {
                case "\u{001B}": state = .esc
                case "\u{0007}": break
                case "\u{0008}": backspace()
                case "\t": tab()
                case "\n": lineFeed()
                case "\r": carriageReturn()
                case "\r\n":
                    carriageReturn()
                    lineFeed()
                case "\u{000E}", "\u{000F}": break
                default:
                    if ch.isHighSurrogate {
                        pendingHigh = ch
                    } else if ch.isLowSurrogate {
                        if let hi = pendingHigh {
                            pendingHigh = nil
                            putChar(String([hi, ch]))
                        } else {
                            putChar("\u{FFFD}")
                        }
                    } else {
                        pendingHigh = nil
                        if ch.unicodeScalars.first.map({ $0.value >= 0x20 }) == true {
                            putChar(String(ch))
                        }
                    }
                }
            case .esc:
                switch ch {
                case "[":
                    state = .csi
                    params = ""
                    csiPrivate = false
                case "]":
                    state = .osc
                    osc = ""
                case "P": state = .dcs
                case "X", "^", "_": state = .sosPmApc
                case "7":
                    savedX = cursorX
                    savedY = cursorY
                    state = .ground
                case "8":
                    cursorX = savedX
                    cursorY = savedY
                    state = .ground
                case "c":
                    hardReset()
                    state = .ground
                case "D":
                    lineFeed()
                    state = .ground
                case "E":
                    carriageReturn()
                    lineFeed()
                    state = .ground
                case "M":
                    reverseIndex()
                    state = .ground
                case "(", ")", "*", "+":
                    skipCharset = true
                    state = .ground
                default:
                    state = .ground
                }
            case .csi:
                if ch == "?", params.isEmpty {
                    csiPrivate = true
                } else if ch.isASCII && ((ch >= "0" && ch <= "9") || ch == ";" || ch == ":") {
                    params.append(ch)
                } else if ch.isASCII && ch >= " " && ch <= "/" {
                    params.append(ch)
                } else if ch.isASCII && ch >= "@" && ch <= "~" {
                    execCsi(ch)
                    state = .ground
                } else {
                    state = .ground
                }
            case .osc:
                switch ch {
                case "\u{0007}": state = .ground
                case "\u{001B}": break
                case "\\": state = .ground
                default: osc.append(ch)
                }
            case .dcs, .sosPmApc:
                switch ch {
                case "\u{001B}": break
                case "\\", "\u{0007}": state = .ground
                default: break
                }
            }
            i = next
        }
        bump()
    }

    private func hardReset() {
        clear()
        autoWrap = true
        insertMode = false
        cursorVisible = true
        originMode = false
    }

    private func bump() { revision += 1 }

    private func styleCell(_ ch: String, wide: Bool) -> TermCell {
        TermCell(ch: ch, fg: fg, bg: bg, bold: bold, dim: dim, underline: underline, inverse: inverse, wide: wide)
    }

    private func putChar(_ s: String) {
        let w = terminalCharWidth(s)
        if w <= 0 {
            if let cp = s.unicodeScalars.first?.value, cp >= 0x20, cursorX > 0 {
                var previous = min(cursorX - 1, cols - 1)
                if cells[cursorY][previous].spacer { previous -= 1 }
                if previous >= 0 {
                    cells[cursorY][previous].ch += s
                }
            }
            return
        }
        if autoWrap && cursorX + w > cols {
            wrapped[cursorY] = cursorX
            carriageReturn()
            lineFeed(softWrap: true)
        }
        if cursorX >= cols { cursorX = cols - 1 }
        if insertMode { insertBlanks(w) }
        cells[cursorY][cursorX] = styleCell(s, wide: w == 2)
        if w == 2 {
            if cursorX + 1 < cols { cells[cursorY][cursorX + 1] = TermCell(spacer: true) }
            cursorX += 2
        } else {
            cursorX += 1
        }
        if !autoWrap && cursorX >= cols { cursorX = cols - 1 }
    }

    private func backspace() {
        if cursorX > 0 { cursorX -= 1 }
    }

    private func tab() {
        cursorX = ((cursorX / 8) + 1) * 8
        if cursorX >= cols { cursorX = cols - 1 }
    }

    private func carriageReturn() { cursorX = 0 }

    private func lineFeed(softWrap: Bool = false) {
        if !softWrap { wrapped[cursorY] = 0 }
        if cursorY == scrollBottom { scrollUp(1) }
        else if cursorY < rows - 1 { cursorY += 1 }
    }

    private func reverseIndex() {
        if cursorY == scrollTop { scrollDown(1) }
        else if cursorY > 0 { cursorY -= 1 }
    }

    private func copyRow(from: Int, to: Int) {
        cells[to] = cells[from]
        wrapped[to] = wrapped[from]
    }

    private func clearRow(_ r: Int) {
        cells[r] = Array(repeating: TermCell(), count: cols)
        wrapped[r] = 0
    }

    private func scrollUp(_ n: Int) {
        for _ in 0..<n {
            if !alternateScreen, scrollTop == 0, scrollBottom == rows - 1 {
                precedingCells.append(cells[0])
                precedingWrapped.append(wrapped[0])
                if precedingCells.count > Self.retainedRowLimit {
                    precedingCells.removeFirst()
                    precedingWrapped.removeFirst()
                }
            }
            for r in scrollTop..<scrollBottom { copyRow(from: r + 1, to: r) }
            clearRow(scrollBottom)
        }
    }

    private func scrollDown(_ n: Int) {
        for _ in 0..<n {
            for r in stride(from: scrollBottom, through: scrollTop + 1, by: -1) { copyRow(from: r - 1, to: r) }
            clearRow(scrollTop)
        }
    }

    private func paramsList() -> [Int] {
        if params.isEmpty { return [] }
        return params.split(separator: ";", omittingEmptySubsequences: false).map { Int($0) ?? 0 }
    }

    private func p(_ i: Int, _ def: Int = 1) -> Int {
        let list = paramsList()
        let v = i < list.count ? list[i] : def
        return v == 0 ? def : v
    }

    private func execCsi(_ final: Character) {
        if csiPrivate {
            switch final {
            case "h":
                for it in paramsList() {
                    switch it {
                    case 7: autoWrap = true
                    case 25: cursorVisible = true
                    case 9, 1000, 1002, 1003: mouseMode = it
                    case 1006: sgrMouse = true
                    case 47, 1047, 1049: setAlternateScreen(true)
                    default: break
                    }
                }
            case "l":
                for it in paramsList() {
                    switch it {
                    case 7: autoWrap = false
                    case 25: cursorVisible = false
                    case 9, 1000, 1002, 1003:
                        if mouseMode == it { mouseMode = 0 }
                    case 1006: sgrMouse = false
                    case 47, 1047, 1049: setAlternateScreen(false)
                    default: break
                    }
                }
            default: break
            }
            return
        }
        switch final {
        case "A": cursorY = max(cursorY - p(0), 0)
        case "B": cursorY = min(cursorY + p(0), rows - 1)
        case "C": cursorX = min(cursorX + p(0), cols - 1)
        case "D": cursorX = max(cursorX - p(0), 0)
        case "E":
            cursorY = min(cursorY + p(0), rows - 1)
            cursorX = 0
        case "F":
            cursorY = max(cursorY - p(0), 0)
            cursorX = 0
        case "G": cursorX = min(max(p(0) - 1, 0), cols - 1)
        case "H", "f":
            cursorY = min(max(p(0) - 1, 0), rows - 1)
            cursorX = min(max(p(1, 1) - 1, 0), cols - 1)
        case "J": eraseDisplay(paramsList().first ?? 0)
        case "K": eraseLine(paramsList().first ?? 0)
        case "L": insertLines(p(0))
        case "M": deleteLines(p(0))
        case "@": insertBlanks(p(0))
        case "P": deleteChars(p(0))
        case "X": eraseChars(p(0))
        case "d": cursorY = min(max(p(0) - 1, 0), rows - 1)
        case "m": sgr(paramsList().isEmpty ? [0] : paramsList())
        case "r":
            let top = min(max(p(0) - 1, 0), rows - 1)
            let rawBot = paramsList().count > 1 ? paramsList()[1] : rows
            let bot = (rawBot == 0 ? rows : rawBot) - 1
            scrollTop = min(top, bot)
            scrollBottom = min(max(bot, scrollTop), rows - 1)
        case "s":
            savedX = cursorX
            savedY = cursorY
        case "u":
            cursorX = savedX
            cursorY = savedY
        case "h":
            for it in paramsList() where it == 4 { insertMode = true }
        case "l":
            for it in paramsList() where it == 4 { insertMode = false }
        case "S": scrollUp(p(0))
        case "T": scrollDown(p(0))
        default: break
        }
    }

    private func setAlternateScreen(_ active: Bool) {
        if alternateScreen == active { return }
        if active {
            primaryScreen = snapshot()
            primaryX = cursorX
            primaryY = cursorY
            primarySavedX = savedX
            primarySavedY = savedY
            savedX = 0
            savedY = 0
            cells = Self.blank(cols: cols, rows: rows)
            wrapped = Array(repeating: 0, count: rows)
            cursorX = 0
            cursorY = 0
        } else {
            if let saved = primaryScreen {
                cells = saved.cells
                wrapped = saved.wrapped
            }
            cursorX = primaryX
            cursorY = primaryY
            savedX = primarySavedX
            savedY = primarySavedY
            primaryScreen = nil
        }
        alternateScreen = active
    }

    private func eraseDisplay(_ mode: Int) {
        switch mode {
        case 0:
            eraseLine(0)
            if cursorY + 1 < rows {
                for r in (cursorY + 1)..<rows { clearRow(r) }
            }
        case 1:
            if cursorY > 0 {
                for r in 0..<cursorY { clearRow(r) }
            }
            eraseLine(1)
        case 2, 3:
            for r in 0..<rows { clearRow(r) }
            if !alternateScreen {
                followingCells.removeAll()
                followingWrapped.removeAll()
                if mode == 3 {
                    precedingCells.removeAll()
                    precedingWrapped.removeAll()
                }
            }
        default:
            break
        }
    }

    private func eraseLine(_ mode: Int) {
        switch mode {
        case 0:
            if cursorX < cols {
                for c in cursorX..<cols { cells[cursorY][c] = TermCell() }
            }
        case 1:
            for c in 0...cursorX { cells[cursorY][c] = TermCell() }
        case 2:
            clearRow(cursorY)
        default:
            break
        }
    }

    private func insertLines(_ n: Int) {
        for _ in 0..<n {
            for r in stride(from: scrollBottom, through: cursorY + 1, by: -1) { copyRow(from: r - 1, to: r) }
            clearRow(cursorY)
        }
    }

    private func deleteLines(_ n: Int) {
        for _ in 0..<n {
            for r in cursorY..<scrollBottom { copyRow(from: r + 1, to: r) }
            clearRow(scrollBottom)
        }
    }

    private func insertBlanks(_ n: Int) {
        var row = cells[cursorY]
        for c in stride(from: cols - 1, through: cursorX + n, by: -1) {
            if c - n >= cursorX { row[c] = row[c - n] }
        }
        let until = min(cursorX + n, cols)
        if cursorX < until {
            for c in cursorX..<until { row[c] = TermCell() }
        }
        cells[cursorY] = row
    }

    private func deleteChars(_ n: Int) {
        var row = cells[cursorY]
        for c in cursorX..<cols {
            let src = c + n
            row[c] = src < cols ? row[src] : TermCell()
        }
        cells[cursorY] = row
    }

    private func eraseChars(_ n: Int) {
        let until = min(cursorX + n, cols)
        if cursorX < until {
            for c in cursorX..<until { cells[cursorY][c] = TermCell() }
        }
    }

    private func sgr(_ ps: [Int]) {
        var i = 0
        while i < ps.count {
            let p = ps[i]
            switch p {
            case 0:
                fg = -1; bg = -1; bold = false; dim = false; underline = false; inverse = false
            case 1: bold = true
            case 2: dim = true
            case 4: underline = true
            case 7: inverse = true
            case 22: bold = false; dim = false
            case 24: underline = false
            case 27: inverse = false
            case 30...37: fg = p - 30
            case 39: fg = -1
            case 40...47: bg = p - 40
            case 49: bg = -1
            case 90...97: fg = p - 90 + 8
            case 100...107: bg = p - 100 + 8
            case 38, 48:
                let isFg = p == 38
                if i + 1 < ps.count {
                    switch ps[i + 1] {
                    case 5:
                        if i + 2 < ps.count {
                            if isFg { fg = ps[i + 2] } else { bg = ps[i + 2] }
                            i += 2
                        }
                    case 2:
                        if i + 4 < ps.count {
                            let r = ps[i + 2], g = ps[i + 3], b = ps[i + 4]
                            let n = 16 + 36 * (r / 51) + 6 * (g / 51) + (b / 51)
                            if isFg { fg = n } else { bg = n }
                            i += 4
                        }
                    default:
                        break
                    }
                }
            default:
                break
            }
            i += 1
        }
    }

    private static func blank(cols: Int, rows: Int) -> [[TermCell]] {
        Array(repeating: Array(repeating: TermCell(), count: cols), count: rows)
    }
}

/// East-Asian / emoji width for a single terminal grapheme (BMP-oriented).
public func terminalCharWidth(_ s: String) -> Int {
    guard let scalar = s.unicodeScalars.first else { return 0 }
    let cp = scalar.value
    if cp < 0x20 || cp == 0x7F { return 0 }
    switch scalar.properties.generalCategory {
    case .nonspacingMark, .spacingMark, .enclosingMark: return 0
    default: break
    }
    if s.unicodeScalars.count >= 2, scalar.properties.isEmoji { return 2 }
    if (0x1100...0x115F).contains(cp) || (0x2E80...0xA4CF).contains(cp) || (0xAC00...0xD7A3).contains(cp)
        || (0xF900...0xFAFF).contains(cp) || (0xFE10...0xFE6F).contains(cp) || (0xFF00...0xFF60).contains(cp)
        || (0xFFE0...0xFFE6).contains(cp) || (0x1F300...0x1FAFF).contains(cp) || (0x20000...0x3FFFD).contains(cp) {
        return 2
    }
    return 1
}

private extension Character {
    var isHighSurrogate: Bool {
        unicodeScalars.count == 1 && (0xD800...0xDBFF).contains(unicodeScalars.first!.value)
    }
    var isLowSurrogate: Bool {
        unicodeScalars.count == 1 && (0xDC00...0xDFFF).contains(unicodeScalars.first!.value)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private extension String {
    var trailingSpacesTrimmed: String {
        var end = endIndex
        while end > startIndex {
            let prev = index(before: end)
            if self[prev] == " " { end = prev } else { break }
        }
        return String(self[..<end])
    }

    var trailingNewlinesTrimmed: String {
        var end = endIndex
        while end > startIndex {
            let prev = index(before: end)
            if self[prev] == "\n" { end = prev } else { break }
        }
        return String(self[..<end])
    }
}
