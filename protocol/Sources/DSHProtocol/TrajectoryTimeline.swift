import Foundation

/// Operation-sequence and recorded-time projections for the trajectory swimlane.
/// Mirrors `@deepseek-ai/dsh-client-ui-trajectory` `timeline.ts` (`deriveTrajectoryTimeline`).
public enum TrajectoryTimelineMode: Sendable {
    /// Equal-width ops (时长 off).
    case sequence
    /// Recorded duration with idle gaps compressed (时长 on).
    case duration
    /// Recorded duration retaining wall-clock idle gaps (desktop 实际时间+时长).
    case actual
}

public struct TrajectoryTimeRange: Sendable, Equatable {
    public var start: Double
    public var end: Double
    public init(start: Double, end: Double) {
        self.start = start
        self.end = end
    }
}

public struct TrajectoryTimelineSpan: Sendable, Equatable {
    public var key: String
    public var kind: String
    public var lane: Int
    public var start: Double
    public var end: Double
    public var isError: Bool
    public var label: String

    public init(
        key: String,
        kind: String,
        lane: Int,
        start: Double,
        end: Double,
        isError: Bool = false,
        label: String = ""
    ) {
        self.key = key
        self.kind = kind
        self.lane = lane
        self.start = start
        self.end = end
        self.isError = isError
        self.label = label
    }
}

public struct TrajectoryTimelineTurnBoundary: Sendable, Equatable {
    public var turn: Int
    public var time: Double
    public init(turn: Int, time: Double) {
        self.turn = turn
        self.time = time
    }
}

public struct TrajectoryTimelineModel: Sendable, Equatable {
    public var start: Double
    public var end: Double
    public var spans: [TrajectoryTimelineSpan]
    public var turnBoundaries: [TrajectoryTimelineTurnBoundary]

    public init(
        start: Double,
        end: Double,
        spans: [TrajectoryTimelineSpan],
        turnBoundaries: [TrajectoryTimelineTurnBoundary]
    ) {
        self.start = start
        self.end = end
        self.spans = spans
        self.turnBoundaries = turnBoundaries
    }
}

/// Desktop `laneFor`: tools → lane 2 (工具), assistant/compacted → lane 1 (模型), else lane 0 (输入).
public func trajectoryLaneFor(_ kind: String) -> Int {
    switch kind {
    case "tool", "subtool", "工具", "子工具": return 2
    case "message", "compacted", "助手", "已压缩": return 1
    default: return 0
    }
}

/// Map Chinese row kind labels to the desktop `data-timeline-span` token.
public func trajectorySpanKind(_ kind: String) -> String {
    switch kind {
    case "系统": return "system"
    case "用户": return "user"
    case "上下文": return "context"
    case "助手": return "message"
    case "工具": return "tool"
    case "子工具": return "subtool"
    case "已压缩": return "compacted"
    default: return kind
    }
}

public struct TrajectoryTimelineCell: Sendable, Equatable {
    public var key: String
    public var kind: String
    public var label: String
    public var turn: Int?
    public var startedAt: Int64?
    public var timeSeconds: Double?
    public var isError: Bool
    public var requestOnly: Bool

    public init(
        key: String,
        kind: String,
        label: String,
        turn: Int?,
        startedAt: Int64?,
        timeSeconds: Double?,
        isError: Bool = false,
        requestOnly: Bool = false
    ) {
        self.key = key
        self.kind = kind
        self.label = label
        self.turn = turn
        self.startedAt = startedAt
        self.timeSeconds = timeSeconds
        self.isError = isError
        self.requestOnly = requestOnly
    }
}

