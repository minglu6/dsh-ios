import SwiftUI
import DSHProtocol

struct TrajectoryRecordInspector: View {
    let row: TrajRow
    let turnIndex: Int
    var parentRequest: TrajectoryRequest? = nil
    var onOpenRequest: (TrajectoryRequest) -> Void = { _ in }
    var onOpenRequestTiming: (TrajectoryRequest) -> Void = { _ in }
    var toolCalls: [TrajRow] = []
    @Binding var tabHistory: [TrajDetailTab]
    let onDismiss: () -> Void
    var onOpenTool: (TrajRow) -> Void = { _ in }
    @State private var tab: TrajDetailTab?

    private var tabs: [TrajDetailTab] { trajDetailTabs(row) }

    private var activeTab: TrajDetailTab {
        tab.flatMap { tabs.contains($0) ? $0 : nil }
            ?? tabHistory.reversed().first(where: tabs.contains)
            ?? tabs.first ?? .overview
    }

    var body: some View {
        TrajectoryInspectorFrame(
            title: trajDetailKindLabel(row.kind),
            location: trajDetailLocation(row, turnIndex: turnIndex),
            kind: row.kind,
            tabs: tabs,
            selection: activeTab,
            label: { $0.label },
            onSelect: selectTab,
            onDismiss: onDismiss
        ) {
            tabBody
        }
    }

    private func selectTab(_ value: TrajDetailTab) {
        tabHistory.removeAll { $0 == value }
        tabHistory.append(value)
        tab = value
    }

    @ViewBuilder
    private var tabBody: some View {
        switch activeTab {
        case .overview:
            TrajOverview(
                row: row,
                tabs: tabs,
                parentRequest: parentRequest,
                onOpenRequest: onOpenRequest,
                onOpenRequestTiming: onOpenRequestTiming,
                toolCalls: toolCalls,
                onOpenTool: onOpenTool
            ) { selectTab($0) }
        case .input, .code:
            Group {
                let program = codeProgram(toolName: row.toolName, inputDetail: row.inputDetail, schemaDetail: row.schemaDetail)
                if let program, activeTab == .code {
                    TrajCodeBlock(program.source, language: program.language)
                        .padding(.horizontal, 14)
                } else {
                    TrajPayload(row.inputDetail, missing: TrajL.recordNoPayload)
                }
            }
        case .output:
            Group {
                let program = codeProgram(toolName: row.toolName, inputDetail: row.inputDetail, schemaDetail: row.schemaDetail)
                if program != nil && row.outputDetail == nil && row.running {
                    Text(TrajL.codeRunning)
                        .font(Font.subheadline)
                        .foregroundStyle(T.text3)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                } else {
                    TrajPayload(row.outputDetail, missing: TrajL.recordNoResult, error: row.isError)
                }
            }
        case .rawOutput:
            TrajPayload(row.rawDetail ?? row.outputDetail, missing: TrajL.recordNoOutput)
        case .schema:
            TrajSchema(row.schemaDetail)
        case .timing:
            TrajTiming(row: row)
        case .preview:
            TrajPreview(row: row, toolCalls: toolCalls, onOpenTool: onOpenTool, rendered: true)
        case .raw:
            TrajPreview(row: row, toolCalls: toolCalls, onOpenTool: onOpenTool, rendered: false)
        case .thinking:
            TrajPayload(row.thinkingDetail, missing: TrajL.recordNoContent)
        case .source:
            TrajPayload(row.messageSourceJson, missing: TrajL.sourceNotRecorded)
        case .diff:
            TrajSystemDiff(row: row)
        case .systemPrompt:
            TrajPayload(row.rawDetail, missing: TrajL.recordSystemPromptMissing)
        case .tools:
            TrajPayload(row.toolsJson, missing: TrajL.recordToolsMissing)
        }
    }
}

private struct TrajOverview: View {
    let row: TrajRow
    let tabs: [TrajDetailTab]
    var parentRequest: TrajectoryRequest? = nil
    var onOpenRequest: (TrajectoryRequest) -> Void = { _ in }
    var onOpenRequestTiming: (TrajectoryRequest) -> Void = { _ in }
    let toolCalls: [TrajRow]
    var onOpenTool: (TrajRow) -> Void = { _ in }
    var onOpen: (TrajDetailTab) -> Void

