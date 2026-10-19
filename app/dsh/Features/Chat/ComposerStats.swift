import SwiftUI
import DSHProtocol

private enum StatisticsDialog { case activity, usage, context }

private let statisticsContextColors: [Color] = [
    Color(red: 0.45, green: 0.55, blue: 0.72),
    Color(red: 0.655, green: 0.545, blue: 0.980),
    Color(red: 0.25, green: 0.53, blue: 0.96),
]

struct ComposerStats: View {
    let metrics: ComposerMetrics
    @State private var activityOpen = false
    @State private var usageOpen = false
    @State private var contextOpen = false

    private var detailed: Bool { AppModel.shared.performanceUsage == .detailed }
    private var activity: ComposerActivity? { metrics.activity }
    private var usage: ComposerTokenUsage? { metrics.tokens.flatMap { $0.totalTokens > 0 ? $0 : nil } }
    private var context: ComposerContext? { metrics.context }
    private var speed: String? { activity?.tokensPerSecond.map { "\(statisticsSpeed($0)) tok/s" } }
    private var cache: String? { usage?.cacheHitPercent.map { composerCacheHitPill(percent: $0, english: L.en) } }
    private var activityText: String? {
        if detailed {
            return activity.flatMap { $0.steps > 0
                ? [composerActivityCounts(turns: $0.turns, steps: $0.steps, english: L.en), speed]
                    .compactMap { $0 }
                    .joined(separator: " · ")
                : nil }
        }
        return speed
    }
    private var usageText: String? {
        if detailed { return usage.map { [ "\(statisticsTokens(Double($0.totalTokens))) \(composerStatisticsTokenUnit)", cache].compactMap { $0 }.joined(separator: " · ") } }
        return cache
    }
    private var activityHasDetails: Bool {
        guard let activity else { return false }
        return activity.llmMs > 0 || activity.toolMs > 0 || activity.ttftSteps > 0 || speed != nil
    }

    var body: some View {
        if activityText == nil && usageText == nil && context == nil {
            EmptyView()
        } else {
            HStack(spacing: 12) { pills }
            .frame(maxWidth: .infinity, alignment: .leading)
            .lineLimit(1)
            .padding(.horizontal, 14)
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private var pills: some View {
        if let activityText {
            pill(
                activityText,
                icon: .gaugeOutline,
                clickable: detailed && activityHasDetails,
                open: $activityOpen,
                opensAbove: composerActivityPopoverOpensAbove
            ) { toggle(.activity) } content: {
                activityPopover
            }
        }
        if let usageText {
            pill(
                usageText,
                icon: .databaseOutline,
                clickable: detailed,
                open: $usageOpen,
                opensAbove: composerUsagePopoverOpensAbove
            ) { toggle(.usage) } content: {
                if let usage { sessionUsagePopover(usage) }
            }
        }
        if let context {
            contextMeter(context)
        }
    }

    private func exclusive(_ dialog: StatisticsDialog) {
        activityOpen = dialog == .activity
        usageOpen = dialog == .usage
        contextOpen = dialog == .context
    }

    private func toggle(_ dialog: StatisticsDialog) {
        let alreadyOpen: Bool
        switch dialog {
        case .activity: alreadyOpen = activityOpen
        case .usage: alreadyOpen = usageOpen
        case .context: alreadyOpen = contextOpen
        }
        if alreadyOpen {
            activityOpen = false
            usageOpen = false
            contextOpen = false
            return
        }
        exclusive(dialog)
    }

    private func pill<Content: View>(
        _ text: String,
        icon: OfficialGlyph.Kind,
        clickable: Bool,
        open: Binding<Bool>,
        opensAbove: Bool,
        action: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                OfficialGlyph(kind: icon, size: CGFloat(composerStatisticsIconSizePoints), color: T.text3)
                Text(text).font(.caption).foregroundStyle(T.text3).lineLimit(1)
            }
            .padding(.vertical, 5)
        }
        .buttonStyle(.plain)
        .disabled(!clickable)
        .popover(isPresented: open, attachmentAnchor: .rect(.bounds), arrowEdge: opensAbove ? .bottom : .top) {
            content()
        }
    }

