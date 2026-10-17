import CoreText
import SwiftUI
import UIKit
import DSHProtocol

enum TerminalTypeface {
    struct Resolved {
        let uiFont: UIFont
        let font: Font
        let cellWidth: CGFloat
        let cellHeight: CGFloat
    }

    private static let memo = TerminalTypefaceMemo<Resolved>()

    static var bundledFontURL: URL? {
        Bundle.main.url(
            forResource: TerminalTypefacePolicy.fileName,
            withExtension: TerminalTypefacePolicy.fileExtension,
            subdirectory: TerminalTypefacePolicy.bundleSubdirectory
        ) ?? Bundle.main.url(
            forResource: TerminalTypefacePolicy.fileName,
            withExtension: TerminalTypefacePolicy.fileExtension
        )
    }

    static func bundledFontData() -> Data? {
        bundledFontURL.flatMap { try? Data(contentsOf: $0) }
    }

    static func registerBundledFont() {
        memo.prepare(registerBundledFontNow)
    }

    static func uiFont(ofSize size: CGFloat) -> UIFont {
        resolved(ofSize: size).uiFont
    }

    static func font(ofSize size: CGFloat) -> Font {
        resolved(ofSize: size).font
    }

    static func resolved(ofSize size: CGFloat) -> Resolved {
        let family = AppPrefs.terminalFontFamily
        return memo.value(for: Double(size), family: family, prepare: registerBundledFontNow, create: {
            makeResolved(ofSize: size, family: family)
        })
    }

    private static func registerBundledFontNow() {
        guard let url = bundledFontURL else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }

    private static func makeResolved(ofSize size: CGFloat, family: String) -> Resolved {
        let uiFont = makeUIFont(ofSize: size, family: family)
        let cellWidth = CGFloat(TerminalCellLayout.cellWidth(
            glyphWidth: Double("M".size(withAttributes: [.font: uiFont]).width)
        ))
        let cellHeight = CGFloat(TerminalCellLayout.cellHeight(
            lineHeight: Double(uiFont.lineHeight),
            cellWidth: Double(cellWidth)
        ))
        return Resolved(
            uiFont: uiFont,
            font: Font(uiFont as CTFont),
            cellWidth: cellWidth,
            cellHeight: cellHeight
        )
    }

    private static func makeUIFont(ofSize size: CGFloat, family: String) -> UIFont {
        let primary = preferredTerminalFont(family, size: size)
            ?? UIFont(name: TerminalTypefacePolicy.bundledPostScript, size: size)
            ?? UIFont(name: TerminalTypefacePolicy.bundledFamily, size: size)
            ?? UIFont.monospacedSystemFont(ofSize: size, weight: .regular)
        let cascade = TerminalTypefacePolicy.cascadeFamilies.compactMap { name -> CTFontDescriptor? in
            CTFontCopyFontDescriptor(CTFontCreateWithName(name as CFString, size, nil))
        }
        let attributes: [UIFontDescriptor.AttributeName: Any] = [
            UIFontDescriptor.AttributeName(rawValue: kCTFontCascadeListAttribute as String): cascade,
        ]
        return UIFont(descriptor: primary.fontDescriptor.addingAttributes(attributes), size: size)
    }

    private static func preferredTerminalFont(_ value: String, size: CGFloat) -> UIFont? {
        for entry in value.split(separator: ",") {
            let name = entry.trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            if name.isEmpty { continue }
            switch name.lowercased() {
            case "monospace", "ui-monospace":
                return UIFont.monospacedSystemFont(ofSize: size, weight: .regular)
            case "menlo":
                if let font = UIFont(name: "Menlo-Regular", size: size) { return font }
            default:
                if let font = UIFont(name: name, size: size) { return font }
            }
        }
        return nil
    }
}
