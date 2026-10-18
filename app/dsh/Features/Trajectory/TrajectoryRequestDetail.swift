import SwiftUI
import DSHProtocol

struct TrajectoryRequestSheet: View {
    let request: TrajectoryRequest
    var onOpenResult: (String) -> Void = { _ in }
    var initialTab: TrajRequestTab = .overview
    var assistantRow: TrajRow? = nil
    var onDismiss: () -> Void

    @State private var tab: TrajRequestTab?

    private var tabs: [TrajRequestTab] { trajRequestTabs(request) }

    private var activeTab: TrajRequestTab {
        let candidate = tab ?? initialTab
        return tabs.contains(candidate) ? candidate : .overview
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                Text(location)
                    .font(.caption)
                    .foregroundStyle(T.text3)
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(tabs, id: \.self) { candidate in
                            Button {
                                tab = candidate
                            } label: {
                                Text(candidate.label)
                                    .font(.subheadline.weight(activeTab == candidate ? .semibold : .regular))
                                    .foregroundStyle(activeTab == candidate ? T.ink : T.text3)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .overlay(alignment: .bottom) {
                                        if activeTab == candidate { T.accent.frame(height: 2) }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 8)
                }
                .padding(.top, 8)
                Divider()
                ScrollView {
                    tabBody
                        .padding(14)
                        .padding(.bottom, 24)
                }
            }
            .background(T.bg)
            .navigationTitle(requestLabel(request))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(TrajL.detailsClose, action: onDismiss)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear { tab = initialTab }
        .onChange(of: request.identity) { _ in tab = initialTab }
    }

    private var location: String {
        switch request.purpose {
        case .compaction:
            let section = request.turn.map(TrajL.turnLabel) ?? TrajL.sectionBetweenTurns
            return TrajL.requestCompactionSection(section)
        case .assistant:
            let turn = request.turn.map(TrajL.turnLabel) ?? TrajL.sectionBetweenTurns
            return "\(turn) · \(request.group)"
        }
    }

    @ViewBuilder
    private var tabBody: some View {
        switch activeTab {
        case .overview:
            RequestOverview(request: request, tabs: tabs, assistantRow: assistantRow, onOpenResult: onOpenResult) { tab = $0 }
        case .options:
            RequestOptions(configJson: request.requestConfigJson)
        case .usage:
            RequestUsage(usage: request.usage, cumulative: request.cumulativeUsage)
        case .timing:
            RequestTiming(request: request, assistantRow: assistantRow)
        }
    }
}

private struct RequestOverview: View {
    let request: TrajectoryRequest
    let tabs: [TrajRequestTab]
    let assistantRow: TrajRow?
    var onOpenResult: (String) -> Void
    var onOpen: (TrajRequestTab) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            line(TrajL.detailsStatus, trajectoryStatusLabel(request.status), valueColor: request.status == .error ? T.err : T.ink)
            if request.purpose == .compaction {
                line(TrajL.detailsPurpose, TrajL.requestCompactionPurpose)
            }
            if let provider = request.provider { line(TrajL.detailsProvider, provider) }
            if let model = request.model { line(TrajL.detailsModel, model) }
            line(TrajL.detailsToolCalls, "\(request.toolCallCount)")
            if request.subtoolCallCount > 0 {
                line(TrajL.detailsSubtoolCalls, "\(request.subtoolCallCount)")
            }
            if let err = request.error {
                let label = request.status != .error && request.retry != nil ? TrajL.detailsLastAttemptError : TrajL.detailsError
                let shown: String = {
                    switch request.errorCode {
                    case "AUTH": return TrajL.detailsFailureAuth
                    case "interrupted": return TrajL.layoutCompactionInterrupted
                    default: return err
                    }
                }()
                line(label, shown, valueColor: request.status == .error ? T.err : T.ink)
            }
            if let retry = request.retry {
                let value = request.maxRetries.map { TrajL.requestRetryProgress(retry: retry, maximum: $0) } ?? "\(retry)"
                line(TrajL.detailsRetry, value)
            }
            if let delay = request.retryDelayMs {
                line(TrajL.detailsRetryDelay, formatDurationMillis(Double(delay)))
            }
            if let key = request.resultKey {
                line(
                    TrajL.detailsResult,
                    request.purpose == .compaction ? TrajL.detailsCompacted : TrajL.detailsAssistantMessage,
                    valueColor: T.accent,
                    onClick: { onOpenResult(key) }
                )
            }
            Spacer().frame(height: 8)
            if tabs.contains(.options), let json = request.requestConfigJson {
                section(TrajL.tabOptions, onOpen: { onOpen(.options) }) {
                    Text(prettyRequestJson(json).split(separator: "\n").prefix(4).joined(separator: "\n"))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(T.text2)
                        .lineLimit(4)
                }
            }
            section(TrajL.tabUsage, onOpen: { onOpen(.usage) }) {
                UsageBlock(usage: request.usage)
            }
            section(TrajL.tabTiming, onOpen: { onOpen(.timing) }) {
                RequestTiming(request: request, assistantRow: assistantRow, preview: true)
            }
        }
    }

    private func line(_ label: String, _ value: String, valueColor: Color = T.text2, onClick: (() -> Void)? = nil) -> some View {
        Button {
            onClick?()
        } label: {
            HStack(alignment: .top) {
                Text(label).font(.caption).foregroundStyle(T.text3).frame(width: 88, alignment: .leading)
                Text(value).font(.caption).foregroundStyle(valueColor)
                Spacer()
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .disabled(onClick == nil)
    }

    private func section<Content: View>(_ title: String, onOpen: @escaping () -> Void, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: onOpen) {
                HStack {
                    Text(title).font(.caption.weight(.semibold)).foregroundStyle(T.ink)
                    Spacer()
                    OfficialGlyph(
                        kind: .chevronRight,
                        size: CGFloat(trajectoryDetailChevronIconSizePoints),
                        color: T.caption
                    )
                }
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isButton)
            content()
        }
        .padding(.vertical, 8)
    }
}

