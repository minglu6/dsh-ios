import Foundation

public let codePreviewOrigin = "https://code-preview.invalid"
public let codePreviewAssetPrefix = "\(codePreviewOrigin)/code-preview/"
public let codePreviewURL = "\(codePreviewOrigin)/code-preview/index.html"

/// Exact generated asset names only, not a URL prefix or arbitrary filesystem path.
public func codePreviewAssetFor(url: String, mainFrame: Bool, assets: Set<String>) -> String? {
    if mainFrame { return url == codePreviewURL ? "index.html" : nil }
    if url == "\(codePreviewOrigin)/font/meslo.ttf" { return "@meslo" }
    guard url.hasPrefix(codePreviewAssetPrefix) else { return nil }
    let name = String(url.dropFirst(codePreviewAssetPrefix.count))
    return assets.contains(name) ? name : nil
}

/// JSON is an evaluateJavascript argument, never an HTML/template/script element.
public func codePreviewDocumentScript(path: String, text: String) -> String {
    let payload = jsonObjectKeeping(["path": .string(path), "text": .string(text)])
    guard let encoded = try? payload.encodeString() else {
        preconditionFailure("code preview document JSON must encode")
    }
    let escaped = encoded
        .replacingOccurrences(of: "\u{2028}", with: "\\u2028")
        .replacingOccurrences(of: "\u{2029}", with: "\\u2029")
    return "window.codePreview.setDocument(\(escaped));"
}
