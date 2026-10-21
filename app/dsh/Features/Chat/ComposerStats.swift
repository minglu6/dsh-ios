import SwiftUI
import UIKit
import DSHProtocol

private enum StatisticsDialog { case activity, usage, context }

private let statisticsContextColors: [Color] = [
    Color(red: 0.45, green: 0.55, blue: 0.72),
    Color(red: 0.655, green: 0.545, blue: 0.980),
    Color(red: 0.25, green: 0.53, blue: 0.96),
]

struct ComposerStats: View {
    let metrics: ComposerMetrics
    @ObservedObject var settings: HostSettings
    @State private var activityOpen = false
    @State private var usageOpen = false
    @State private var contextOpen = false

    private var detailed: Bool { settings.value(.performance)?.str() == "detailed" }
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
    private var screenWidth: Double { UIScreen.main.bounds.width }
    private var statDialogMinWidth: CGFloat { CGFloat(composerStatDialogMinWidth(screenWidth: screenWidth)) }
    private var statDialogMaxWidth: CGFloat { CGFloat(composerStatDialogMaxWidth(screenWidth: screenWidth)) }
    private var contextPanelWidth: CGFloat { CGFloat(composerContextPanelWidth(screenWidth: screenWidth)) }

    var body: some View {
        if activityText == nil && usageText == nil && context == nil {
            EmptyView()
        } else {
            HStack(alignment: .center, spacing: CGFloat(composerStatisticsRowGapPoints)) { pills }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(composerStatisticsRowIdentifier())
            .frame(maxWidth: .infinity, alignment: .center)
            .lineLimit(1)
            .padding(.horizontal, CGFloat(composerStatisticsRowPaddingHorizontalPoints))
            .padding(.top, CGFloat(composerStatisticsRowPaddingTopPoints))
            .padding(.bottom, CGFloat(composerStatisticsRowPaddingBottomPoints))
            .onChange(of: detailed) { _ in
                activityOpen = false
                usageOpen = false
            }
        }
    }

