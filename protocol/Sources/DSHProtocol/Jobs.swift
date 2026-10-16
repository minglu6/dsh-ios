import Foundation

/// One row from Host `jobs.list` / follow `job` frames.
public struct JobRow: Sendable, Equatable, Identifiable {
    public var id: String
    public var status: String
    public var title: String
    public var detail: String?
    public var kind: String
    public var startedAt: Int64
    public var finishedAt: Int64?
    public var progress: String?
    public var outputTotal: Int

    public var isLive: Bool { status == "running" || status == "stopping" }
    public var canKill: Bool { status == "running" }
    public var isObservable: Bool { isLive || outputTotal > 0 }
    public var qualifier: String? { progress ?? detail }

    public init(
        id: String,
        status: String,
        title: String,
        detail: String? = nil,
        kind: String = "",
        startedAt: Int64 = 0,
        finishedAt: Int64? = nil,
        progress: String? = nil,
        outputTotal: Int = 0
    ) {
        self.id = id
        self.status = status
        self.title = title
        self.detail = detail
        self.kind = kind
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.progress = progress
        self.outputTotal = outputTotal
    }

    public static func parse(_ element: JSONValue) -> JobRow? {
        guard let id = jobIdentity(element) else { return nil }
        let status = element["status"].str() ?? element["state"].str() ?? ""
        let title = element["label"].str()?.nilIfBlank
            ?? element["command"].str()?.nilIfBlank
            ?? element["name"].str()?.nilIfBlank
            ?? id
        let output = element["output"]
        let outputTotal = output["total"].int() ?? output["bytes"].int() ?? 0
        return JobRow(
            id: id,
            status: status,
            title: title,
            detail: element["detail"].str(),
            kind: element["kind"].str() ?? "",
            startedAt: element["startedAt"].long() ?? 0,
            finishedAt: element["finishedAt"].long(),
            progress: element["progress"].str(),
            outputTotal: outputTotal
        )
    }
}

/// Desktop `JobListAction` two-press kill: one armed row at a time.
public enum JobKillPhase: Equatable, Sendable {
    case idle
    case armed(key: String, untilMs: Int64)
    case pending(key: String)
    case failed(key: String, untilMs: Int64)

    public var key: String? {
        switch self {
        case .idle: return nil
        case .armed(let key, _), .pending(let key), .failed(let key, _): return key
        }
    }

    public var stateName: String {
        switch self {
        case .idle: return "idle"
        case .armed: return "armed"
        case .pending: return "pending"
        case .failed: return "failed"
        }
    }
}

public let jobKillArmMs: Int64 = 3_000
public let jobKillFailedMs: Int64 = 4_000

public func jobKillPress(phase: JobKillPhase, key: String, nowMs: Int64) -> JobKillPhase {
    if case .armed(let armed, let until) = phase, armed == key, nowMs < until {
        return .pending(key: key)
    }
    return .armed(key: key, untilMs: nowMs + jobKillArmMs)
}

public func jobKillTick(phase: JobKillPhase, nowMs: Int64, runningKeys: Set<String>) -> JobKillPhase {
    switch phase {
    case .idle:
        return .idle
    case .armed(let key, let until):
        if !runningKeys.contains(key) || nowMs >= until { return .idle }
        return phase
    case .pending(let key):
        if !runningKeys.contains(key) { return .idle }
        return phase
    case .failed(let key, let until):
        if !runningKeys.contains(key) || nowMs >= until { return .idle }
        return phase
    }
}

public func jobKillAdmit(phase: JobKillPhase, key: String, ok: Bool, nowMs: Int64) -> JobKillPhase {
    guard case .pending(let pending) = phase, pending == key else { return phase }
    return ok ? phase : .failed(key: key, untilMs: nowMs + jobKillFailedMs)
}

