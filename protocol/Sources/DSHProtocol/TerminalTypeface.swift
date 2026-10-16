import Foundation

/// Bundled MesloLGL DZ Nerd Font (same face Android ships for PTY / Powerlevel10k).
public enum TerminalTypefacePolicy {
    public static let bundledFamily = "MesloLGLDZ Nerd Font"
    public static let bundledPostScript = "MesloLGLDZNF-Regular"
    public static let fileName = "MesloLGLDZNerdFont-Regular"
    public static let fileExtension = "ttf"
    /// `Fonts/` is an Xcode folder reference, so UIAppFonts and Bundle lookups use this path.
    public static let bundleSubdirectory = "Fonts"
    public static var uiAppFontPath: String { "\(bundleSubdirectory)/\(fileName).\(fileExtension)" }

    /// CoreText cascade after the Nerd face so ASCII stays Menlo-width and
    /// missing PUA glyphs can still fall through to Apple Symbols / emoji.
    public static let cascadeFamilies = [
        bundledFamily,
        "Menlo",
        "SF Mono",
        "Courier",
        "Apple Symbols",
        "Apple Color Emoji",
    ]
}

/// PTY cell box from glyph width + line height. Resize, Canvas, and hit-testing
/// must use this same formula so column width, row height, and cursor mapping stay aligned.
public enum TerminalCellLayout {
    public static let inset: Double = 8
    public static let lineHeightMultiple: Double = 1.35
    public static let minHeightToWidth: Double = 1.6
    public static let minColumns = 2
    public static let minRows = 1

    public static func cellWidth(glyphWidth: Double) -> Double {
        max(glyphWidth, 1)
    }

    public static func cellHeight(lineHeight: Double, cellWidth: Double) -> Double {
        max(lineHeight * lineHeightMultiple, cellWidth * minHeightToWidth)
    }

    public static func columns(viewportWidth: Double, cellWidth: Double) -> Int {
        max(minColumns, Int((viewportWidth - inset * 2) / cellWidth))
    }

    public static func rows(viewportHeight: Double, cellHeight: Double) -> Int {
        max(minRows, Int((viewportHeight - inset * 2) / cellHeight))
    }

    public static func column(x: Double, cellWidth: Double) -> Int {
        Int(floor((x - inset) / cellWidth))
    }

    public static func row(y: Double, cellHeight: Double) -> Int {
        Int(floor((y - inset) / cellHeight))
    }
}

/// One prepared value per font size, plus a process-wide prepare hook (font registration).
/// `create` / `prepare` run while the lock is held so a size is materialized at most once.
public final class TerminalTypefaceMemo<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var prepared = false
    private var storage: [Double: Value] = [:]

    public init() {}

    public func prepare(_ body: () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        guard !prepared else { return }
        body()
        prepared = true
    }

    public func value(for size: Double, prepare: () -> Void, create: () -> Value) -> Value {
        lock.lock()
        defer { lock.unlock() }
        if !prepared {
            prepare()
            prepared = true
        }
        if let existing = storage[size] { return existing }
        let created = create()
        storage[size] = created
        return created
    }
}
