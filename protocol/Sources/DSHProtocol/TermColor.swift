import Foundation

/// Device-independent sRGB used by the terminal palette.
public struct TermRGB: Equatable, Sendable {
    public var r: Double
    public var g: Double
    public var b: Double
    public var a: Double

    public init(r: Double, g: Double, b: Double, a: Double = 1) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    public static func rgb(_ hex: UInt32) -> TermRGB {
        TermRGB(
            r: Double((hex >> 16) & 0xFF) / 255,
            g: Double((hex >> 8) & 0xFF) / 255,
            b: Double(hex & 0xFF) / 255,
            a: 1
        )
    }

    public func withAlpha(_ alpha: Double) -> TermRGB {
        TermRGB(r: r, g: g, b: b, a: alpha)
    }
}

/// Desktop xterm.js Tango ANSI 16. Default fg/bg follow the live appearance, not these slots.
public enum Tango {
    /// ANSI 0–15 (black / chromatic / white + bright).
    public static let ansi: [TermRGB] = [
        .rgb(0x2E3436),
        .rgb(0xCC0000),
        .rgb(0x4E9A06),
        .rgb(0xC4A000),
        .rgb(0x3465A4),
        .rgb(0x75507B),
        .rgb(0x06989A),
        .rgb(0xD3D7CF),
        .rgb(0x555753),
        .rgb(0xEF2929),
        .rgb(0x8AE234),
        .rgb(0xFCE94F),
        .rgb(0x729FCF),
        .rgb(0xAD7FA8),
        .rgb(0x34E2E2),
        .rgb(0xEEEEEC),
    ]
}

public func xterm256(_ n: Int) -> TermRGB {
    if n < 16 { return Tango.ansi[n] }
    if n < 232 {
        let i = n - 16
        func c(_ v: Int) -> Double { Double(v == 0 ? 0 : 55 + v * 40) / 255 }
        return TermRGB(r: c(i / 36), g: c((i / 6) % 6), b: c(i % 6))
    }
    let g = Double(8 + (n - 232) * 10) / 255
    return TermRGB(r: g, g: g, b: g)
}
