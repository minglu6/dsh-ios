import CoreGraphics
import Foundation

/// SVG path `d` → `CGPath`. Official wordmark and plugin artwork are SVG path data.
enum SVGPath {
    static func cgPath(_ d: String) -> CGPath {
        let path = CGMutablePath()
        var i = d.startIndex
        var command: Character = " "
        var current = CGPoint.zero
        var start = CGPoint.zero
        var lastCubic: CGPoint?
        var lastQuad: CGPoint?

        func skip() {
            while i < d.endIndex, d[i].isWhitespace || d[i] == "," { i = d.index(after: i) }
        }
        func nextNumber() -> CGFloat? {
            skip()
            guard i < d.endIndex else { return nil }
            let startIndex = i
            if d[i] == "+" || d[i] == "-" { i = d.index(after: i) }
            var seenDot = false
            var seenExp = false
            while i < d.endIndex {
                let c = d[i]
                if c.isNumber {
                    i = d.index(after: i)
                } else if c == "." && !seenDot && !seenExp {
                    seenDot = true
                    i = d.index(after: i)
                } else if (c == "e" || c == "E") && !seenExp {
                    seenExp = true
                    i = d.index(after: i)
                    if i < d.endIndex, d[i] == "+" || d[i] == "-" { i = d.index(after: i) }
                } else {
                    break
                }
            }
            if startIndex == i { return nil }
            return Double(d[startIndex..<i]).map { CGFloat($0) }
        }
        func nextPair() -> CGPoint? {
            guard let x = nextNumber(), let y = nextNumber() else { return nil }
            return CGPoint(x: x, y: y)
        }
        func isCommand(_ c: Character) -> Bool {
            "MmLlHhVvCcSsQqTtAaZz".contains(c)
        }

        skip()
        while i < d.endIndex {
            if isCommand(d[i]) {
                command = d[i]
                i = d.index(after: i)
            } else if command == " " {
                break
            }
            let relative = command.isLowercase
            guard let kind = command.uppercased().first else { return path }
            switch kind {
            case "M":
                guard var p = nextPair() else { return path }
                if relative { p.x += current.x; p.y += current.y }
                path.move(to: p)
                current = p
                start = p
                lastCubic = nil
                lastQuad = nil
                command = relative ? "l" : "L"
            case "L":
                guard var p = nextPair() else { return path }
                if relative { p.x += current.x; p.y += current.y }
                path.addLine(to: p)
                current = p
                lastCubic = nil
                lastQuad = nil
            case "H":
                guard var x = nextNumber() else { return path }
                if relative { x += current.x }
                current = CGPoint(x: x, y: current.y)
                path.addLine(to: current)
                lastCubic = nil
                lastQuad = nil
            case "V":
                guard var y = nextNumber() else { return path }
                if relative { y += current.y }
                current = CGPoint(x: current.x, y: y)
                path.addLine(to: current)
                lastCubic = nil
                lastQuad = nil
            case "C":
                guard var c1 = nextPair(), var c2 = nextPair(), var p = nextPair() else { return path }
                if relative {
                    c1.x += current.x; c1.y += current.y
                    c2.x += current.x; c2.y += current.y
                    p.x += current.x; p.y += current.y
                }
                path.addCurve(to: p, control1: c1, control2: c2)
                lastCubic = c2
                lastQuad = nil
                current = p
            case "S":
                guard var c2 = nextPair(), var p = nextPair() else { return path }
                if relative {
                    c2.x += current.x; c2.y += current.y
                    p.x += current.x; p.y += current.y
                }
                let c1: CGPoint
                if let last = lastCubic {
                    c1 = CGPoint(x: 2 * current.x - last.x, y: 2 * current.y - last.y)
                } else {
                    c1 = current
                }
                path.addCurve(to: p, control1: c1, control2: c2)
                lastCubic = c2
                lastQuad = nil
                current = p
            case "Q":
                guard var c = nextPair(), var p = nextPair() else { return path }
                if relative {
                    c.x += current.x; c.y += current.y
                    p.x += current.x; p.y += current.y
                }
                path.addQuadCurve(to: p, control: c)
                lastQuad = c
                lastCubic = nil
                current = p
            case "T":
                guard var p = nextPair() else { return path }
                if relative { p.x += current.x; p.y += current.y }
                let c: CGPoint
                if let last = lastQuad {
                    c = CGPoint(x: 2 * current.x - last.x, y: 2 * current.y - last.y)
                } else {
                    c = current
                }
                path.addQuadCurve(to: p, control: c)
                lastQuad = c
                lastCubic = nil
                current = p
            case "A":
                guard let rx = nextNumber(), let ry = nextNumber(), let rotation = nextNumber(),
                      let large = nextNumber(), let sweep = nextNumber(), var dest = nextPair()
                else { return path }
                if relative { dest.x += current.x; dest.y += current.y }
                addArc(path, from: current, to: dest, rx: abs(rx), ry: abs(ry), rotation: rotation * .pi / 180,
                       large: large != 0, sweep: sweep != 0)
                current = dest
                lastCubic = nil
                lastQuad = nil
            case "Z":
                path.closeSubpath()
                current = start
                lastCubic = nil
                lastQuad = nil
            default:
                return path
            }
            skip()
        }
        return path
    }