/// Live rows first in start order, then settled rows newest-first.
public func orderedJobRows(_ jobs: [JobRow]) -> [JobRow] {
    jobs.sorted { left, right in
        if left.isLive != right.isLive { return left.isLive }
        if left.isLive { return left.startedAt < right.startedAt }
        let leftDone = left.finishedAt ?? left.startedAt
        let rightDone = right.finishedAt ?? right.startedAt
        if leftDone != rightDone { return leftDone > rightDone }
        return left.startedAt < right.startedAt
    }
}

public func jobElapsedMs(_ job: JobRow, nowMs: Int64) -> Int64 {
    if job.isLive { return max(0, nowMs - job.startedAt) }
    return max(0, (job.finishedAt ?? job.startedAt) - job.startedAt)
}

/// Desktop `ui-jobs` `duration.*` (at most two adjacent units).
public func jobDurationText(elapsedMs: Int64, english: Bool) -> String {
    let total = max(0, elapsedMs / 1_000)
    let seconds = total % 60
    let minutes = (total / 60) % 60
    let hours = total / 3_600
    if english {
        if hours > 0 { return "\(hours)h \(minutes)m" }
        if minutes > 0 { return "\(minutes)m \(seconds)s" }
        return "\(seconds)s"
    }
    if hours > 0 { return "\(hours)小时\(minutes)分" }
    if minutes > 0 { return "\(minutes)分\(seconds)秒" }
    return "\(seconds)秒"
}

public func jobStatusLabel(_ status: String, english: Bool) -> String {
    switch status {
    case "running": return english ? "running" : "运行中"
    case "stopping": return english ? "stopping" : "正在停止"
    case "completed": return english ? "completed" : "已完成"
    case "killed": return english ? "cancelled" : "已取消"
    case "failed": return english ? "failed" : "已失败"
    default: return status
    }
}

public func jobKillStopLabel(label: String, english: Bool) -> String {
    english ? "Stop task \(label)" : "停止任务 \(label)"
}

public func jobKillConfirmLabel(english: Bool) -> String {
    english ? "Click again to confirm" : "再次点击确认停止"
}

public func jobKillConfirmAction(english: Bool) -> String {
    english ? "Confirm stop" : "确认停止"
}

public func jobKillFailedLabel(english: Bool) -> String {
    english ? "Stop failed" : "停止失败"
}

public func jobSectionLive(english: Bool) -> String {
    english ? "Running" : "进行中"
}

public func jobSectionSettled(count: Int, english: Bool) -> String {
    english ? "Finished \(count)" : "已结束 \(count)"
}

public func jobSectionClear(english: Bool) -> String {
    english ? "Clear" : "清空"
}

public enum JobChip: Sendable, Equatable {
    case unavailable
    case live(Int)
    case retained(Int)
}

/// Header chip visibility and copy. Failed refresh is not zero; stale running counts must not survive.
public enum JobsActionLabel {
    public static func chip(jobs: [JobRow]?, failed: Bool) -> JobChip? {
        if failed { return .unavailable }
        guard let jobs, !jobs.isEmpty else { return nil }
        let live = jobs.filter(\.isLive).count
        return live > 0 ? .live(live) : .retained(jobs.count)
    }

    public static func text(_ chip: JobChip, en: Bool) -> String {
        switch chip {
        case .unavailable:
            return en ? "Job status unavailable" : "任务状态不可用"
        case .live(let count):
            if en {
                return count == 1 ? "1 background job running" : "\(count) background jobs running"
            }
            return "\(count) 个后台任务运行中"
        case .retained(let count):
            if en {
                return count == 1 ? "1 background job" : "\(count) background jobs"
            }
            return "\(count) 个后台任务"
        }
    }
}

public struct JobOutputChunk: Sendable, Equatable {
    public var text: String
    public var gapBefore: Bool

    public init(text: String, gapBefore: Bool = false) {
        self.text = text
        self.gapBefore = gapBefore
    }
}