    var body: some View {
        let state = trajRowState(row)
        VStack(alignment: .leading, spacing: 0) {
            if let parentRequest {
                overviewLine(
                    row.kind == TrajL.kindAssistant ? TrajL.detailsSource : TrajL.detailsHierarchy,
                    requestLabel(parentRequest),
                    valueColor: T.text2,
                    onClick: { onOpenRequest(parentRequest) }
                )
            } else if row.kind == TrajL.kindTool || row.kind == TrajL.kindSubtool {
                overviewLine(TrajL.detailsHierarchy, TrajL.detailsAssistantMessage)
            }
            overviewLine(TrajL.detailsStatus, trajectoryStatusLabel(state), valueColor: state == .error ? T.err : T.ink)
            if row.kind == TrajL.kindAssistant {
                overviewLine(TrajL.usageTokens, row.outputTokens.map(TrajL.unitTokens) ?? "—")
                if let reasoning = row.reasoningTokens {
                    overviewLine(TrajL.usageReasoning, TrajL.unitTokens(reasoning))
                    if let output = row.outputTokens {
                        overviewLine(TrajL.usageContent, TrajL.unitTokens(max(0, output - reasoning)))
                    }
                }
            }
            Spacer().frame(height: 8)
            if tabs.contains(.preview) {
                overviewSection(TrajL.tabPreview, onOpen: { onOpen(.preview) }) {
                    TrajPreview(row: row, toolCalls: toolCalls, onOpenTool: onOpenTool, rendered: true, compact: true)
                }
            }
            if tabs.contains(.input) || tabs.contains(.code) {
                let inputTab: TrajDetailTab = tabs.contains(.code) ? .code : .input
                overviewSection(inputTab.label, onOpen: { onOpen(inputTab) }) {
                    if inputTab == .code,
                       let program = codeProgram(toolName: row.toolName, inputDetail: row.inputDetail, schemaDetail: row.schemaDetail) {
                        TrajCodeBlock(program.source, language: program.language)
                    } else {
                        TrajectoryJsonValue(source: pretty(row.inputDetail) ?? TrajL.recordNoPayload)
                    }
                }
            }
            if tabs.contains(.output) {
                overviewSection(TrajL.tabResult, onOpen: { onOpen(.output) }) {
                    TrajectoryJsonValue(source: row.outputDetail ?? TrajL.recordNoResult)
                }
            }
            if tabs.contains(.schema) {
                overviewSection(TrajL.tabSchema, onOpen: { onOpen(.schema) }) {
                    TrajSchema(row.schemaDetail, inset: false)
                }
            }
            if row.kind == TrajL.kindAssistant {
                Spacer().frame(height: 12)
                overviewSection(TrajL.timingRequest, onOpen: parentRequest.map { req in { onOpenRequestTiming(req) } }) {
                    AssistantTimingRows(row: row)
                }
            } else if tabs.contains(.timing) {
                overviewSection(TrajL.tabTiming, onOpen: { onOpen(.timing) }) {
                    overviewLine(TrajL.timingStarted, formatStartedAt(row.startedAt))
                    overviewLine(TrajL.timingDuration, formatElapsedSeconds(row.timeSeconds))
                }
            }
            if tabs.contains(.rawOutput) {
                overviewSection(TrajL.tabRawOutput, onOpen: { onOpen(.rawOutput) }) {
                    TrajCodeBlock(row.rawDetail ?? row.outputDetail ?? TrajL.recordNoOutput)
                }
            }
        }
        .padding(.horizontal, 14)
    }

    private func overviewLine(_ label: String, _ value: String, valueColor: Color = T.ink, onClick: (() -> Void)? = nil) -> some View {
        TrajectoryOverviewLine(label: label, value: value, valueColor: valueColor, onOpen: onClick)
    }

    private func overviewSection<Content: View>(
        _ title: String,
        onOpen: (() -> Void)?,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        TrajectoryOverviewSection(title: title, onOpen: onOpen, content: content)
            .padding(.vertical, 4)
    }
}

struct AssistantTimingRows: View {
    let row: TrajRow
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            line(TrajL.timingStarted, formatStartedAt(row.startedAt))
            line(TrajL.timingTotalDuration, row.running ? TrajL.statusPending : formatAssistantDuration(row.timeSeconds))
            line(TrajL.timingTtft, formatTtft(row))
            line(TrajL.timingGeneration, formatGeneration(row))
            line(TrajL.timingThroughput, formatThroughput(row))
        }
    }

    private func line(_ label: String, _ value: String) -> some View {
        TrajectoryOverviewLine(label: label, value: value)
    }
}

private struct TrajTiming: View {
    let row: TrajRow
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if row.kind == TrajL.kindAssistant {
                AssistantTimingRows(row: row)
            } else {
                line(TrajL.timingStarted, formatStartedAt(row.startedAt))
                line(TrajL.timingDuration, formatElapsedSeconds(row.timeSeconds))
            }
            line(TrajL.timingSource, row.running ? TrajL.timingSessionTimestampsRunning : TrajL.timingSessionTimestamps)
        }
        .padding(.horizontal, 14)
    }

    private func line(_ label: String, _ value: String) -> some View {
        TrajectoryOverviewLine(label: label, value: value)
    }
}

