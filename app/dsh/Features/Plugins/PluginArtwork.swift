import SwiftUI
import WebKit
import DSHProtocol

/// Fixed-palette 36×36 artwork from desktop `plugin-artwork.tsx` / Android `PluginArtwork.kt`.
struct PluginArtwork: View {
    let kind: String
    var size: CGFloat = 36

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 36
            var ctx = context
            ctx.translateBy(x: (size.width - 36 * scale) / 2, y: (size.height - 36 * scale) / 2)
            ctx.scaleBy(x: scale, y: scale)
            drawPluginArtwork(ctx, kind: kind)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct PluginMetadataArtwork: View {
    let icon: String?
    var size: CGFloat = 36

    var body: some View {
        if let xml = pluginMetadataSVG(icon) {
            PluginSVGView(xml: xml).frame(width: size, height: size)
        } else {
            PluginArtwork(kind: "default", size: size)
        }
    }
}

private struct PluginSVGView: UIViewRepresentable {
    let xml: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        let view = WKWebView(frame: .zero, configuration: config)
        view.isOpaque = false
        view.backgroundColor = .clear
        view.scrollView.isScrollEnabled = false
        view.scrollView.backgroundColor = .clear
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        let html = "<html><head><meta name=viewport content='width=36,initial-scale=1'></head><body style='margin:0;background:transparent'>\(xml)</body></html>"
        view.loadHTMLString(html, baseURL: nil)
    }
}

