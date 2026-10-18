import SwiftUI

/// Official desktop / Android `D.*` mapping onto SF Symbols. Layout-only; semantics stay the same.
enum D {
    static let goal = "target"
    static let plan = "doc.text"
    static let compact = "circle.circle"
    static let shield = "shield"
    static let search = "magnifyingglass"
    static let sliders = "slider.horizontal.3"
    static let newChat = "square.and.pencil"
    static let download = "square.and.arrow.down"
    static let paperPlane = "paperplane"
    static let terminal = "terminal"
    static let pin = "pin"
    static let pinFill = "pin.fill"
    static let archive = "archivebox"
    static let unarchive = "archivebox.fill"
    static let edit = "pencil"
    static let clock = "clock"
    static let agentPreset = "person.crop.circle"
    static let browse = "doc.text.magnifyingglass"
    static let close = "xmark"
    static let plus = "plus"
}

/// Desktop `IconPluginPinwheelOutlineRegular` / Android `dsh_plugin_pinwheel` (16×16 strokes).
struct PluginPinwheelIcon: View {
    var size: CGFloat = 16
    var color: Color = T.ink

    var body: some View {
        Canvas { context, canvasSize in
            let scale = min(canvasSize.width, canvasSize.height) / 16
            var ctx = context
            ctx.scaleBy(x: scale, y: scale)
            let stroke = StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round)
            for d in Self.blades {
                ctx.stroke(Path(SVGPath.cgPath(d)), with: .color(color), style: stroke)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private static let blades = [
        "M7.84457 5.06199C11.6605 4.93876 14.7962 6.14848 14.8484 7.76397C14.8875 8.97461 13.1838 10.0696 10.7215 10.5942",
        "M5.12742 8.07731C5.00419 4.26138 6.21391 1.12568 7.8294 1.07351C9.04004 1.03441 10.135 2.73808 10.6596 5.20037",
        "M8.02457 10.6802C4.20865 10.8034 1.07294 9.5937 1.02077 7.97821C0.981678 6.76758 2.68535 5.67262 5.14763 5.14798",
        "M10.7476 7.89535C10.8708 11.7113 9.66109 14.847 8.0456 14.8991C6.83496 14.9382 5.74 13.2346 5.21536 10.7723",
    ]
}