    @ViewBuilder
    private var activityPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            UsagePopoverHeader(
                icon: .gaugeOutline,
                title: composerActivityTitle(english: L.en)
            )
            if let activity {
                if activity.llmMs > 0 {
                    detail(composerActivityLlmTime(english: L.en), statisticsDuration(activity.llmMs))
                }
                if activity.toolMs > 0 {
                    detail(composerActivityToolTime(english: L.en), statisticsDuration(activity.toolMs))
                }
                if let ttft = activity.meanTtftMs {
                    detail(composerActivityTtft(english: L.en), statisticsDuration(ttft))
                }
                if let speed {
                    detail(composerActivitySpeed(english: L.en), speed)
                }
            }
        }
        .padding(16)
        .frame(minWidth: 240, maxWidth: 320)
        .modifier(PopoverCompactAdaptation())
    }

    private func contextMeter(_ context: ComposerContext) -> some View {
        let reading = "\(context.percent)%"
        return Button { toggle(.context) } label: {
            HStack(spacing: 4) {
                ComposerContextRing(percent: context.percent)
                Text(reading).font(.caption).foregroundStyle(T.text3).lineLimit(1)
            }
            .padding(.vertical, 5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(composerContextAria(percent: reading, english: L.en))
        .popover(
            isPresented: $contextOpen,
            attachmentAnchor: .rect(.bounds),
            arrowEdge: composerContextPopoverOpensAbove ? .bottom : .top
        ) {
            contextPopover(context)
        }
    }

    private func contextPopover(_ context: ComposerContext) -> some View {
        let headline = composerContextHeadline(english: L.en)
        let reading = "\(context.percent)%"
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                if !headline.before.isEmpty {
                    Text(headline.before).font(.subheadline.weight(.medium)).foregroundStyle(T.ink)
                }
                Text(reading).font(.subheadline.weight(.medium)).monospacedDigit().foregroundStyle(T.ink)
                if !headline.after.isEmpty {
                    Text(headline.after).font(.subheadline.weight(.medium)).foregroundStyle(T.ink)
                }
                Spacer(minLength: 12)
                Text("~\(statisticsTokens(context.usedTokens)) / \(statisticsTokens(context.contextWindow))")
                    .font(.subheadline.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(T.text2)
            }
            .accessibilityLabel(composerContextUsed(english: L.en))
            contextBar(context.percent)
            if let breakdown = metrics.contextBreakdown {
                detail(
                    composerContextBreakdownLabel(.system, english: L.en),
                    "~\(statisticsTokens(breakdown.systemTokens))",
                    statisticsContextColors[0]
                )
                detail(
                    composerContextBreakdownLabel(.tools, english: L.en),
                    "~\(statisticsTokens(breakdown.toolsTokens))",
                    statisticsContextColors[1]
                )
                detail(
                    composerContextBreakdownLabel(.messages, english: L.en),
                    "~\(statisticsTokens(breakdown.messageTokens))",
                    statisticsContextColors[2]
                )
            }
        }
        .padding(16)
        .frame(minWidth: 240, maxWidth: 320)
        .modifier(PopoverCompactAdaptation())
    }

    /// Desktop session usage chip: anchored above, icon + title left, total right.
    private func sessionUsagePopover(_ usage: ComposerTokenUsage) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            UsagePopoverHeader(
                title: composerSessionUsageTitle(english: L.en),
                value: composerSessionUsageTitleValue(exactTotal: statisticsExact(usage.totalTokens))
            )
            if let hit = usage.cacheHitPercent {
                detail(composerSessionUsageRowLabel(.cacheHit, english: L.en), "\(hit)%")
            }
            detail(
                composerSessionUsageRowLabel(.uncachedInput, english: L.en),
                composerSessionUsageTokenValue(exact: statisticsExact(usage.uncachedInputTokens))
            )
            detail(
                composerSessionUsageRowLabel(.cacheRead, english: L.en),
                composerSessionUsageTokenValue(exact: statisticsExact(usage.cacheReadTokens))
            )
            if usage.cacheWriteTokens != 0 {
                detail(
                    composerSessionUsageRowLabel(.cacheWrite, english: L.en),
                    composerSessionUsageTokenValue(exact: statisticsExact(usage.cacheWriteTokens))
                )
            }
            detail(
                composerSessionUsageRowLabel(.output, english: L.en),
                composerSessionUsageTokenValue(exact: statisticsExact(usage.outputTokens))
            )
        }
        .padding(16)
        .frame(minWidth: 240, maxWidth: 320)
        .modifier(PopoverCompactAdaptation())
    }

    private func detail(_ label: String, _ value: String, _ swatch: Color? = nil) -> some View {
        HStack {
            if let swatch { RoundedRectangle(cornerRadius: 1).fill(swatch).frame(width: 8, height: 8) }
            Text(label).foregroundStyle(T.text2)
            Spacer()
            Text(value).foregroundStyle(T.ink)
        }
        .font(.subheadline)
    }

    private func contextBar(_ percent: Int) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                T.hoverBg
                if percent > 0 {
                    let width = geo.size.width * CGFloat(percent) / 100
                    if let breakdown = metrics.contextBreakdown {
                        let total = breakdown.systemTokens + breakdown.toolsTokens + breakdown.messageTokens
                        if total > 0 {
                            HStack(spacing: 0) {
                                ForEach(Array([breakdown.systemTokens, breakdown.toolsTokens, breakdown.messageTokens].enumerated()), id: \.offset) { index, tokens in
                                    statisticsContextColors[index].frame(width: width * CGFloat(tokens / total))
                                }
                            }
                        } else {
                            T.text3.frame(width: width)
                        }
                    } else {
                        T.text3.frame(width: width)
                    }
                }
            }
        }
        .frame(height: 4)
    }
}