    @ViewBuilder
    private var pills: some View {
        if let activityText {
            ComposerStatPill(
                text: activityText,
                icon: OfficialGlyph(
                    kind: .gaugeOutline,
                    size: CGFloat(composerStatisticsIconSizePoints),
                    color: activityOpen ? T.text2 : T.text3
                ),
                clickable: detailed && activityHasDetails,
                open: activityOpen,
                restingInk: T.text3,
                activeInk: T.text2,
                activeBackground: T.hoverBg
            ) { toggle(.activity) }
            .accessibilityIdentifier("composerStats.activity")
            .popover(
                isPresented: $activityOpen,
                attachmentAnchor: .rect(.bounds),
                arrowEdge: composerActivityPopoverOpensAbove ? .bottom : .top
            ) {
                activityPopover
            }
        }
        if let usageText {
            ComposerStatPill(
                text: usageText,
                icon: OfficialGlyph(
                    kind: .databaseOutline,
                    size: CGFloat(composerStatisticsIconSizePoints),
                    color: usageOpen ? T.text2 : T.text3
                ),
                clickable: detailed,
                open: usageOpen,
                restingInk: T.text3,
                activeInk: T.text2,
                activeBackground: T.hoverBg
            ) { toggle(.usage) }
            .accessibilityIdentifier("composerStats.usage")
            .popover(
                isPresented: $usageOpen,
                attachmentAnchor: .rect(.bounds),
                arrowEdge: composerUsagePopoverOpensAbove ? .bottom : .top
            ) {
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

    @ViewBuilder
    private var activityPopover: some View {
        VStack(alignment: .leading, spacing: 0) {
            UsagePopoverHeader(
                icon: .gaugeOutline,
                title: composerActivityTitle(english: L.en),
                titleFont: Font.system(size: CGFloat(composerStatDialogFontSizePoints), weight: .medium),
                afterTitle: composerStatDialogTitleMarginBottomPoints,
                afterRule: composerStatDialogTitleRuleMarginBottomPoints,
                titleGap: composerStatDialogTitleGapPoints
            )
            VStack(alignment: .leading, spacing: CGFloat(composerStatDialogDetailsRowGapPoints)) {
                if let activity {
                    if activity.llmMs > 0 {
                        statDialogRow(composerActivityLlmTime(english: L.en), statisticsDuration(activity.llmMs, english: L.en))
                    }
                    if activity.toolMs > 0 {
                        statDialogRow(composerActivityToolTime(english: L.en), statisticsDuration(activity.toolMs, english: L.en))
                    }
                    if let ttft = activity.meanTtftMs {
                        statDialogRow(composerActivityTtft(english: L.en), statisticsDuration(ttft, english: L.en))
                    }
                    if let speed {
                        statDialogRow(composerActivitySpeed(english: L.en), speed)
                    }
                }
            }
        }
        .font(Font.system(size: CGFloat(composerStatDialogFontSizePoints)))
        .padding(CGFloat(composerStatDialogPaddingPoints))
        .frame(minWidth: statDialogMinWidth, maxWidth: statDialogMaxWidth)
        .modifier(PopoverCompactAdaptation())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("composerStats.activityDialog")
    }

    private func contextMeter(_ context: ComposerContext) -> some View {
        let reading = "\(context.percent)%"
        let ink = contextOpen ? T.text2 : T.text3
        return Button { toggle(.context) } label: {
            HStack(spacing: CGFloat(composerContextMeterIconGapPoints)) {
                ComposerContextRing(percent: context.percent, fill: ink)
                Text(reading)
                    .font(Font.system(size: CGFloat(composerContextMeterFontSizePoints)))
                    .monospacedDigit()
                    .foregroundStyle(ink)
                    .lineLimit(1)
            }
            .frame(minHeight: CGFloat(composerStatisticsPillLineHeightPoints))
            .padding(.vertical, CGFloat(composerStatisticsPillPaddingVerticalPoints))
            .padding(.horizontal, CGFloat(composerStatisticsPillPaddingHorizontalPoints))
            .background(
                contextOpen ? T.hoverBg : Color.clear,
                in: RoundedRectangle(cornerRadius: CGFloat(composerStatisticsPillRadiusPoints), style: .circular)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(composerContextAria(percent: reading, english: L.en))
        .accessibilityIdentifier("composerStats.context")
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
        let panelFont = Font.system(size: CGFloat(composerContextPanelFontSizePoints))
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: CGFloat(composerContextPanelHeaderGapPoints)) {
                if !headline.before.isEmpty {
                    Text(headline.before).font(panelFont).foregroundStyle(T.text3)
                }
                Text(reading).font(panelFont.weight(.medium)).monospacedDigit().foregroundStyle(T.ink)
                if !headline.after.isEmpty {
                    Text(headline.after).font(panelFont).foregroundStyle(T.text3)
                }
                Spacer(minLength: 0)
                Text("~\(statisticsTokens(context.usedTokens)) / \(statisticsTokens(context.contextWindow))")
                    .font(panelFont.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(T.ink)
            }
            .accessibilityLabel(composerContextUsed(english: L.en))
            contextBar(context.percent)
                .padding(.top, CGFloat(composerContextBarMarginTopPoints))
                .padding(.bottom, CGFloat(composerContextBarMarginBottomPoints))
            if let breakdown = metrics.contextBreakdown {
                VStack(spacing: 0) {
                    contextMeterRow(
                        composerContextBreakdownLabel(.system, english: L.en),
                        "~\(statisticsTokens(breakdown.systemTokens))",
                        statisticsContextColors[0]
                    )
                    contextMeterRow(
                        composerContextBreakdownLabel(.tools, english: L.en),
                        "~\(statisticsTokens(breakdown.toolsTokens))",
                        statisticsContextColors[1]
                    )
                    contextMeterRow(
                        composerContextBreakdownLabel(.messages, english: L.en),
                        "~\(statisticsTokens(breakdown.messageTokens))",
                        statisticsContextColors[2]
                    )
                }
                .padding(.top, CGFloat(composerContextRowsMarginTopPoints))
            }
        }
        .font(panelFont)
        .padding(CGFloat(composerContextPanelPaddingPoints))
        .frame(width: contextPanelWidth)
        .modifier(PopoverCompactAdaptation())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("composerStats.contextDialog")
    }

    /// Desktop session usage chip: anchored above, icon + title left, total right.
    private func sessionUsagePopover(_ usage: ComposerTokenUsage) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            UsagePopoverHeader(
                title: composerSessionUsageTitle(english: L.en),
                value: composerSessionUsageTitleValue(exactTotal: statisticsExact(usage.totalTokens)),
                titleFont: Font.system(size: CGFloat(composerStatDialogFontSizePoints), weight: .medium),
                afterTitle: composerStatDialogTitleMarginBottomPoints,
                afterRule: composerStatDialogTitleRuleMarginBottomPoints,
                titleGap: composerStatDialogTitleGapPoints
            )
            VStack(alignment: .leading, spacing: CGFloat(composerStatDialogDetailsRowGapPoints)) {
                if let hit = usage.cacheHitPercent {
                    statDialogRow(composerSessionUsageRowLabel(.cacheHit, english: L.en), "\(hit)%")
                }
                statDialogRow(
                    composerSessionUsageRowLabel(.uncachedInput, english: L.en),
                    composerSessionUsageTokenValue(exact: statisticsExact(usage.uncachedInputTokens))
                )
                statDialogRow(
                    composerSessionUsageRowLabel(.cacheRead, english: L.en),
                    composerSessionUsageTokenValue(exact: statisticsExact(usage.cacheReadTokens))
                )
                if usage.cacheWriteTokens != 0 {
                    statDialogRow(
                        composerSessionUsageRowLabel(.cacheWrite, english: L.en),
                        composerSessionUsageTokenValue(exact: statisticsExact(usage.cacheWriteTokens))
                    )
                }
                statDialogRow(
                    composerSessionUsageRowLabel(.output, english: L.en),
                    composerSessionUsageTokenValue(exact: statisticsExact(usage.outputTokens))
                )
            }
        }
        .font(Font.system(size: CGFloat(composerStatDialogFontSizePoints)))
        .padding(CGFloat(composerStatDialogPaddingPoints))
        .frame(minWidth: statDialogMinWidth, maxWidth: statDialogMaxWidth)
        .modifier(PopoverCompactAdaptation())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("composerStats.usageDialog")
    }

    /// Desktop `stat-dialog` `.details dt` tertiary / `dd` secondary, `gap: 6px 16px`.
    private func statDialogRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: CGFloat(composerStatDialogDetailsColumnGapPoints)) {
            Text(label).foregroundStyle(T.text3)
            Spacer(minLength: 0)
            Text(value).foregroundStyle(T.text2).monospacedDigit().multilineTextAlignment(.trailing)
        }
        .font(Font.system(size: CGFloat(composerStatDialogFontSizePoints)))
    }

