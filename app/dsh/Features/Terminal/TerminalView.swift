import SwiftUI
import UIKit
import DSHProtocol

struct TerminalView: View {
    @ObservedObject var model: AppModel
    var enabled: Bool
    var platform: String?
    @FocusState private var inputFocused: Bool
    @State private var ime = terminalImeAnchor
    @State private var pendingPaste: String?
    @State private var selectionGrid: TerminalGrid?
    @State private var selectionAnchor = 0
    @State private var selectionEnd = 0
    @State private var viewport = CGSize.zero

    private var selecting: Bool { selectionGrid != nil }
    private var isMac: Bool { platform == "darwin" }
    private var inputEnabled: Bool { enabled && !selecting && pendingPaste == nil }

    var body: some View {
        VStack(spacing: 0) {
            shortcuts
            Divider()
            ZStack(alignment: .topLeading) {
                TextField("", text: $ime)
                    .focused($inputFocused)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .keyboardType(.asciiCapable)
                    .submitLabel(.return)
                    .frame(width: 1, height: 1)
                    .opacity(0.01)
                    .accessibilityLabel(L.terminalKeyboardInput())
                    .disabled(!enabled || selecting)
                    .onChange(of: ime) { next in
                        guard enabled, !selecting else { return }
                        let input = terminalCommittedInput(next)
                        if input.count > 1, input.contains("\r") {
                            pendingPaste = input
                        } else if !input.isEmpty {
                            model.writeTerminal(input)
                        }
                        ime = terminalImeAnchor
                    }
                TerminalCanvas(
                    terminal: model.terminal,
                    revision: model.terminalRevision,
                    fontSize: model.terminalFontSize,
                    fontFamily: model.terminalFontFamily,
                    enabled: enabled && !selecting,
                    selection: selectionGrid,
                    selectionAnchor: selectionAnchor,
                    selectionEnd: selectionEnd,
                    onTap: { row, col in
                        if !selecting, enabled {
                            if let seq = model.terminal.tapInput(row: row, column: col) {
                                model.writeTerminal(seq)
                            }
                            startInput()
                        }
                    },
                    onSelect: { grid, anchor, end in
                        selectionGrid = grid
                        selectionAnchor = anchor
                        selectionEnd = end
                        inputFocused = false
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(T.bg)
                .accessibilityElement()
                .accessibilityLabel(L.terminalOutputHint())
                .accessibilityIdentifier("terminalScreen")
                .accessibilityValue(model.terminal.plainText())
                .onSizeChange { size in
                    viewport = size
                    resizeToViewport()
                }
            }
        }
        .onChange(of: model.terminalFontSize) { _ in resizeToViewport() }
        .onChange(of: model.terminalFontFamily) { _ in resizeToViewport() }
        .onChange(of: enabled) { value in
            if !value {
                inputFocused = false
                ime = terminalImeAnchor
                pendingPaste = nil
            }
        }
        .alert(L.pasteMultilineTitle(), isPresented: Binding(
            get: { pendingPaste != nil },
            set: { if !$0 { pendingPaste = nil } }
        )) {
            Button(L.cancel(), role: .cancel) { pendingPaste = nil }
            Button(L.confirmPaste()) {
                if let text = pendingPaste, enabled { model.writeTerminal(text) }
                pendingPaste = nil
            }
            .disabled(!enabled)
        } message: {
            Text(L.pasteMultilineBody())
        }
    }

    private var shortcuts: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                TerminalKey("Esc", enabled: inputEnabled) { send("\u{001b}") }
                TerminalKey("Tab", enabled: inputEnabled) { send("\t") }
                TerminalKey("↑", enabled: inputEnabled, description: "Cursor up") { send("\u{001b}[A") }
                TerminalKey("↓", enabled: inputEnabled, description: "Cursor down") { send("\u{001b}[B") }
                TerminalKey(
                    "",
                    enabled: enabled || selecting,
                    active: inputFocused,
                    glyph: selecting ? .checkOutline : .keyboard,
                    description: selecting ? L.terminalDone() : (inputFocused ? L.hideKeyboard() : L.showKeyboard())
                ) {
                    if selecting {
                        selectionGrid = nil
                        if enabled { startInput() }
                    } else if inputFocused {
                        inputFocused = false
                    } else {
                        startInput()
                    }
                }
            }
            HStack(spacing: 4) {
                TerminalKey("Ctrl+C", enabled: inputEnabled || (!isMac && selecting)) {
                    if selecting && !isMac { copySelection() } else { send("\u{0003}") }
                }
                TerminalKey("Ctrl+D", enabled: inputEnabled) { send("\u{0004}") }
                TerminalKey(terminalKeyPasteLabel(platform: platform), enabled: inputEnabled, description: L.paste()) { paste() }
                TerminalKey(terminalKeyCopyLabel(platform: platform), enabled: selecting, description: L.copy()) { copySelection() }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(T.surface)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("terminalKeyBar")
    }

    private func resizeToViewport() {
        let size = viewport
        guard enabled, size.width > 0, size.height > 0 else { return }
        let face = TerminalTypeface.resolved(ofSize: CGFloat(model.terminalFontSize))
        let cols = TerminalCellLayout.columns(
            viewportWidth: Double(size.width),
            cellWidth: Double(face.cellWidth)
        )
        let rows = TerminalCellLayout.rows(
            viewportHeight: Double(size.height),
            cellHeight: Double(face.cellHeight)
        )
        if cols != model.terminal.cols || rows != model.terminal.rows {
            model.resizeTerminal(cols: cols, rows: rows)
        }
    }

    private func send(_ value: String) {
        if inputEnabled { model.writeTerminal(value) }
    }

    private func startInput() {
        selectionGrid = nil
        if enabled { inputFocused = true }
    }

    private func copySelection() {
        guard let grid = selectionGrid else { return }
        UIPasteboard.general.string = grid.selectedText(anchor: selectionAnchor, end: selectionEnd)
    }

    private func paste() {
        guard inputEnabled, let text = UIPasteboard.general.string, !text.isEmpty else { return }
        if text.contains("\n") || text.contains("\r") { pendingPaste = text }
        else { send(text) }
    }
}

private struct TerminalKey: View {
    let label: String
    var enabled: Bool = true
    var active: Bool = false
    var glyph: OfficialGlyph.Kind?
    var description: String
    let action: () -> Void

