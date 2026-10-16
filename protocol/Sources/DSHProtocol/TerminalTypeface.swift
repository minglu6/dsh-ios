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
