import Foundation
import SwiftUI

private let genericFontNames: Set<String> = [
    "serif", "sans-serif", "monospace", "cursive", "fantasy", "system-ui", "ui-serif", "ui-sans-serif",
    "ui-monospace", "ui-rounded", "emoji", "math", "fangsong", "-apple-system", "blinkmacsystemfont",
]
private let unsafeFontCharacters = try! NSRegularExpression(pattern: #"[\"'\\<>\u0000-\u001f\u007f]"#)

/// Same persisted comma-separated list as desktop; empty selects the built-in stack.
func normalizeFontFamily(_ value: String) -> String {
    value.split(separator: ",").compactMap { item -> String? in
        var name = String(item)
        let ns = name as NSString
        name = unsafeFontCharacters.stringByReplacingMatches(in: name, range: NSRange(location: 0, length: ns.length), withTemplate: "")
        name = name.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { return nil }
        if genericFontNames.contains(name.lowercased()) { return name }
        return "\"\(name)\""
    }.joined(separator: ", ")
}

enum LocalFonts {
    static func text(size: CGFloat? = nil) -> Font {
        resolve(AppPrefs.textFontFamily, monospace: false, size: size ?? CGFloat(AppPrefs.fontSize))
    }
    /// Secondary conversation copy follows the user's text size without shrinking below 10 pt.
    static func secondaryText() -> Font {
        text(size: CGFloat(max(10, AppPrefs.fontSize - 2)))
    }
    static func code(size: CGFloat? = nil) -> Font {
        resolve(AppPrefs.codeFontFamily, monospace: true, size: size ?? CGFloat(AppPrefs.codeFontSize))
    }
    static func terminal() -> Font { resolve(AppPrefs.terminalFontFamily, monospace: true, size: CGFloat(AppPrefs.terminalFontSize)) }

    static func resolve(_ value: String, monospace: Bool, size: CGFloat) -> Font {
        let fallback: Font = monospace ? TerminalTypeface.font(ofSize: size) : .system(size: size)
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return fallback }
        for entry in value.split(separator: ",") {
            let name = entry.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            switch name.lowercased() {
            case "serif", "ui-serif", "math", "fangsong": return .system(size: size, design: .serif)
            case "sans-serif", "system-ui", "ui-sans-serif", "ui-rounded", "-apple-system", "blinkmacsystemfont", "emoji":
                return .system(size: size)
            case "monospace", "ui-monospace":
                return TerminalTypeface.font(ofSize: size)
            case "meslolgl dz", "meslolgl dz nerd font", "meslolgl dz nerd font mono",
                 "meslolgs nf", "meslolgs nerd font":
                return TerminalTypeface.font(ofSize: size)
            default:
                return .custom(name, size: size)
            }
        }
        return fallback
    }
}

func clampFontSize(_ value: Int, range: ClosedRange<Int>) -> Int {
    min(max(value, range.lowerBound), range.upperBound)
}