    /// Desktop `ContextMeter` `.row dt` secondary / `dd` primary.
    private func contextMeterRow(_ label: String, _ value: String, _ swatch: Color) -> some View {
        HStack(alignment: .center, spacing: CGFloat(composerContextRowGapPoints)) {
            HStack(spacing: CGFloat(composerContextSwatchGapPoints)) {
                RoundedRectangle(cornerRadius: CGFloat(composerContextSwatchRadiusPoints), style: .circular)
                    .fill(swatch)
                    .frame(
                        width: CGFloat(composerContextSwatchSizePoints),
                        height: CGFloat(composerContextSwatchSizePoints)
                    )
                Text(label).foregroundStyle(T.text2)
            }
            Spacer(minLength: 0)
            Text(value).foregroundStyle(T.ink).monospacedDigit()
        }
        .font(Font.system(size: CGFloat(composerContextPanelFontSizePoints)))
        .padding(.vertical, CGFloat(composerContextRowPaddingVerticalPoints))
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
                            HStack(spacing: CGFloat(composerContextBarSegmentGapPoints)) {
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
        .frame(height: CGFloat(composerContextBarHeightPoints))
        .clipShape(Capsule())
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
                Text(label).font(Font.caption).foregroundStyle(T.text3).lineLimit(1)
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
                    value: composerSessionUsageTitleValue(exactTotal: statisticsExact(usage.totalTokens)),
                    titleFont: Font.subheadline.weight(.medium),
                    afterTitle: 8,
                    afterRule: 0,
                    titleGap: 16
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
            .font(Font.subheadline)
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
    let titleFont: Font
    let afterTitle: Double
    let afterRule: Double
    let titleGap: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 6) {
                OfficialGlyph(kind: icon, size: CGFloat(composerStatisticsIconSizePoints), color: T.ink)
                Text(title).font(titleFont).foregroundStyle(T.ink)
                Spacer(minLength: CGFloat(titleGap))
                if let value {
                    Text(value).font(titleFont).monospacedDigit().foregroundStyle(T.ink)
                }
            }
            .padding(.bottom, CGFloat(afterTitle))
            Divider()
                .padding(.bottom, CGFloat(afterRule))
        }
    }
}

/// Desktop `ContextMeter` 14px ring (`r=5.5`, 2px stroke, start at 12 o'clock).
/// Fill is `--dsw-alias-label-tertiary` (`ContextMeter.module.css` `.fill`).
private struct ComposerContextRing: View {
    let percent: Int
    var fill: Color = T.text3

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
                    fill,
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

func statisticsDuration(_ milliseconds: Double, english: Bool) -> String {
    let seconds = milliseconds / 1000
    if seconds < 60 {
        return "\(statisticsRounded(seconds, decimals: 1))\(english ? "s" : "秒")"
    }
    let whole = Int64(floor(seconds + 0.5))
    return english ? "\(whole / 60)m\(whole % 60)s" : "\(whole / 60)分\(whole % 60)秒"
}