private func drawPluginArtwork(_ context: GraphicsContext, kind: String) {
    switch kind {
    case "terminal":
        let paint = Color(hex: 0xFF679EFE)
        context.stroke(Path(SVGPath.cgPath("M10 11L16.606 17.606C16.6841 17.6841 16.6841 17.8107 16.606 17.8888L10 24.4948")), with: .color(paint), lineWidth: 3.5)
        context.stroke(Path(SVGPath.cgPath("M20.1211 24.4946H26.8685")), with: .color(paint), lineWidth: 3.5)
    case "loop":
        context.fill(Path(SVGPath.cgPath("M18.0486 28.4901C12.0858 28.4901 7.25195 23.6562 7.25195 17.6934C13.2148 17.6934 18.0486 22.5272 18.0486 28.4901Z")), with: .color(Color(hex: 0xFFA797FC)))
        context.fill(
            Path(SVGPath.cgPath("M18.0486 6.89667C12.0858 6.89667 7.25195 11.7305 7.25195 17.6934C13.2148 17.6934 18.0486 12.8595 18.0486 6.89667Z")),
            with: .linearGradient(
                Gradient(colors: [Color(hex: 0xFFA23AE7), Color(hex: 0xFFE2E2E2)]),
                startPoint: CGPoint(x: 16.7911, y: 16.1655),
                endPoint: CGPoint(x: 8.98192, y: 8.74289)
            )
        )
        context.fill(Path(SVGPath.cgPath("M18.0485 28.4901C24.0114 28.4901 28.8452 23.6562 28.8452 17.6934C22.8824 17.6934 18.0485 22.5272 18.0485 28.4901Z")), with: .color(Color(hex: 0xFF4561EE)))
        context.fill(Path(SVGPath.cgPath("M18.0485 6.89667C24.0114 6.89667 28.8452 11.7305 28.8452 17.6934C22.8824 17.6934 18.0485 12.8595 18.0485 6.89667Z")), with: .color(Color(hex: 0xFF658EFF)))
    case "subagent":
        context.fill(
            Path(SVGPath.rect(x: 14.9893, y: 15.1877, width: 12.2365, height: 12.2365, radius: 2)),
            with: .linearGradient(
                Gradient(colors: [Color(hex: 0xFF45E7A4).opacity(204 / 255), Color(hex: 0xFF05909D).opacity(204 / 255)]),
                startPoint: CGPoint(x: 21.1075, y: 15.1877),
                endPoint: CGPoint(x: 21.1075, y: 27.4243)
            )
        )
        context.fill(
            Path(SVGPath.rect(x: 8.87109, y: 9.0697, width: 12.2365, height: 12.2365, radius: 2)),
            with: .linearGradient(
                Gradient(colors: [Color(hex: 0xFF69B9FF).opacity(204 / 255), Color(hex: 0xFF324DE2).opacity(204 / 255)]),
                startPoint: CGPoint(x: 14.9894, y: 9.0697),
                endPoint: CGPoint(x: 14.9894, y: 21.3063)
            )
        )
    case "search":
        let ring = Path(SVGPath.cgPath(
            "M21.9717 16.2159H19.9717C19.9717 18.5386 18.0888 20.4215 15.7661 20.4215V22.4215V24.4215C20.2979 24.4215 23.9717 20.7478 23.9717 16.2159H21.9717Z" +
            "M15.7661 22.4215V20.4215C13.4434 20.4215 11.5605 18.5386 11.5605 16.2159H9.56055H7.56055C7.56055 20.7478 11.2343 24.4215 15.7661 24.4215V22.4215Z" +
            "M9.56055 16.2159H11.5605C11.5605 13.8933 13.4434 12.0104 15.7661 12.0104V10.0104V8.01038C11.2343 8.01038 7.56055 11.6841 7.56055 16.2159H9.56055Z" +
            "M15.7661 10.0104V12.0104C18.0888 12.0104 19.9717 13.8933 19.9717 16.2159H21.9717H23.9717C23.9717 11.6841 20.2979 8.01038 15.7661 8.01038V10.0104Z"
        ))
        context.fill(
            ring,
            with: .linearGradient(
                Gradient(colors: [Color(hex: 0xFF41E1AC), Color(hex: 0xFF658EFF)]),
                startPoint: CGPoint(x: 7.56, y: 16.22),
                endPoint: CGPoint(x: 24.0, y: 16.22)
            )
        )
        context.stroke(Path(SVGPath.cgPath("M26.5362 26.9865L22.3813 22.8317")), with: .color(Color(hex: 0xFF658EFF)), lineWidth: 3)
    default:
        context.fill(
            Path(SVGPath.cgPath(
                "M24.6294 8.63696C26.2862 8.63705 27.6294 9.98016 27.6294 11.637V12.7825C27.6292 14.4391 26.2861 15.7824 24.6294 15.7825H23.4839C22.6519 15.7825 21.5454 16.3459 21.5454 17.1778V18.1573C21.5454 18.7757 22.216 19.1966 22.8345 19.1965H24.6294C26.2861 19.1965 27.6292 20.5398 27.6294 22.1965V23.9924C27.6292 25.6491 26.2861 26.9924 24.6294 26.9924H22.8345C21.1778 26.9924 19.8347 25.649 19.8345 23.9924V22.1965C19.8345 21.7148 19.4957 21.2327 19.014 21.2327H16.4792C15.7975 21.2327 15.3374 22.0061 15.3374 22.6877V23.8333C15.3373 25.49 13.9942 26.8333 12.3374 26.8333H11.1919C9.53509 26.8333 8.19198 25.49 8.19189 23.8333V22.6877C8.19189 21.0309 9.53504 19.6877 11.1919 19.6877H12.3374C13.1964 19.6877 14.3999 19.0959 14.3999 18.2369V16.0185C14.3999 14.9518 15.2646 14.0872 16.3312 14.0872H19.435C20.0596 14.0872 20.484 13.4071 20.4839 12.7825V11.637C20.4839 9.98011 21.827 8.63696 23.4839 8.63696H24.6294Z" +
                "M13.4116 11.2468C13.4116 12.6882 12.2431 13.8567 10.8018 13.8567C9.36037 13.8567 8.19189 12.6882 8.19189 11.2468C8.19189 9.80544 9.36037 8.63696 10.8018 8.63696C12.2431 8.63696 13.4116 9.80544 13.4116 11.2468Z"
            )),
            with: .linearGradient(
                Gradient(colors: [Color(hex: 0xFF54ECE7), Color(hex: 0xFF658EFF)]),
                startPoint: CGPoint(x: 15.1481, y: 9.94188),
                endPoint: CGPoint(x: 15.1481, y: 13.6375)
            )
        )
    }
}
