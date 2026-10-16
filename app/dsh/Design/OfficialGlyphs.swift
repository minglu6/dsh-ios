import SwiftUI
import DSHProtocol

/// Desktop primitives permission / think / agent-preset artwork, 16×16 view box.
struct OfficialGlyph: View {
    enum Kind {
        case think
        case agentPreset
        case permission(String)
    }

    let kind: Kind
    var size: CGFloat = 14
    var color: Color = T.text3

    var body: some View {
        Canvas { context, canvas in
            let scale = min(canvas.width, canvas.height) / 16
            var ctx = context
            ctx.scaleBy(x: scale, y: scale)
            let stroke = StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round)
            switch kind {
            case .think:
                ctx.stroke(Path(SVGPath.cgPath(Self.thinkOrbitA)), with: .color(color), style: stroke)
                ctx.stroke(Path(SVGPath.cgPath(Self.thinkOrbitB)), with: .color(color), style: stroke)
                ctx.fill(Path(SVGPath.cgPath(Self.thinkCore)), with: .color(color))
            case .agentPreset:
                ctx.fill(Path(SVGPath.cgPath(Self.presetFill)), with: .color(color))
                ctx.stroke(Path(SVGPath.cgPath(Self.presetHead)), with: .color(color), style: stroke)
                ctx.stroke(Path(SVGPath.cgPath(Self.presetLeft)), with: .color(color), style: stroke)
                ctx.stroke(Path(SVGPath.cgPath(Self.presetRight)), with: .color(color), style: stroke)
            case .permission(let value):
                drawPermission(&ctx, value: value, color: color, stroke: stroke)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func drawPermission(_ ctx: inout GraphicsContext, value: String, color: Color, stroke: StrokeStyle) {
        switch value {
        case "read-only":
            ctx.stroke(Path(SVGPath.cgPath(Self.readCheck)), with: .color(color), style: stroke)
            ctx.stroke(Path(SVGPath.cgPath(Self.shield)), with: .color(color), style: StrokeStyle(lineWidth: 1, lineJoin: .round))
        case "workspace-write":
            ctx.fill(Path(SVGPath.cgPath(Self.writeShield)), with: .color(color))
            ctx.stroke(Path(SVGPath.cgPath(Self.writeLineA)), with: .color(color), style: stroke)
            ctx.stroke(Path(SVGPath.cgPath(Self.writeLineB)), with: .color(color), style: stroke)
            ctx.fill(Path(SVGPath.cgPath(Self.writePencil)), with: .color(color))
            ctx.fill(Path(SVGPath.cgPath(Self.writeBase)), with: .color(color))
        case "danger-full-access":
            ctx.stroke(Path(SVGPath.cgPath(Self.shield)), with: .color(color), style: StrokeStyle(lineWidth: 1, lineJoin: .round))
            ctx.stroke(Path(SVGPath.cgPath(Self.fullBangStem)), with: .color(color), style: stroke)
            ctx.stroke(Path(SVGPath.cgPath(Self.fullBangDot)), with: .color(color), style: stroke)
        case "auto":
            ctx.stroke(Path(SVGPath.cgPath(Self.shield)), with: .color(color), style: StrokeStyle(lineWidth: 1, lineJoin: .round))
            ctx.stroke(Path(SVGPath.cgPath(Self.autoA)), with: .color(color), style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
        default:
            break
        }
    }

    private static let thinkOrbitA = "M10.2854 5.71481C12.9673 8.39663 14.1182 11.5938 12.8562 12.8559C11.5942 14.1179 8.39706 12.9669 5.71518 10.2851C3.03333 7.60323 1.88236 4.40608 3.14441 3.14403C4.40644 1.882 7.6036 3.03297 10.2854 5.71481Z"
    private static let thinkOrbitB = "M10.2854 10.2851C7.6036 12.9669 4.40644 14.1179 3.14441 12.8559C1.88236 11.5938 3.03333 8.39663 5.71518 5.71481C8.39706 3.03297 11.5942 1.882 12.8562 3.14403C14.1182 4.40608 12.9673 7.60323 10.2854 10.2851Z"
    private static let thinkCore = "M8.86291 8.0002C8.86291 8.47549 8.47762 8.86087 8.00224 8.86087C7.52694 8.86087 7.1416 8.47549 7.1416 8.0002C7.1416 7.52485 7.52694 7.13953 8.00224 7.13953C8.47762 7.13953 8.86291 7.52485 8.86291 8.0002Z"
    private static let presetFill = "M6.51867 12.3282C7.29816 12.6011 8.16475 12.6514 9.02269 12.4216C9.57879 12.2726 10.0784 12.0185 10.5087 11.6888C10.7819 12.0555 11.1606 12.3304 11.5913 12.4805C10.9688 13.029 10.2149 13.4478 9.35911 13.6771C8.13946 14.0038 6.90632 13.8971 5.82126 13.4533C6.15821 13.1562 6.4021 12.7652 6.51867 12.3282ZM9.17629 2.89409C11.1101 3.34433 12.739 4.81872 13.2889 6.87043C13.4219 7.3665 13.4811 7.8649 13.4774 8.35466C13.0924 8.13213 12.6422 8.01837 12.1741 8.05276L12.1711 8.05257C12.1539 7.77199 12.109 7.48889 12.0334 7.20684C11.6363 5.72533 10.5048 4.6372 9.13549 4.22844C9.25559 3.87667 9.29214 3.49087 9.22309 3.09892C9.2108 3.02922 9.19451 2.96108 9.17629 2.89409ZM4.7311 3.89107L4.78302 4.11879C4.87648 4.4488 5.04146 4.74263 5.25579 4.98896C3.98078 6.01355 3.35848 7.72904 3.8089 9.41059C3.81828 9.44559 3.82866 9.48025 3.83885 9.51479C3.38217 9.61268 2.98548 9.84137 2.68107 10.1556C2.63414 10.022 2.5897 9.88632 2.55244 9.74726C1.93301 7.43489 2.86717 5.07173 4.71504 3.76697L4.7311 3.89107Z"
    private static let presetHead = "M7.99136 5.28105C8.87501 5.28105 9.59136 4.56471 9.59136 3.68105C9.59136 2.7974 8.87501 2.08105 7.99136 2.08105C7.1077 2.08105 6.39136 2.7974 6.39136 3.68105C6.39136 4.56471 7.1077 5.28105 7.99136 5.28105Z"
    private static let presetLeft = "M3.94009 12.9417C4.82374 12.9417 5.54009 12.2254 5.54009 11.3417C5.54009 10.458 4.82374 9.7417 3.94009 9.7417C3.05643 9.7417 2.34009 10.458 2.34009 11.3417C2.34009 12.2254 3.05643 12.9417 3.94009 12.9417Z"
    private static let presetRight = "M12.0851 12.9417C12.9688 12.9417 13.6851 12.2254 13.6851 11.3417C13.6851 10.458 12.9688 9.7417 12.0851 9.7417C11.2015 9.7417 10.4851 10.458 10.4851 11.3417C10.4851 12.2254 11.2015 12.9417 12.0851 12.9417Z"
    private static let readCheck = "M5.08545 8.13775L7.18455 10.2368C7.26636 10.3187 7.4003 10.3142 7.47649 10.2271L11.5148 5.61194"
    private static let shield = "M6.59624 2.14853C7.50155 1.80917 8.49914 1.80919 9.40444 2.14859L13.9245 3.84317V7.11961C13.9245 11.6089 10.5565 13.5975 8.00035 14.5779C5.44423 13.5975 2.07544 11.6089 2.07544 7.11961V3.84317L6.59624 2.14853Z"
    private static let writeShield = "M6.4209 1.68067C7.43922 1.299 8.56177 1.29898 9.58008 1.68067L14.0996 3.375C14.2946 3.44811 14.4236 3.63455 14.4238 3.84278V6.89063C14.1115 6.71853 13.7761 6.58312 13.4238 6.48926V4.18946L9.22852 2.61621C8.43657 2.31947 7.56341 2.31939 6.77148 2.61621L2.5752 4.18946V7.11914C2.5752 11.1796 5.52369 13.056 8 14.0391C8.27653 13.9293 8.55827 13.8067 8.8418 13.6729C9.07101 13.9468 9.33228 14.1929 9.62012 14.4053C9.12409 14.6579 8.63578 14.8696 8.17871 15.0449C8.0637 15.0889 7.93628 15.0889 7.82129 15.0449C5.22011 14.0472 1.5752 11.9381 1.5752 7.11914V3.84278C1.57541 3.63469 1.70463 3.44821 1.89941 3.375L6.4209 1.68067Z"
    private static let writeLineA = "M5.26392 6.60339H10.7361"
    private static let writeLineB = "M5.26392 9.86902H8.32833"
    private static let writePencil = "M10.0317 13.2229C10.263 13.3929 10.4943 13.563 10.7256 13.733C10.7932 13.6482 10.8608 13.5634 10.9284 13.4786C12.1455 11.9522 13.3626 10.4258 14.5798 8.89935C14.6474 8.81455 14.715 8.72975 14.7826 8.64495C14.4143 8.37419 14.046 8.10344 13.6777 7.83268C13.6169 7.92252 13.5562 8.01236 13.4954 8.10219C12.4016 9.71926 11.3078 11.3363 10.214 12.9534C10.1532 13.0432 10.0924 13.1331 10.0317 13.2229Z"
    private static let writeBase = "M12.6516 12.6696C12.6516 12.925 12.6516 13.1804 12.6516 13.4359C12.6952 13.4378 12.7387 13.4398 12.7823 13.4417C13.5663 13.4768 14.3504 13.5118 15.1345 13.5469C15.178 13.5488 15.2216 13.5508 15.2651 13.5527C15.2651 13.2194 15.2651 12.8861 15.2651 12.5527C15.2216 12.5547 15.178 12.5566 15.1345 12.5586C14.3504 12.5936 13.5663 12.6287 12.7823 12.6637C12.7387 12.6657 12.6952 12.6676 12.6516 12.6696Z"
    private static let fullBangStem = "M8 4.39209V9.89209"
    private static let fullBangDot = "M8 10.8081V11.8081"
    private static let autoA = "M5.75 10.15L8 4.95L10.25 10.15M6.43 8.59H9.57"
}