    init(
        _ label: String,
        enabled: Bool = true,
        active: Bool = false,
        glyph: OfficialGlyph.Kind? = nil,
        description: String? = nil,
        action: @escaping () -> Void
    ) {
        self.label = label
        self.enabled = enabled
        self.active = active
        self.glyph = glyph
        self.description = description ?? label
        self.action = action
    }

    var body: some View {
        let color = enabled ? (active ? T.accent : T.text2) : T.text3.opacity(0.5)
        Button(action: action) {
            Group {
                if let glyph {
                    OfficialGlyph(kind: glyph, size: CGFloat(terminalKeyGlyphSizePoints), color: color)
                } else {
                    Text(label).font(.system(size: 13)).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, minHeight: CGFloat(terminalKeyMinHeightPoints))
            .foregroundStyle(color)
            .background(active ? T.tint : Color.clear, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(description)
    }
}

private struct TerminalCanvas: View {
    let terminal: AnsiTerminal
    let revision: Int64
    let fontSize: Int
    let fontFamily: String
    let enabled: Bool
    let selection: TerminalGrid?
    let selectionAnchor: Int
    let selectionEnd: Int
    let onTap: (Int, Int) -> Void
    let onSelect: (TerminalGrid, Int, Int) -> Void

    var body: some View {
        Canvas { context, size in
            _ = revision
            _ = fontFamily
            let face = TerminalTypeface.resolved(ofSize: CGFloat(fontSize))
            let cellW = face.cellWidth
            let cellH = face.cellHeight
            let inset = CGFloat(TerminalCellLayout.inset)
            let rows = selection?.rows ?? terminal.rows
            let cols = selection?.cols ?? terminal.cols
            let foreground = TermRGB(r: T.ink.components.r, g: T.ink.components.g, b: T.ink.components.b, a: 1)
            let background = TermRGB(r: T.bg.components.r, g: T.bg.components.g, b: T.bg.components.b, a: 1)
            for r in 0..<rows {
                var c = 0
                while c < cols {
                    let cell = selection?.cell(r, c) ?? terminal.cell(r, c)
                    if cell.spacer { c += 1; continue }
                    let w = cell.wide ? 2 : 1
                    var fg = cell.fgColor(defaultForeground: foreground)
                    var bg = cell.bgColor(defaultBackground: background)
                    if cell.inverse { swap(&fg, &bg) }
                    let selected = selection != nil &&
                        (r * cols + c) >= min(selectionAnchor, selectionEnd) &&
                        (r * cols + c) <= max(selectionAnchor, selectionEnd)
                    if selected {
                        if ThemeStateHolder.shared.dark {
                            bg = TermRGB(r: 1, g: 1, b: 1, a: 0.22)
                        } else {
                            bg = TermRGB(r: 0, g: 0, b: 0, a: 0.12)
                        }
                    }
                    let rect = CGRect(x: CGFloat(c) * cellW + inset, y: CGFloat(r) * cellH + inset, width: cellW * CGFloat(w), height: cellH)
                    if bg != background {
                        context.fill(Path(rect), with: .color(color(bg)))
                    }
                    let cursor = enabled && terminal.isCursorVisible() && terminal.cursorX == c && terminal.cursorY == r
                    if cursor {
                        context.fill(Path(rect), with: .color(color(fg)))
                        fg = bg
                    }
                    if cell.ch != " ", !cell.ch.isEmpty {
                        var text = Text(cell.ch).font(face.font).foregroundColor(color(fg))
                        if cell.bold { text = text.bold() }
                        context.draw(text, at: CGPoint(x: rect.minX, y: rect.minY), anchor: .topLeading)
                        if cell.underline {
                            var path = Path()
                            path.move(to: CGPoint(x: rect.minX, y: rect.maxY - 1))
                            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - 1))
                            context.stroke(path, with: .color(color(fg)), lineWidth: 1)
                        }
                    }
                    c += w
                }
            }
        }
        .padding(0)
        .contentShape(Rectangle())
        .gesture(
            SpatialTapGesture().onEnded { value in
                let cell = cellAt(value.location)
                onTap(cell.row, cell.col)
            }
        )
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .sequenced(before: DragGesture(minimumDistance: 0))
                .onChanged { value in
                    switch value {
                    case .first(true):
                        break
                    case .second(true, let drag):
                        if let drag {
                            beginOrExtend(drag.location)
                        }
                    default:
                        break
                    }
                }
                .onEnded { value in
                    if case .second(_, let drag) = value, let drag {
                        beginOrExtend(drag.location)
                    }
                }
        )
    }