private struct TrajPreview: View {
    let row: TrajRow
    var toolCalls: [TrajRow] = []
    var onOpenTool: (TrajRow) -> Void = { _ in }
    var rendered: Bool
    var compact: Bool = false
    @State private var thinkingExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let thinking = row.thinkingDetail, !thinking.isEmpty {
                Button { thinkingExpanded.toggle() } label: {
                    HStack(spacing: 4) {
                        OfficialGlyph(
                            kind: .chevronRight,
                            size: CGFloat(trajectoryDetailChevronIconSizePoints),
                            color: T.text3
                        )
                        .rotationEffect(.degrees(
                            thinkingExpanded ? trajectoryThinkingChevronExpandedRotationDegrees : 0
                        ))
                        Text(TrajL.recordThinking).font(Font.caption).foregroundStyle(T.text3)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .contain)
                .accessibilityAddTraits(.isButton)
                if thinkingExpanded {
                    if rendered {
                        MarkdownView(source: thinking, wrapCode: true, bodyColor: T.text2, variant: .compact,
                                     onFile: { AppModel.shared.openFilePreview(path: $0) },
                                     onLink: { AppModel.shared.openChatLink($0) })
                    } else {
                        TrajCodeBlock(thinking)
                    }
                }
            }
            let body = row.kind == TrajL.kindAssistant ? row.outputDetail : row.rawDetail
            if let body, !body.isEmpty {
                if rendered {
                    MarkdownView(source: body, wrapCode: true, variant: .trajectory,
                                 onFile: { AppModel.shared.openFilePreview(path: $0) },
                                 onLink: { AppModel.shared.openChatLink($0) })
                } else {
                    TrajCodeBlock(body)
                }
            }
            ForEach(toolCalls) { call in
                Button { onOpenTool(call) } label: {
                    HStack(spacing: 4) {
                        OfficialGlyph(kind: .toolWrench, size: 12, color: T.caption)
                        Text(call.title)
                            .font(Font.system(size: 12, design: .monospaced))
                            .foregroundStyle(T.text3)
                            .lineLimit(compact ? 1 : nil)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .contain)
                .accessibilityAddTraits(.isButton)
            }
            if (body ?? "").isEmpty && (row.thinkingDetail ?? "").isEmpty && toolCalls.isEmpty {
                Text(TrajL.recordNoContent).font(Font.subheadline).foregroundStyle(T.text3)
            }
        }
        .padding(.horizontal, compact ? 0 : 14)
    }
}

private struct TrajPayload: View {
    let text: String?
    let missing: String
    var error: Bool = false

    init(_ text: String?, missing: String, error: Bool = false) {
        self.text = text
        self.missing = missing
        self.error = error
    }

    var body: some View {
        TrajectoryJsonValue(source: pretty(text) ?? text ?? missing, error: error || text == nil)
            .padding(.horizontal, 14)
    }
}

private struct TrajSchema: View {
    let json: String?
    let inset: Bool

    init(_ json: String?, inset: Bool = true) {
        self.json = json
        self.inset = inset
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let parsed = json.flatMap({ try? JSONValue.parse($0) }),
               let name = parsed["name"].str() {
                Text(name).font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundStyle(T.ink)
                if let description = parsed["description"].str() {
                    Text(description).font(.system(size: 13)).foregroundStyle(T.text2)
                }
                if let parameters = parsed.obj()?["parameters"], let json = parameters.prettyString() {
                    Text(TrajL.tabPayload).font(.system(size: 12)).foregroundStyle(T.text3)
                    TrajectoryJsonValue(source: json)
                }
            } else {
                Text(json ?? TrajL.recordSchemaUnavailable)
                    .font(Font.system(size: 12, design: .monospaced))
                    .foregroundStyle(T.text3)
            }
        }
        .padding(.horizontal, inset ? 14 : 0)
    }
}

private struct TrajSystemDiff: View {
    let row: TrajRow
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(TrajL.recordSystemPrompt).font(Font.caption).foregroundStyle(T.text3)
            let prev = row.previousText ?? ""
            let curr = row.rawDetail ?? ""
            if prev.isEmpty && curr.isEmpty {
                Text(TrajL.recordSystemPromptMissing).font(Font.subheadline).foregroundStyle(T.text3)
            } else {
                TrajCodeBlock("— previous —\n\(prev)\n\n— current —\n\(curr)")
            }
            if let diff = toolCatalogDiff(previousJson: row.previousToolsJson, currentJson: row.toolsJson) {
                Text(TrajL.recordTools).font(Font.caption).foregroundStyle(T.text3).padding(.top, 8)
                TrajCodeBlock(diff)
            }
        }
        .padding(.horizontal, 14)
    }
}

private struct TrajCodeBlock: View {
    let text: String
    var language: String?
    var error: Bool = false

    init(_ text: String, language: String? = nil, error: Bool = false) {
        self.text = text
        self.language = language
        self.error = error
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let language {
                Text(language).font(Font.caption).foregroundStyle(T.text3)
            }
            Text(text)
                .font(Font.system(size: 12, design: .monospaced))
                .foregroundStyle(error ? T.err : T.ink)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private func pretty(_ text: String?) -> String? {
    guard let text, !text.isEmpty, let parsed = try? JSONValue.parse(text) else { return text }
    return parsed.prettyString() ?? text
}