/// Project every visible record into a stable three-lane timeline.
/// Returns nil when no record is visible.
public func deriveTrajectoryTimeline(
    _ cells: [TrajectoryTimelineCell],
    mode: TrajectoryTimelineMode = .sequence
) -> TrajectoryTimelineModel? {
    if mode != .sequence {
        return deriveTimedTimeline(
            cells,
            actualDuration: mode == .duration || mode == .actual,
            compressIdle: mode == .duration
        )
    }
    var spans: [TrajectoryTimelineSpan] = []
    var turnBoundaries: [TrajectoryTimelineTurnBoundary] = []
    var lastTurn: Int?
    for cell in cells {
        if cell.requestOnly { continue }
        if let turn = cell.turn, turn != lastTurn {
            turnBoundaries.append(TrajectoryTimelineTurnBoundary(turn: turn, time: Double(spans.count)))
            lastTurn = turn
        }
        let start = Double(spans.count)
        spans.append(TrajectoryTimelineSpan(
            key: cell.key,
            kind: trajectorySpanKind(cell.kind),
            lane: trajectoryLaneFor(cell.kind),
            start: start,
            end: start + 1.0,
            isError: cell.isError,
            label: cell.label
        ))
    }
    if spans.isEmpty { return nil }
    return TrajectoryTimelineModel(start: 0.0, end: Double(spans.count), spans: spans, turnBoundaries: turnBoundaries)
}

private func finite(_ value: Double?) -> Bool {
    guard let value else { return false }
    return value.isFinite
}

private func cellRange(_ cell: TrajectoryTimelineCell) -> TrajectoryTimeRange? {
    guard cell.startedAt != nil else { return nil }
    let durationMs = finite(cell.timeSeconds) ? max(0.0, (cell.timeSeconds ?? 0) * 1_000.0) : 0.0
    let start = Double(cell.startedAt!)
    return TrajectoryTimeRange(start: start, end: start + durationMs)
}

private func deriveTimedTimeline(
    _ cells: [TrajectoryTimelineCell],
    actualDuration: Bool,
    compressIdle: Bool
) -> TrajectoryTimelineModel? {
    struct Raw {
        var turn: Int?
        var span: TrajectoryTimelineSpan
    }
    var rawSpans: [Raw] = []
    for cell in cells {
        if cell.requestOnly { continue }
        guard let range = cellRange(cell) else { continue }
        rawSpans.append(Raw(
            turn: cell.turn,
            span: TrajectoryTimelineSpan(
                key: cell.key,
                kind: trajectorySpanKind(cell.kind),
                lane: trajectoryLaneFor(cell.kind),
                start: range.start,
                end: range.end,
                isError: cell.isError,
                label: cell.label
            )
        ))
    }
    if rawSpans.isEmpty { return nil }

    var removedIdleBySpan: [String: Double] = [:]
    var removedIdle = 0.0
    var coveredUntil: Double?
    let sorted = rawSpans.map(\.span).sorted {
        if $0.start != $1.start { return $0.start < $1.start }
        return $0.end < $1.end
    }
    for span in sorted {
        if compressIdle, let covered = coveredUntil, span.start > covered {
            removedIdle += span.start - covered
        }
        removedIdleBySpan[span.key] = removedIdle
        coveredUntil = coveredUntil.map { max($0, span.end) } ?? span.end
    }

    var spans: [TrajectoryTimelineSpan] = []
    var turnBoundaries: [TrajectoryTimelineTurnBoundary] = []
    var lastTurn: Int?
    for raw in rawSpans {
        let offset = removedIdleBySpan[raw.span.key] ?? 0.0
        var projected = raw.span
        projected.start = raw.span.start - offset
        projected.end = (actualDuration ? raw.span.end : raw.span.start) - offset
        spans.append(projected)
        if let turn = raw.turn, turn != lastTurn {
            turnBoundaries.append(TrajectoryTimelineTurnBoundary(turn: turn, time: projected.start))
            lastTurn = turn
        }
    }
    return TrajectoryTimelineModel(
        start: spans.map(\.start).min() ?? 0,
        end: spans.map(\.end).max() ?? 0,
        spans: spans,
        turnBoundaries: turnBoundaries
    )
}