struct TurnUsageAction: View {
    let turn: Int
    let usage: TurnTokenUsage
    @State private var expanded = false

    var body: some View {
        let count = composerSessionUsageTokenValue(exact: statisticsTokens(Double(usage.totalTokens)))
        let label = composerTurnUsageConsumed(total: count, english: L.en)
        Button { expanded.toggle() } label: {
            HStack(spacing: 4) {
                OfficialGlyph(kind: .databaseOutline, size: CGFloat(composerStatisticsIconSizePoints), color: T.text3)
                Text(label).font(.caption).foregroundStyle(T.text3).lineLimit(1)
            }
            .padding(.leading, 11)
            .padding(.trailing, 2)
            .padding(.vertical, 5)
            .background(expanded ? T.hoverBg : Color.clear, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: 180, minHeight: 48)
        .popover(isPresented: $expanded, attachmentAnchor: .rect(.bounds), arrowEdge: composerUsagePopoverOpensAbove ? .bottom : .top) {
            VStack(alignment: .leading, spacing: 10) {
                UsagePopoverHeader(
                    title: composerTurnUsageTitle(english: L.en),
                    value: composerSessionUsageTitleValue(exactTotal: statisticsExact(usage.totalTokens))
                )
                if let routes = usage.routes, !routes.isEmpty {
                    row(composerTurnUsageModelLabel(english: L.en), routes.map { "\($0.provider)/\($0.model)" }.joined(separator: ", "))
                }
                let promptTokens = usage.totalTokens - usage.outputTokens
                if let cached = usage.cacheReadTokens, promptTokens > 0 {
                    row(composerSessionUsageRowLabel(.cacheHit, english: L.en), String(format: "%.1f%%", Double(cached) / Double(promptTokens) * 100))
                }
                row(composerSessionUsageRowLabel(.uncachedInput, english: L.en), composerSessionUsageTokenValue(exact: statisticsExact(usage.uncachedInputTokens)))
                if let read = usage.cacheReadTokens {
                    row(composerSessionUsageRowLabel(.cacheRead, english: L.en), composerSessionUsageTokenValue(exact: statisticsExact(read)))
                }
                if let write = usage.cacheWriteTokens {
                    row(composerSessionUsageRowLabel(.cacheWrite, english: L.en), composerSessionUsageTokenValue(exact: statisticsExact(write)))
                }
                outputRow
            }
            .font(.subheadline)
            .padding(16)
            .frame(minWidth: 240, maxWidth: 320)
            .modifier(PopoverCompactAdaptation())
        }
        .onChange(of: turn) { _ in expanded = false }
    }

    private var outputRow: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(composerSessionUsageRowLabel(.output, english: L.en)).foregroundStyle(T.text2)
            Spacer()
            HStack(spacing: 0) {
                Text(composerSessionUsageTokenValue(exact: statisticsExact(usage.outputTokens))).foregroundStyle(T.ink)
                if let reasoning = usage.reasoningTokens {
                    Text(composerTurnUsageReasoning(
                        tokens: composerSessionUsageTokenValue(exact: statisticsExact(reasoning)),
                        english: L.en
                    ))
                    .foregroundStyle(T.text3)
                }
            }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(T.text2)
            Spacer()
            Text(value).foregroundStyle(T.ink)
        }
    }
}

