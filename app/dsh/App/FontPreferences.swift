import Foundation
import SwiftUI
import UIKit

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
    private enum Family {
        case system, serif, terminal, custom(String)
    }

    private struct NativeKey: Hashable {
        let value: String
        let monospace: Bool
        let size: CGFloat
        let terminalFamily: String
    }

    @MainActor private static var nativeFonts: [NativeKey: UIFont] = [:]

    static func text(size: CGFloat? = nil) -> Font {
        resolve(AppPrefs.textFontFamily, monospace: false, size: size ?? CGFloat(AppPrefs.fontSize))
    }
    static func code(size: CGFloat? = nil) -> Font {
        resolve(AppPrefs.codeFontFamily, monospace: true, size: size ?? CGFloat(AppPrefs.codeFontSize))
    }
    static func terminal() -> Font { resolve(AppPrefs.terminalFontFamily, monospace: true, size: CGFloat(AppPrefs.terminalFontSize)) }

    static func resolve(_ value: String, monospace: Bool, size: CGFloat) -> Font {
        switch family(value, monospace: monospace) {
        case .system: return .system(size: size)
        case .serif: return .system(size: size, design: .serif)
        case .terminal: return TerminalTypeface.font(ofSize: size)
        case .custom(let name): return .custom(name, size: size)
        }
    }

    @MainActor static func uiText(size: CGFloat? = nil) -> UIFont {
        uiResolve(AppPrefs.textFontFamily, monospace: false, size: size ?? CGFloat(AppPrefs.fontSize))
    }

    @MainActor static func uiCode(size: CGFloat? = nil) -> UIFont {
        uiResolve(AppPrefs.codeFontFamily, monospace: true, size: size ?? CGFloat(AppPrefs.codeFontSize))
    }

    @MainActor private static func uiResolve(_ value: String, monospace: Bool, size: CGFloat) -> UIFont {
        let key = NativeKey(value: value, monospace: monospace, size: size, terminalFamily: AppPrefs.terminalFontFamily)
        if let cached = nativeFonts[key] { return cached }
        let font: UIFont
        switch family(value, monospace: monospace) {
        case .system:
            font = .systemFont(ofSize: size)
        case .serif:
            let system = UIFont.systemFont(ofSize: size)
            font = UIFont(descriptor: system.fontDescriptor.withDesign(.serif) ?? system.fontDescriptor, size: size)
        case .terminal:
            font = TerminalTypeface.uiFont(ofSize: size)
        case .custom(let name):
            font = UIFont(name: name, size: size) ?? .systemFont(ofSize: size)
        }
        if nativeFonts.count >= 64 { nativeFonts.removeAll(keepingCapacity: true) }
        nativeFonts[key] = font
        return font
    }

    private static func family(_ value: String, monospace: Bool) -> Family {
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return monospace ? .terminal : .system
        }
        for entry in value.split(separator: ",") {
            let name = entry.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            switch name.lowercased() {
            case "serif", "ui-serif", "math", "fangsong": return .serif
            case "sans-serif", "system-ui", "ui-sans-serif", "ui-rounded", "-apple-system", "blinkmacsystemfont", "emoji":
                return .system
            case "monospace", "ui-monospace",
                 "meslolgl dz", "meslolgl dz nerd font", "meslolgl dz nerd font mono",
                 "meslolgs nf", "meslolgs nerd font":
                return .terminal
            default:
                return .custom(name)
            }
        }
        return monospace ? .terminal : .system
    }
}

func clampFontSize(_ value: Int, range: ClosedRange<Int>) -> Int {
    min(max(value, range.lowerBound), range.upperBound)
}
