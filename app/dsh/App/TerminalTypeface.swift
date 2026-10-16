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
        memo.value(for: Double(size), prepare: registerBundledFontNow, create: {
            makeResolved(ofSize: size)
        })
    }

    private static func registerBundledFontNow() {
        guard let url = bundledFontURL else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }

    private static func makeResolved(ofSize size: CGFloat) -> Resolved {
        let uiFont = makeUIFont(ofSize: size)
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

    private static func makeUIFont(ofSize size: CGFloat) -> UIFont {
        let primary = UIFont(name: TerminalTypefacePolicy.bundledPostScript, size: size)
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
}
