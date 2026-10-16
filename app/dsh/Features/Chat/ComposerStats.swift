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
    @State private var dialog: StatisticsDialog?

    private var detailed: Bool { AppModel.shared.performanceUsage == .detailed }
    private var activity: ComposerActivity? { metrics.activity }
    private var usage: ComposerTokenUsage? { metrics.tokens.flatMap { $0.totalTokens > 0 ? $0 : nil } }
    private var context: ComposerContext? { metrics.context }
    private var speed: String? { activity?.tokensPerSecond.map { "\(statisticsSpeed($0)) tok/s" } }
    private var cache: String? { usage?.cacheHitPercent.map { L.t("缓存命中 \($0)%", "Cache hit \($0)%") } }
    private var activityText: String? {
        if detailed {
            return activity.flatMap { $0.steps > 0 ? [L.t("\($0.turns) 轮 \($0.steps) 步", "\($0.turns) turns \($0.steps) steps"), speed].compactMap { $0 }.joined(separator: " · ") : nil }
        }
        return speed
    }
    private var usageText: String? {
        if detailed { return usage.map { [ "\(statisticsTokens(Double($0.totalTokens))) tokens", cache].compactMap { $0 }.joined(separator: " · ") } }
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
            .sheet(item: Binding(
                get: { dialog.map { DialogBox($0) } },
                set: { dialog = $0?.kind }
            )) { box in
                dialogView(box.kind)
            }
        }
    }

    @ViewBuilder
    private var pills: some View {
        if let activityText {
            pill(activityText, clickable: detailed && activityHasDetails) { dialog = .activity }
        }
        if let usageText {
            pill(usageText, clickable: detailed) { dialog = .usage }
        }
        if let context {
            pill("\(context.percent)%", clickable: true) { dialog = .context }
        }
    }

    private func pill(_ text: String, clickable: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "gauge.with.dots.needle.67percent").font(.system(size: 12)).foregroundStyle(T.text3)
                Text(text).font(.caption).foregroundStyle(T.text3).lineLimit(1)
            }
            .padding(.vertical, 5)
        }
        .buttonStyle(.plain)
        .disabled(!clickable)
    }

    private func dialogView(_ kind: StatisticsDialog) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    switch kind {
                    case .activity:
                        if let activity {
                            if activity.llmMs > 0 { detail(L.t("模型用时", "LLM time"), statisticsDuration(activity.llmMs)) }
                            if activity.toolMs > 0 { detail(L.t("工具调用用时", "Tool time"), statisticsDuration(activity.toolMs)) }
                            if let ttft = activity.meanTtftMs { detail(L.t("首 token 平均（TTFT）", "Avg time to first token (TTFT)"), statisticsDuration(ttft)) }
                            if let speed { detail(L.t("输出速度（TPS）", "Tokens per second (TPS)"), speed) }
                        }
                    case .usage:
                        if let usage {
                            detail(L.t("合计", "Total"), statisticsExact(usage.totalTokens))
                            if let hit = usage.cacheHitPercent { detail(L.t("缓存命中率", "Cache hit"), "\(hit)%") }
                            detail(L.t("未缓存输入", "Uncached input"), statisticsExact(usage.uncachedInputTokens))
                            detail(L.t("缓存读取", "Cache read"), statisticsExact(usage.cacheReadTokens))
                            if usage.cacheWriteTokens != 0 { detail(L.t("缓存写入", "Cache write"), statisticsExact(usage.cacheWriteTokens)) }
                            detail(L.t("输出", "Output"), statisticsExact(usage.outputTokens))
                        }
                    case .context:
                        if let context {
                            detail(L.t("上下文已用 \(context.percent)%", "\(context.percent)% of context used"), "~\(statisticsTokens(context.usedTokens)) / \(statisticsTokens(context.contextWindow))")
                            contextBar(context.percent)
                            if let breakdown = metrics.contextBreakdown {
                                detail(L.t("系统提示词", "System prompt"), "~\(statisticsTokens(breakdown.systemTokens))", statisticsContextColors[0])
                                detail(L.t("工具", "Tools"), "~\(statisticsTokens(breakdown.toolsTokens))", statisticsContextColors[1])
                                detail(L.t("对话", "Conversation"), "~\(statisticsTokens(breakdown.messageTokens))", statisticsContextColors[2])
                            }
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle(dialogTitle(kind))
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L.close()) { dialog = nil } } }
        }
    }

    private func dialogTitle(_ kind: StatisticsDialog) -> String {
        switch kind {
        case .activity: return metrics.activityIsWholeSession ? L.t("会话统计", "Session statistics") : L.t("已加载历史统计", "Loaded history statistics")
        case .usage: return L.t("Token 用量", "Token usage")
        case .context: return L.t("上下文用量", "Context usage")
        }
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
        let count = "\(statisticsTokens(Double(usage.totalTokens))) tok"
        let label = L.t("用量 \(count)", "Usage \(count)")
        Button { expanded.toggle() } label: {
            HStack(spacing: 4) {
                Image(systemName: "cylinder").font(.system(size: 12)).foregroundStyle(T.text3)
                Text(label).font(.caption).foregroundStyle(T.text3).lineLimit(1)
            }
            .padding(.leading, 11)
            .padding(.trailing, 2)
            .padding(.vertical, 5)
            .background(expanded ? T.hoverBg : Color.clear, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: 180, minHeight: 48)
        .popover(isPresented: $expanded, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 10) {
                Text(L.t("本轮用量", "Turn usage")).font(.subheadline.weight(.medium)).foregroundStyle(T.ink)
                row(L.t("合计", "Total"), "\(statisticsExact(usage.totalTokens)) tok")
                if let routes = usage.routes, !routes.isEmpty {
                    Text(L.t("模型", "Model")).foregroundStyle(T.text2)
                    ForEach(routes, id: \.self) { route in
                        Text("\(route.provider)/\(route.model)").foregroundStyle(T.ink)
                    }
                }
                let promptTokens = usage.totalTokens - usage.outputTokens
                if let cached = usage.cacheReadTokens, promptTokens > 0 {
                    row(L.t("缓存命中率", "Cache hit"), String(format: "%.1f%%", Double(cached) / Double(promptTokens) * 100))
                }
                row(L.t("未缓存输入", "Uncached input"), "\(statisticsExact(usage.uncachedInputTokens)) tok")
                if let read = usage.cacheReadTokens { row(L.t("缓存读取", "Cache read"), "\(statisticsExact(read)) tok") }
                if let write = usage.cacheWriteTokens { row(L.t("缓存写入", "Cache write"), "\(statisticsExact(write)) tok") }
                row(L.t("输出", "Output"), "\(statisticsExact(usage.outputTokens)) tok")
                if let reasoning = usage.reasoningTokens {
                    row(L.t("其中推理输出", "Of which reasoning"), "\(statisticsExact(reasoning)) tok")
                        .padding(.leading, 12)
                }
            }
            .font(.subheadline)
            .padding(16)
            .frame(minWidth: 240, maxWidth: 320)
            .modifier(PopoverCompactAdaptation())
        }
        .onChange(of: turn) { _ in expanded = false }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(T.text2)
            Spacer()
            Text(value).foregroundStyle(T.ink)
        }
    }
}

private struct DialogBox: Identifiable {
    let kind: StatisticsDialog
    var id: String { String(describing: kind) }
    init(_ kind: StatisticsDialog) { self.kind = kind }
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
