import SwiftUI
import DSHProtocol

struct TrajectoryView: View {
    @ObservedObject var model: AppModel
    @StateObject private var ledgerCache = TrajectoryLedgerCache()
    @State private var selection: TrajectorySelection?
    @State private var actualDuration = false
    @State private var turnsCollapsed = false
    @State private var callsCollapsed = false
    @State private var searchQuery = ""

    var body: some View {
        let loaded = model.chat?.loaded == true
        if !loaded {
            VStack(spacing: 8) {
                ProgressView()
                Text(TrajL.historyLoadingTrajectory)
                    .font(Font.subheadline)
                    .foregroundStyle(T.caption)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ledger(ledgerCache.snapshot(for: model))
        }
    }

    private func ledger(_ snapshot: TrajectoryLedgerSnapshot) -> some View {
        let timeline = actualDuration ? snapshot.durationTimeline : snapshot.sequenceTimeline
        let projection = snapshot.project(query: searchQuery, callsCollapsed: callsCollapsed)
        let selectedKey = selection?.rowKey
        let selectedRequestId = selection?.requestId
        return VStack(spacing: 0) {
            toolbar
            if let timeline {
                SwimlaneChart(model: timeline, selectedKey: selectedKey) { key in
                    openRow(key, in: snapshot)
                }
            }
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if model.chat?.hasMore == true || model.chat?.loadingOlder == true {
                        Button {
                            model.loadOlderHistory()
                        } label: {
                            Text(model.chat?.loadingOlder == true ? TrajL.historyLoadingEarlier : TrajL.historyLoadEarlier)
                                .font(Font.caption)
                                .foregroundStyle(model.chat?.loadingOlder == true ? T.text2 : T.accent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .disabled(model.chat?.loadingOlder == true || model.chat?.hasMore != true)
                    }
                    if turnsCollapsed {
                        ForEach(projection.turns, id: \.self) { turn in
                            Button { turnsCollapsed = false } label: {
                                Text(TrajL.turnLabel(turn))
                                    .font(Font.caption)
                                    .foregroundStyle(T.text3)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                            }
                        }
                    } else {
                        // A single ForEach keeps even a many-thousand-row turn lazy.
                        ForEach(projection.rows) { entry in
                            let row = entry.row
                            let boundary = snapshot.boundaryByRow[row.key]
                            TrajRowView(
                                row: row,
                                highlighted: selectedKey == row.key,
                                turnStart: entry.turnStart ? entry.turn : nil,
                                requestBoundary: boundary,
                                requestSelected: selectedRequestId != nil && selectedRequestId == boundary?.identity
                            ) {
                                selection = .row(row, turn: entry.turn)
                            } onRequestClick: { req in
                                selection = .request(req, tab: .overview)
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { selection != nil },
            set: { if !$0 { selection = nil } }
        )) {
            if let detail = selection {
                Group {
                    switch detail {
                    case .row(let row, let turn):
                        TrajectoryDetailSheet(
                            row: row,
                            turnIndex: turn,
                            parentRequest: requestForRow(row, requests: snapshot.requests),
                            onOpenRequest: { selection = .request($0, tab: .overview) },
                            onOpenRequestTiming: { selection = .request($0, tab: .timing) },
                            toolCalls: snapshot.toolCalls(for: row),
                            onDismiss: { selection = nil }
                        ) { call in
                            openRow(call.key, in: snapshot)
                        }
                    case .request(let request, let tab):
                        TrajectoryRequestSheet(
                            request: request,
                            onOpenResult: { openRow($0, in: snapshot) },
                            initialTab: tab,
                            assistantRow: request.resultKey.flatMap { snapshot.assistantByKey[$0] },
                            onDismiss: { selection = nil }
                        )
                    }
                }
                .id(detail.id)
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 4) {
            toolbarChip(pressed: actualDuration, label: TrajL.toolbarDuration) {
                actualDuration.toggle()
            } icon: {
                OfficialGlyph(
                    kind: .trajectoryClock,
                    size: CGFloat(trajectoryToolbarClockIconSizePoints),
                    color: actualDuration ? T.ink : T.text3
                )
            }
            toolbarChip(pressed: turnsCollapsed, label: TrajL.toolbarTurns) {
                turnsCollapsed.toggle()
            } icon: {
                Text(turnsCollapsed ? "⊞" : "⊟").font(.caption)
            }
            toolbarChip(pressed: callsCollapsed, label: TrajL.toolbarCalls) {
                callsCollapsed.toggle()
            } icon: {
                Text(callsCollapsed ? "⊞" : "⊟").font(.caption)
            }
            Spacer()
            HStack(spacing: 4) {
                OfficialGlyph(
                    kind: .searchOutline,
                    size: CGFloat(trajectoryToolbarSearchIconSizePoints),
                    color: T.caption
                )
                TextField(TrajL.toolbarSearchPlaceholder, text: $searchQuery)
                    .font(Font.caption)
                    .textInputAutocapitalization(.never)
                    .accessibilityLabel(TrajL.toolbarSearch)
            }
            .padding(.horizontal, 6)
            .frame(maxWidth: 176)
            .frame(height: 24)
            .background(T.surface, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(T.border, lineWidth: 0.5))
        }
        .padding(.horizontal, 6)
        .frame(height: 32)
        .overlay(alignment: .bottom) { Divider() }
    }

    private func toolbarChip<Icon: View>(
        pressed: Bool,
        label: String,
        action: @escaping () -> Void,
        @ViewBuilder icon: () -> Icon
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                icon()
                Text(label).font(Font.caption).foregroundStyle(pressed ? T.ink : T.text3)
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(pressed ? T.fill : Color.clear, in: RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(pressed ? .isSelected : [])
    }

    private func openRow(_ key: String, in snapshot: TrajectoryLedgerSnapshot) {
        guard let entry = snapshot.rowByKey[key] else { return }
        selection = .row(entry.row, turn: entry.turn)
    }
}

/// A single presentation owner prevents competing row/request sheets during navigation.
private enum TrajectorySelection: Identifiable {
    case row(TrajRow, turn: Int)
    case request(TrajectoryRequest, tab: TrajRequestTab)

    enum ID: Hashable {
        case row(Int, String)
        case request(String)
    }

    var id: ID {
        switch self {
        case .row(let row, let turn): return .row(turn, row.key)
        case .request(let request, _): return .request(request.identity)
        }
    }

    var rowKey: String? {
        if case .row(let row, _) = self { return row.key }
        return nil
    }

    var requestId: String? {
        if case .request(let request, _) = self { return request.identity }
        return nil
    }
}

/// View-lifetime memoization only: no publication from body evaluation. Chat writes
/// (not item counts) invalidate it, so streaming replacements and paging stay live.
@MainActor
private final class TrajectoryLedgerCache: ObservableObject {
    private weak var source: AppModel?
    private var revision: UInt64?
    private var english = false
    private var current: TrajectoryLedgerSnapshot?

    func snapshot(for model: AppModel) -> TrajectoryLedgerSnapshot {
        if source === model, revision == model.chatRevision,
           english == TrajL.en, let current {
            return current
        }
        let next = TrajectoryLedgerSnapshot(
            items: model.chat?.items ?? [],
            steps: model.chat?.steps ?? []
        )
        source = model
        revision = model.chatRevision
        english = TrajL.en
        current = next
        return next
    }
}

private struct TrajectoryLedgerRow: Identifiable {
    struct ID: Hashable {
        let turn: Int
        let key: String
    }

    let row: TrajRow
    let turn: Int
    let turnStart: Bool
    var id: ID { ID(turn: turn, key: row.key) }
}

private struct TrajectoryLedgerProjection {
    let rows: [TrajectoryLedgerRow]
    let turns: [Int]
}

private final class TrajectoryLedgerSnapshot {
    let turns: [TrajTurn]
    let requests: [TrajectoryRequest]
    let boundaryByRow: [String: TrajectoryRequest]
    private(set) var rowByKey: [String: TrajectoryLedgerRow] = [:]
    private(set) var assistantByKey: [String: TrajRow] = [:]
    private var toolRows: [TrajRow] = []
    private lazy var cells = trajectoryTimelineCells(turns)
    lazy var sequenceTimeline = deriveTrajectoryTimeline(cells, mode: .sequence)
    lazy var durationTimeline = deriveTrajectoryTimeline(cells, mode: .duration)
    private var projection: TrajectoryLedgerProjection?
    private var projectedQuery = ""
    private var projectedCallsCollapsed = false
    private var searchedQuery: String?
    private var searchMatches: Set<String>?

    init(items: [Item], steps: [StepRecord]) {
        turns = buildTrajectory(items, steps: steps)
        requests = buildTrajectoryRequests(items: items, steps: steps)
        boundaryByRow = trajectoryRequestBoundaries(requests, turns: turns)
        for turn in turns {
            for (index, row) in turn.rows.enumerated() {
                // Match the former first(where:) navigation even if keys repeat.
                if rowByKey[row.key] == nil {
                    rowByKey[row.key] = TrajectoryLedgerRow(row: row, turn: turn.index, turnStart: index == 0)
                }
                if row.kind == TrajL.kindAssistant, assistantByKey[row.key] == nil {
                    assistantByKey[row.key] = row
                }
                if row.callId != nil { toolRows.append(row) }
            }
        }
    }

    func project(query: String, callsCollapsed: Bool) -> TrajectoryLedgerProjection {
        if projectedQuery == query, projectedCallsCollapsed == callsCollapsed, let projection {
            return projection
        }
        if searchedQuery != query {
            searchMatches = trajectorySearchMatches(turns, query: query)
            searchedQuery = query
        }
        let matches = searchMatches
        var rows: [TrajectoryLedgerRow] = []
        var visibleTurns: [Int] = []
        for turn in turns {
            var first = true
            for row in turn.rows {
                if let matches, !matches.contains(row.key) { continue }
                if callsCollapsed && (row.kind == TrajL.kindTool || row.kind == TrajL.kindSubtool) { continue }
                rows.append(TrajectoryLedgerRow(row: row, turn: turn.index, turnStart: first))
                first = false
            }
            if matches == nil || !first { visibleTurns.append(turn.index) }
        }
        let next = TrajectoryLedgerProjection(rows: rows, turns: visibleTurns)
        projectedQuery = query
        projectedCallsCollapsed = callsCollapsed
        projection = next
        return next
    }

    func toolCalls(for row: TrajRow) -> [TrajRow] {
        let ids = Set(row.toolCallIds)
        guard !ids.isEmpty else { return [] }
        return toolRows.filter { candidate in
            candidate.callId.map { ids.contains($0) } ?? false
        }
    }
}

private struct TrajRowView: View {
    let row: TrajRow
    let highlighted: Bool
    let turnStart: Int?
    var requestBoundary: TrajectoryRequest? = nil
    var requestSelected = false
    let onClick: () -> Void
    var onRequestClick: (TrajectoryRequest) -> Void = { _ in }

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onClick) {
                ZStack(alignment: .topLeading) {
                    HStack(spacing: 7) {
                        if row.kind == TrajL.kindSubtool {
                            Color.clear.frame(width: 14)
                        }
                        KindBadge(kind: row.kind)
                        HStack(spacing: 0) {
                            Text(displayTitle)
                                .font(isTool ? Font.system(size: 12, design: .monospaced) : Font.system(size: 12))
                                .foregroundStyle(row.toolCallOnly ? T.text3 : T.ink)
                                .lineLimit(1)
                            if let preview = row.resultPreview {
                                Text(" → ")
                                    .font(Font.system(size: 12, design: .monospaced))
                                    .foregroundStyle(T.caption)
                                Text(preview)
                                    .font(Font.system(size: 12, design: .monospaced))
                                    .foregroundStyle(row.isError ? T.err : T.text2)
                                    .lineLimit(1)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.leading, 28)
                    .padding(.trailing, 8)
                    if let turnStart {
                        Text("\(turnStart)")
                            .font(Font.system(size: 8))
                            .foregroundStyle(T.text3)
                            .padding(.horizontal, 3)
                            .background(T.fill)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(TrajL.kindLabel(row.kind)) \(row.title)")
            .accessibilityIdentifier("trajRow.\(row.key)")
            if let requestBoundary {
                Button {
                    onRequestClick(requestBoundary)
                } label: {
                    Circle()
                        .fill(requestSelected ? T.accent : (row.isError ? T.err : T.caption))
                        .frame(width: 5, height: 5)
                        .frame(width: 24, height: 30)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(TrajL.requestLabel(requestBoundary.number))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 30, maxHeight: 30, alignment: .leading)
        .background(highlighted ? T.fill : Color.clear)
        .overlay(alignment: .leading) {
            if highlighted {
                T.accent.frame(width: 3)
            }
        }
        .overlay(alignment: .bottom) { Divider() }
    }

    private var isTool: Bool {
        row.kind == TrajL.kindTool || row.kind == TrajL.kindSubtool
    }

    private var displayTitle: String {
        row.toolCallOnly ? TrajL.recordToolCallOnly : row.title
    }
}

/// Desktop `KIND_ICON` + `.kindTag` at `@container width<=620px`: 19pt chip,
/// 13pt official SVG, label hidden. User chip is business-primary on
/// business-tertiary — not success green. Unknown kinds draw nothing.
private struct KindBadge: View {
    let kind: String

    var body: some View {
        ZStack {
            if let glyph {
                OfficialGlyph(
                    kind: glyph,
                    size: CGFloat(trajectoryKindIconSizePoints(for: kind)),
                    color: fg
                )
            }
        }
        .frame(
            width: CGFloat(trajectoryKindTagSizePoints),
            height: CGFloat(trajectoryKindTagSizePoints)
        )
        .background(bg, in: RoundedRectangle(cornerRadius: CGFloat(trajectoryKindTagRadiusPoints)))
        .accessibilityLabel(TrajL.kindLabel(kind))
    }

    private var glyph: OfficialGlyph.Kind? {
        switch kind {
        case TrajL.kindSystem: return .settingsOutlineRegular
        case TrajL.kindUser: return .userOutline
        case TrajL.kindContext: return .information
        case TrajL.kindCompacted: return .compacted
        case TrajL.kindAssistant: return .sparkle
        case TrajL.kindTool, TrajL.kindSubtool: return .toolWrench
        default: return nil
        }
    }

    /// Desktop `.user` / `.systemNeutral` / `.contextGreen` / `.toolAmber` /
    /// `.subtoolAmber` / `.assistantVioletBright` / `.compacted`.
    private var fg: Color {
        switch kind {
        case TrajL.kindUser: return T.accent
        case TrajL.kindContext: return T.trajectoryContext
        case TrajL.kindAssistant: return T.trajectoryAssistant
        case TrajL.kindTool: return T.warnText
        case TrajL.kindSubtool: return T.warnText.opacity(0.62)
        default: return T.text2
        }
    }

    private var bg: Color {
        switch kind {
        case TrajL.kindUser: return T.tint
        case TrajL.kindContext: return T.trajectoryContextBg
        case TrajL.kindAssistant: return T.trajectoryAssistantBg
        case TrajL.kindTool: return T.warnTint
        case TrajL.kindSubtool: return T.warnTint.opacity(0.58)
        default: return T.fill2
        }
    }
}

private struct SwimlaneChart: View {
    let model: TrajectoryTimelineModel
    var selectedKey: String?
    var onSpanClick: (String) -> Void

    var body: some View {
        let domain = max(model.end - model.start, 1.0)
        HStack(spacing: 0) {
            VStack(alignment: .trailing, spacing: 0) {
                ForEach([TrajL.columnInput, TrajL.columnModel, TrajL.columnTools], id: \.self) { label in
                    Text(label)
                        .font(Font.system(size: 10))
                        .foregroundStyle(T.caption)
                        .frame(height: 14, alignment: .center)
                }
            }
            .frame(width: 44)
            .padding(.trailing, 3)
            .padding(.top, 4)
            GeometryReader { geo in
                Canvas { context, size in
                    let topPad: CGFloat = 7
                    let laneH: CGFloat = 14
                    let barH: CGFloat = 8
                    let minSpan: CGFloat = 2
                    for b in model.turnBoundaries {
                        let x = (b.time - model.start) / domain * size.width
                        var path = Path()
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                        context.stroke(path, with: .color(T.border), lineWidth: 1)
                    }
                    for span in model.spans {
                        let left = (span.start - model.start) / domain * size.width
                        let rawW = (span.end - span.start) / domain * size.width
                        let w = max(rawW, minSpan)
                        let gap = min(rawW * 0.08, 1)
                        let top = topPad + CGFloat(span.lane) * laneH
                        let rect = CGRect(x: left + gap, y: top, width: max(w - gap * 2, minSpan), height: barH)
                        let selected = selectedKey == span.key
                        context.fill(
                            Path(roundedRect: rect, cornerRadius: 1),
                            with: .color(spanColor(span.kind, isError: span.isError).opacity(selected ? 1 : (span.kind == "message" || span.kind == "tool" || span.kind == "subtool" || span.isError ? 1 : 0.78)))
                        )
                        if selected {
                            context.fill(
                                Path(roundedRect: rect.insetBy(dx: 0, dy: -1), cornerRadius: 1),
                                with: .color(T.accent.opacity(0.25))
                            )
                        }
                    }
                }
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onEnded { value in
                    if let key = spanAt(x: value.location.x, y: value.location.y, width: geo.size.width) {
                        onSpanClick(key)
                    }
                })
            }
        }
        .frame(height: 50)
        .background(T.surface)
    }

    private func spanAt(x: CGFloat, y: CGFloat, width: CGFloat) -> String? {
        let domain = max(model.end - model.start, 1.0)
        let topPad: CGFloat = 7
        let laneH: CGFloat = 14
        let barH: CGFloat = 8
        let minSpan: CGFloat = 2
        if y < topPad { return nil }
        let lane = Int((y - topPad) / laneH)
        if !(0...2).contains(lane) { return nil }
        if y - topPad - CGFloat(lane) * laneH > barH { return nil }
        for span in model.spans.reversed() {
            if span.lane != lane { continue }
            let rawW = (span.end - span.start) / domain * width
            let gap = min(rawW * 0.08, minSpan / 2)
            let left = (span.start - model.start) / domain * width + gap
            let spanWidth = max(rawW - gap * 2, minSpan)
            if x >= left && x <= left + spanWidth { return span.key }
        }
        return nil
    }

    private func spanColor(_ kind: String, isError: Bool) -> Color {
        if isError { return T.err }
        switch kind {
        case "user": return T.ok
        case "context": return T.ok.opacity(0.7)
        case "message": return T.accent
        case "tool", "subtool": return T.warnText
        default: return T.text2
        }
    }
}