private struct RequestOptions: View {
    let configJson: String?

    var body: some View {
        if let configJson, !configJson.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(TrajL.optionsJson).font(.system(size: 12)).foregroundStyle(T.text3)
                TrajectoryJsonValue(source: configJson)
            }
        } else {
            Text(TrajL.optionsNotRecorded).font(.subheadline).foregroundStyle(T.text3)
        }
    }
}

private struct RequestUsage: View {
    let usage: StepUsage?
    let cumulative: StepUsage?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(TrajL.usageThisRequest).font(.system(size: 12, weight: .medium)).foregroundStyle(T.text2)
            UsageBlock(usage: usage)
            Spacer().frame(height: 12)
            Text(TrajL.usageSessionCumulative).font(.system(size: 12, weight: .medium)).foregroundStyle(T.text2)
            UsageBlock(usage: cumulative)
        }
    }
}

private struct UsageBlock: View {
    let usage: StepUsage?

    var body: some View {
        let values = [usage?.inputTokens, usage?.cacheReadTokens, usage?.cacheWriteTokens, usage?.outputTokens, usage?.reasoningTokens].compactMap { $0 }
        if usage == nil || values.isEmpty {
            Text(TrajL.usageNotReported).font(.system(size: 13)).foregroundStyle(T.text3).padding(.top, 4)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                if let n = usage?.inputTokens { line(TrajL.usageInput, TrajL.unitTokens(n)) }
                if let n = usage?.cacheReadTokens { line(TrajL.usageCached, TrajL.unitTokens(n)) }
                if let n = usage?.cacheWriteTokens { line(TrajL.usageCacheCreated, TrajL.unitTokens(n)) }
                if let n = usage?.outputTokens { line(TrajL.usageOutput, TrajL.unitTokens(n)) }
                if let n = usage?.reasoningTokens { line(TrajL.usageReasoning, TrajL.unitTokens(n)) }
            }
        }
    }

    private func line(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.caption).foregroundStyle(T.text3).frame(width: 88, alignment: .leading)
            Text(value).font(.caption).foregroundStyle(T.ink)
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

private struct RequestTiming: View {
    let request: TrajectoryRequest
    let assistantRow: TrajRow?
    var preview = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if request.purpose == .assistant, let assistantRow {
                AssistantTimingRows(row: assistantRow)
            } else {
                line(TrajL.timingStarted, formatStartedAt(request.startedAt))
                let durationSec: Double? = {
                    if let start = request.startedAt, let end = request.completedAt {
                        return Double(max(0, end - start)) / 1000.0
                    }
                    return nil
                }()
                line(TrajL.timingDuration, {
                    if request.status == .running { return TrajL.statusPending }
                    if let durationSec { return formatElapsedSeconds(durationSec) }
                    return TrajL.timingNotAvailable
                }())
                if !preview {
                    line(TrajL.timingSource, {
                        if durationSec == nil && request.status != .running { return TrajL.timingNotAvailable }
                        if request.status == .running { return TrajL.timingSessionTimestampsRunning }
                        return TrajL.timingSessionTimestamps
                    }())
                }
            }
        }
    }

    private func line(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.caption).foregroundStyle(T.text3).frame(width: 88, alignment: .leading)
            Text(value).font(.caption).foregroundStyle(T.ink)
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

private func prettyRequestJson(_ text: String) -> String {
    (try? JSONValue.parse(text).prettyString()) ?? text
}