    private func beginOrExtend(_ point: CGPoint) {
        let grid = selection ?? terminal.snapshot()
        if selection == nil, terminalGridIsBlank(grid) { return }
        let cell = cellAt(point, cols: grid.cols)
        let pos = grid.position(row: cell.row, col: cell.col)
        if selection == nil {
            let range = grid.wordAt(pos)
            onSelect(grid, range.lowerBound, range.upperBound)
        } else {
            onSelect(grid, selectionAnchor, pos)
        }
    }

    private func cellAt(_ point: CGPoint, cols: Int? = nil) -> (row: Int, col: Int) {
        let face = TerminalTypeface.resolved(ofSize: CGFloat(fontSize))
        let col = TerminalCellLayout.column(x: Double(point.x), cellWidth: Double(face.cellWidth))
        let row = TerminalCellLayout.row(y: Double(point.y), cellHeight: Double(face.cellHeight))
        return (row, col)
    }

    private func color(_ rgb: TermRGB) -> Color {
        Color(.sRGB, red: rgb.r, green: rgb.g, blue: rgb.b, opacity: rgb.a)
    }
}

private extension Color {
    var components: (r: Double, g: Double, b: Double) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b))
    }
}

extension View {
    func onSizeChange(_ body: @escaping (CGSize) -> Void) -> some View {
        background(
            GeometryReader { geo in
                Color.clear.preference(key: SizeKey.self, value: geo.size)
            }
        )
        .onPreferenceChange(SizeKey.self, perform: body)
    }
}

private struct SizeKey: PreferenceKey {
    static var defaultValue = CGSize.zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) { value = nextValue() }
}
