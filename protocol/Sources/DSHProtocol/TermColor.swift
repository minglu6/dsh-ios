import Foundation

/// Device-independent sRGB used by the Tokyo Night PTY palette.
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

/// Syntax/ANSI palette. Terminal default foreground and background follow live DSH aliases.
public enum TokyoNight {
    public static let bg = TermRGB.rgb(0x1A1B26)
    public static let fg = TermRGB.rgb(0xC0CAF5)
    public static let cursor = TermRGB.rgb(0xC0CAF5)
    public static let selection = TermRGB.rgb(0x33467C)
    /// ANSI 0–15.
    public static let ansi: [TermRGB] = [
        .rgb(0x15161E),
        .rgb(0xF7768E),
        .rgb(0x9ECE6A),
        .rgb(0xE0AF68),
        .rgb(0x7AA2F7),
        .rgb(0xBB9AF7),
        .rgb(0x7DCFFF),
        .rgb(0xA9B1D6),
        .rgb(0x414868),
        .rgb(0xF7768E),
        .rgb(0x9ECE6A),
        .rgb(0xE0AF68),
        .rgb(0x7AA2F7),
        .rgb(0xBB9AF7),
        .rgb(0x7DCFFF),
        .rgb(0xC0CAF5),
    ]
}

public func xterm256(_ n: Int) -> TermRGB {
    if n < 16 { return TokyoNight.ansi[n] }
    if n < 232 {
        let i = n - 16
        func c(_ v: Int) -> Double { Double(v == 0 ? 0 : 55 + v * 40) / 255 }
        return TermRGB(r: c(i / 36), g: c((i / 6) % 6), b: c(i % 6))
    }
    let g = Double(8 + (n - 232) * 10) / 255
    return TermRGB(r: g, g: g, b: g)
}