/// Desktop `stat-dialog` heading: section icon + name left, exact total right.
private struct UsagePopoverHeader: View {
    var icon: OfficialGlyph.Kind = .databaseOutline
    let title: String
    var value: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 6) {
                OfficialGlyph(kind: icon, size: CGFloat(composerStatisticsIconSizePoints), color: T.ink)
                Text(title).font(.subheadline.weight(.medium)).foregroundStyle(T.ink)
                Spacer(minLength: 16)
                if let value {
                    Text(value).font(.subheadline.weight(.medium)).monospacedDigit().foregroundStyle(T.ink)
                }
            }
            Divider()
        }
    }
}

/// Desktop `ContextMeter` 14px ring (`r=5.5`, 2px stroke, start at 12 o'clock).
private struct ComposerContextRing: View {
    let percent: Int

    var body: some View {
        let size = CGFloat(composerContextRingSizePoints)
        let stroke = CGFloat(composerContextRingStrokePoints)
        let diameter = CGFloat(composerContextRingRadiusPoints) * 2
        ZStack {
            Circle()
                .stroke(T.borderL3, lineWidth: stroke)
            Circle()
                .trim(from: 0, to: CGFloat(min(100, max(0, percent))) / 100)
                .stroke(
                    T.ink,
                    style: StrokeStyle(
                        lineWidth: stroke,
                        lineCap: composerContextRingFillLineCapRound ? .round : .butt
                    )
                )
                .rotationEffect(.degrees(-90))
        }
        .frame(width: diameter, height: diameter)
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

func statisticsRounded(_ value: Double, decimals: Int) -> String {
    let scale: Double = decimals == 0 ? 1 : 10
    let rounded = floor(value * scale + 0.5) / scale
    return rounded.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(rounded)) : String(format: "%.1f", rounded)
}

func statisticsSpeed(_ value: Double) -> String { statisticsRounded(value, decimals: value >= 10 ? 0 : 1) }

func statisticsTokens(_ value: Double) -> String {
    switch value {
    case ..<1000: return statisticsRounded(value, decimals: 0)
    case ..<1_000_000:
        let scaled = value / 1000
        return statisticsRounded(scaled, decimals: scaled >= 100 ? 0 : 1) + "K"
    default:
        let scaled = value / 1_000_000
        return statisticsRounded(scaled, decimals: scaled >= 100 ? 0 : 1) + "M"
    }
}

func statisticsExact(_ value: Int64) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.locale = Locale(identifier: "en_US")
    return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
}

func statisticsDuration(_ milliseconds: Double) -> String {
    let seconds = milliseconds / 1000
    if seconds < 60 { return "\(statisticsRounded(seconds, decimals: 1))s" }
    let whole = Int64(floor(seconds + 0.5))
    return "\(whole / 60)m\(whole % 60)s"
}
