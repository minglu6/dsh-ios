import SwiftUI
import DSHProtocol

/// Desktop sidebar `StateDot` (14px track + breathing arc) and completion green dot.
struct SidebarSessionLeadingView: View {
    let kind: SidebarSessionLeading
    var english: Bool = false

    var body: some View {
        ZStack {
            switch kind {
            case .idle:
                Color.clear
            case .unread:
                Circle()
                    .fill(T.ok)
                    .frame(
                        width: CGFloat(sidebarLeadingSlotHeightPoints) * CGFloat(sidebarCompletionDotRadiusRatio) * 2,
                        height: CGFloat(sidebarLeadingSlotHeightPoints) * CGFloat(sidebarCompletionDotRadiusRatio) * 2
                    )
                    .accessibilityLabel(sidebarCompletionUnreadLabel(english: english))
            case .running:
                SidebarActivitySpinner(color: T.text3)
                    .accessibilityLabel(sidebarRunningLabel(english: english))
            case .awaitingAnswer:
                Circle()
                    .fill(T.warnBorder)
                    .frame(
                        width: CGFloat(sidebarLeadingSlotHeightPoints) * CGFloat(sidebarCompletionDotRadiusRatio) * 2,
                        height: CGFloat(sidebarLeadingSlotHeightPoints) * CGFloat(sidebarCompletionDotRadiusRatio) * 2
                    )
                    .accessibilityLabel(sidebarAwaitingAnswerLabel(english: english))
            case .awaitingApproval:
                Circle()
                    .fill(T.warnBorder)
                    .frame(
                        width: CGFloat(sidebarLeadingSlotHeightPoints) * CGFloat(sidebarCompletionDotRadiusRatio) * 2,
                        height: CGFloat(sidebarLeadingSlotHeightPoints) * CGFloat(sidebarCompletionDotRadiusRatio) * 2
                    )
                    .accessibilityLabel(sidebarAwaitingApprovalLabel(english: english))
            }
        }
        .frame(width: CGFloat(sidebarLeadingSlotWidthPoints), height: CGFloat(sidebarLeadingSlotHeightPoints))
    }
}

private struct SidebarActivitySpinner: View {
    let color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let progress: CGFloat = reduceMotion
                ? 0.5
                : CGFloat(timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.5) / 1.5)
            Canvas { context, size in
                let unit = min(size.width, size.height) / 24
                let radius = 9.5 * unit
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                var track = Path()
                track.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
                context.stroke(track, with: .color(color.opacity(0.25)), style: StrokeStyle(lineWidth: 2 * unit, lineCap: .round))
                let breathT = progress < 0.5 ? progress * 2 : (1 - progress) * 2
                let breathing = breathT * breathT * (3 - 2 * breathT)
                let degreesPerUnit = CGFloat(180.0 / (Double.pi * 9.5))
                var arc = Path()
                arc.addArc(
                    center: center,
                    radius: radius,
                    startAngle: .degrees(Double(progress * 360 + 6 * breathing * degreesPerUnit)),
                    endAngle: .degrees(Double(progress * 360 + 6 * breathing * degreesPerUnit + (12 + 12 * breathing) * degreesPerUnit)),
                    clockwise: false
                )
                context.stroke(arc, with: .color(color), style: StrokeStyle(lineWidth: 2 * unit, lineCap: .round))
            }
        }
        .frame(width: CGFloat(sidebarLeadingSlotHeightPoints), height: CGFloat(sidebarLeadingSlotHeightPoints))
    }
}
