import CoreText
import SwiftUI
import UIKit
import DSHProtocol

enum TerminalTypeface {
    private static var registered = false

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
        guard !registered else { return }
        registered = true
        guard let url = bundledFontURL else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }

    static func uiFont(ofSize size: CGFloat) -> UIFont {
        registerBundledFont()
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

    static func font(ofSize size: CGFloat) -> Font {
        Font(uiFont(ofSize: size) as CTFont)
    }
}