public enum JobFollowKind: Sendable, Equatable {
    case opened(status: String)
    case status(status: String)
    case output(lossy: Bool, chunks: [JobOutputChunk])
    case other
}

public enum JobFollowFrame {
    public static func parse(_ frame: JSONValue) -> JobFollowKind {
        switch frame["type"].str() {
        case "opened":
            return .opened(status: frame["job"]["status"].str() ?? "")
        case "status":
            return .status(status: frame["job"]["status"].str() ?? "")
        case "output":
            let chunks = (frame["chunks"].arr() ?? []).map { chunk in
                JobOutputChunk(text: chunk["text"].str() ?? "", gapBefore: jsonFlagTrue(chunk["gapBefore"]))
            }
            return .output(lossy: jsonFlagTrue(frame["lossy"]), chunks: chunks)
        default:
            return .other
        }
    }
}

public enum JobFollowRequest {
    public static func args(sessionId: String, jobId: String, from: Int64? = nil) -> JSONValue {
        jsonObject([
            "sessionId": .string(sessionId),
            "jobId": .string(jobId),
            "from": from.map { .number(Double($0)) },
        ])
    }
}

/// First assigned `subId` wins. A concurrent follow for the same job must unfollow the extra subscription.
public enum JobFollowClaim {
    public static func assign(current: inout [String: String], jobId: String, subId: String) -> String? {
        if let existing = current[jobId] {
            return existing == subId ? nil : subId
        }
        current[jobId] = subId
        return nil
    }

    /// One in-flight `jobs.follow` per job. Returns false when already assigned or already starting.
    public static func begin(inFlight: inout Set<String>, assigned: [String: String], jobId: String) -> Bool {
        if assigned[jobId] != nil { return false }
        return inFlight.insert(jobId).inserted
    }

    public static func end(inFlight: inout Set<String>, jobId: String) {
        inFlight.remove(jobId)
    }
}

/// Android `JobsSheet.appendOutput`: split on `\n` and extend the last line.
public func appendJobOutput(_ lines: inout [String], text: String) {
    if text.isEmpty { return }
    if lines.isEmpty { lines.append("") }
    let pieces = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    guard let first = pieces.first else { return }
    lines[lines.count - 1] += first
    if pieces.count > 1 {
        lines.append(contentsOf: pieces.dropFirst())
    }
}

public func applyJobOutputFrames(
    to lines: inout [String],
    lossy: Bool,
    chunks: [JobOutputChunk],
    expiredNotice: String,
    missingNotice: String
) {
    if lossy { appendJobOutput(&lines, text: "\n\(expiredNotice)\n") }
    for chunk in chunks {
        if chunk.gapBefore { appendJobOutput(&lines, text: "\n\(missingNotice)\n") }
        appendJobOutput(&lines, text: chunk.text)
    }
}

public func parseJobRoster(_ result: JSONValue) -> [JobRow] {
    let rows = result["jobs"].arr() ?? result["rows"].arr() ?? result.arr() ?? []
    return rows.compactMap(JobRow.parse)
}

/// Host `job.list` rows use string ids (`bash-1`); pocket JSON may also send a number.
public func jobIdentity(_ element: JSONValue) -> String? {
    element["id"].str()?.nilIfBlank
        ?? element["jobId"].str()?.nilIfBlank
        ?? element["id"].long().map(String.init)
        ?? element["jobId"].long().map(String.init)
}

/// Chip `.task` must run before any roster exists (same empty-Group trap as ChangesCard).
public let jobsActionWatchAnchorPoints: Double = 1

public func jobsActionShouldWatch(online: Bool, hasListOp: Bool) -> Bool {
    online && hasListOp
}

/// kotlinx `JsonElement.toString() == "true"` for boolean or string primitives.
public func jsonFlagTrue(_ value: JSONValue) -> Bool {
    if value.bool() == true { return true }
    if value.str() == "true" { return true }
    return false
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : self
    }
}
