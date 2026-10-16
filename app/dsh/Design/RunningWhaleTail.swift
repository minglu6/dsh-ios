import ImageIO
import SwiftUI
import UIKit
import DSHProtocol

/// Desktop `ui-chat` `RunningWhaleTail`: APNG alpha mask, static SVG when reduced-motion.
struct RunningWhaleTail: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if reduceMotion || RunningWhaleFrames.template == nil {
                RunningWhaleStill()
            } else if let template = RunningWhaleFrames.template {
                Image(uiImage: template)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            }
        }
        .frame(width: 14, height: 14)
        .foregroundStyle(T.accent)
        .accessibilityHidden(true)
    }
}

private struct RunningWhaleStill: View {
    var body: some View {
        Canvas { context, size in
            var transform = CGAffineTransform(scaleX: size.width / 16, y: size.height / 16)
            if let path = SVGPath.cgPath(runningWhaleRestPath).copy(using: &transform) {
                context.stroke(Path(path), with: .color(T.accent), lineWidth: max(1, size.width / 16))
            }
        }
    }
}

/// 60-frame / 50ms APNG shipped as `running-whale@2x.png` (desktop ui-chat).
enum RunningWhaleFrames {
    static let template: UIImage? = load()

    private static func load() -> UIImage? {
        let names = ["running-whale@2x", "running-whale"]
        let url = names.compactMap { Bundle.main.url(forResource: $0, withExtension: "png") }.first
        guard let url, let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let count = CGImageSourceGetCount(source)
        guard count > 0 else { return nil }
        var frames: [UIImage] = []
        var duration: TimeInterval = 0
        for index in 0..<count {
            guard let cg = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
            frames.append(UIImage(cgImage: cg).withRenderingMode(.alwaysTemplate))
            duration += frameDuration(source, index: index)
        }
        guard !frames.isEmpty else { return nil }
        if frames.count == 1 { return frames[0] }
        return UIImage.animatedImage(with: frames, duration: duration > 0 ? duration : Double(frames.count) * 0.05)
    }

    private static func frameDuration(_ source: CGImageSource, index: Int) -> TimeInterval {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any] else {
            return 0.05
        }
        let png = properties[kCGImagePropertyPNGDictionary] as? [CFString: Any]
        let num = (png?[kCGImagePropertyAPNGUnclampedDelayTime] as? NSNumber)
            ?? (png?[kCGImagePropertyAPNGDelayTime] as? NSNumber)
        if let num, num.doubleValue > 0 { return num.doubleValue }
        return 0.05
    }
}

