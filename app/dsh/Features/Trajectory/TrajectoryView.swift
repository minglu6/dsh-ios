import SwiftUI
import DSHProtocol

struct TrajectoryView: View {
    @ObservedObject var model: AppModel
    @State private var selected: TrajRow?
    @State private var selectedRequest: TrajectoryRequest?
    @State private var requestTab: TrajRequestTab = .overview
    @State private var selectedTurn = 0
    @State private var actualDuration = false
    @State private var turnsCollapsed = false
    @State private var callsCollapsed = false
    @State private var searchQuery = ""

    private var turns: [TrajTurn] {
        buildTrajectory(model.chat?.items ?? [], steps: model.chat?.steps ?? [])
    }

    private var requests: [TrajectoryRequest] {
        buildTrajectoryRequests(items: model.chat?.items ?? [], steps: model.chat?.steps ?? [])
    }

    private var boundaryByRow: [String: TrajectoryRequest] {
        var map: [String: TrajectoryRequest] = [:]
        for request in requests {
            if let key = requestBoundaryRowKey(request, turns: turns) {
                map[key] = request
            }
        }
        return map
    }

    var body: some View {
        let loaded = model.chat?.loaded == true
        if !loaded {
            VStack(spacing: 8) {
                ProgressView()
                Text(TrajL.historyLoadingTrajectory)
                    .font(.subheadline)
                    .foregroundStyle(T.caption)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ledger
        }
    }

    private var ledger: some View {
        let mode: TrajectoryTimelineMode = actualDuration ? .duration : .sequence
        let cells = trajectoryTimelineCells(turns)
        let timeline = deriveTrajectoryTimeline(cells, mode: mode)
        let searchMatches = trajectorySearchMatches(turns, query: searchQuery)
        return VStack(spacing: 0) {
            toolbar
            if let timeline {
                SwimlaneChart(model: timeline, selectedKey: selected?.key) { key in
                    for turn in turns {
                        if let row = turn.rows.first(where: { $0.key == key }) {
                            selected = row
                            selectedTurn = turn.index
                            return
                        }
                    }
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
                                .font(.caption)
                                .foregroundStyle(model.chat?.loadingOlder == true ? T.text2 : T.accent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .disabled(model.chat?.loadingOlder == true || model.chat?.hasMore != true)
                    }
                    ForEach(turns, id: \.index) { turn in
                        let visible = turn.rows.filter { row in
                            (searchMatches == nil || searchMatches!.contains(row.key)) &&
                            !(callsCollapsed && (row.kind == TrajL.kindTool || row.kind == TrajL.kindSubtool))
                        }
                        if searchMatches != nil && visible.isEmpty {
                            EmptyView()
                        } else if turnsCollapsed {
                            Button { turnsCollapsed = false } label: {
                                Text(TrajL.turnLabel(turn.index))
                                    .font(.caption)
                                    .foregroundStyle(T.text3)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                            }
                        } else {
                            ForEach(Array(visible.enumerated()), id: \.element.key) { index, row in
                                let boundary = boundaryByRow[row.key]
                                TrajRowView(
                                    row: row,
                                    highlighted: selected?.key == row.key,
                                    turnStart: index == 0 ? turn.index : nil,
                                    requestBoundary: boundary,
                                    requestSelected: selectedRequest != nil && selectedRequest?.identity == boundary?.identity
                                ) {
                                    selected = row
                                    selectedTurn = turn.index
                                } onRequestClick: { req in
                                    selected = nil
                                    requestTab = .overview
                                    selectedRequest = req
                                }
                            }
                        }
                    }
                }
            }
        }
        .sheet(item: $selected) { row in
            TrajectoryDetailSheet(
                row: row,
                turnIndex: selectedTurn,
                parentRequest: requestForRow(row, requests: requests),
                onOpenRequest: { req in
                    selected = nil
                    requestTab = .overview
                    selectedRequest = req
                },
                onOpenRequestTiming: { req in
                    selected = nil
                    requestTab = .timing
                    selectedRequest = req
                },
                toolCalls: toolCalls(for: row)
            ) { call in
                selected = call
                if let turn = turns.first(where: { $0.rows.contains(where: { $0.key == call.key }) }) {
                    selectedTurn = turn.index
                }
            }
        }
        .sheet(item: $selectedRequest) { req in
            TrajectoryRequestSheet(
                request: req,
                onOpenResult: { key in
                    selectedRequest = nil
                    for turn in turns {
                        if let row = turn.rows.first(where: { $0.key == key }) {
                            selected = row
                            selectedTurn = turn.index
                            return
                        }
                    }
                },
                initialTab: requestTab,
                assistantRow: req.resultKey.flatMap { key in
                    turns.flatMap(\.rows).first { $0.key == key && $0.kind == TrajL.kindAssistant }
                },
                onDismiss: { selectedRequest = nil }
            )
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
                    .font(.caption)
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
                Text(label).font(.caption).foregroundStyle(pressed ? T.ink : T.text3)
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(pressed ? T.fill : Color.clear, in: RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(pressed ? .isSelected : [])
    }

    private func toolCalls(for row: TrajRow) -> [TrajRow] {
        let ids = Set(row.toolCallIds)
        guard !ids.isEmpty else { return [] }
        return turns.flatMap(\.rows).filter { candidate in
            if let callId = candidate.callId { return ids.contains(callId) }
            return false
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
                                .font(isTool ? .system(size: 12, design: .monospaced) : .system(size: 12))
                                .foregroundStyle(row.toolCallOnly ? T.text3 : T.ink)
                                .lineLimit(1)
                            if let preview = row.resultPreview {
                                Text(" → ")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(T.caption)
                                Text(preview)
                                    .font(.system(size: 12, design: .monospaced))
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
                            .font(.system(size: 8))
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
                        .font(.system(size: 10))
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