    static func rect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, radius: CGFloat) -> CGPath {
        CGPath(roundedRect: CGRect(x: x, y: y, width: width, height: height), cornerWidth: radius, cornerHeight: radius, transform: nil)
    }
}

private func addArc(_ path: CGMutablePath, from: CGPoint, to: CGPoint, rx: CGFloat, ry: CGFloat, rotation: CGFloat, large: Bool, sweep: Bool) {
    if rx == 0 || ry == 0 {
        path.addLine(to: to)
        return
    }
    let dx = (from.x - to.x) / 2
    let dy = (from.y - to.y) / 2
    let cosφ = cos(rotation)
    let sinφ = sin(rotation)
    let x1 = cosφ * dx + sinφ * dy
    let y1 = -sinφ * dx + cosφ * dy
    var rxk = rx
    var ryk = ry
    let λ = (x1 * x1) / (rxk * rxk) + (y1 * y1) / (ryk * ryk)
    if λ > 1 {
        let s = sqrt(λ)
        rxk *= s
        ryk *= s
    }
    let rx2 = rxk * rxk
    let ry2 = ryk * ryk
    let n = rx2 * ry2 - rx2 * y1 * y1 - ry2 * x1 * x1
    let d = rx2 * y1 * y1 + ry2 * x1 * x1
    var t = d == 0 ? 0 : sqrt(max(0, n / d))
    if large == sweep { t = -t }
    let cx1 = t * rxk * y1 / ryk
    let cy1 = t * -ryk * x1 / rxk
    let cx = cosφ * cx1 - sinφ * cy1 + (from.x + to.x) / 2
    let cy = sinφ * cx1 + cosφ * cy1 + (from.y + to.y) / 2
    func angle(_ u: CGPoint, _ v: CGPoint) -> CGFloat {
        let sign: CGFloat = (u.x * v.y - u.y * v.x) < 0 ? -1 : 1
        let mag = sqrt(u.x * u.x + u.y * u.y) * sqrt(v.x * v.x + v.y * v.y)
        if mag == 0 { return 0 }
        return sign * acos(min(1, max(-1, (u.x * v.x + u.y * v.y) / mag)))
    }
    let v1 = CGPoint(x: (x1 - cx1) / rxk, y: (y1 - cy1) / ryk)
    let v2 = CGPoint(x: (-x1 - cx1) / rxk, y: (-y1 - cy1) / ryk)
    let θ1 = angle(CGPoint(x: 1, y: 0), v1)
    var Δθ = angle(v1, v2)
    if !sweep && Δθ > 0 { Δθ -= 2 * .pi }
    if sweep && Δθ < 0 { Δθ += 2 * .pi }
    let segments = max(1, Int(ceil(abs(Δθ) / (.pi / 2))))
    let step = Δθ / CGFloat(segments)
    for i in 0..<segments {
        let a1 = θ1 + CGFloat(i) * step
        let α = sin(step) * (sqrt(4 + 3 * tan(step / 2) * tan(step / 2)) - 1) / 3
        func point(_ a: CGFloat) -> CGPoint {
            CGPoint(
                x: cosφ * rxk * cos(a) - sinφ * ryk * sin(a) + cx,
                y: sinφ * rxk * cos(a) + cosφ * ryk * sin(a) + cy
            )
        }
        func tangent(_ a: CGFloat) -> CGPoint {
            CGPoint(
                x: -cosφ * rxk * sin(a) - sinφ * ryk * cos(a),
                y: -sinφ * rxk * sin(a) + cosφ * ryk * cos(a)
            )
        }
        let p1 = point(a1)
        let p2 = point(a1 + step)
        let t1 = tangent(a1)
        let t2 = tangent(a1 + step)
        path.addCurve(
            to: p2,
            control1: CGPoint(x: p1.x + α * t1.x, y: p1.y + α * t1.y),
            control2: CGPoint(x: p2.x - α * t2.x, y: p2.y - α * t2.y)
        )
    }
}
