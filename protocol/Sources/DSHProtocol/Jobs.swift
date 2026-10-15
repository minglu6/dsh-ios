import Foundation

/// One row from Host `jobs.list` / follow `job` frames.
public struct JobRow: Sendable, Equatable, Identifiable {
    public var id: String
    public var status: String
    public var title: String
    public var detail: String?

    public var isLive: Bool { status == "running" || status == "stopping" }
    public var canKill: Bool { status == "running" || status == "pending" }

    public init(id: String, status: String, title: String, detail: String? = nil) {
        self.id = id
        self.status = status
        self.title = title
        self.detail = detail
    }

    public static func parse(_ element: JSONValue) -> JobRow? {
        guard let id = element["id"].str()?.nilIfBlank ?? element["jobId"].str()?.nilIfBlank else { return nil }
        let status = element["status"].str() ?? element["state"].str() ?? ""
        let title = element["label"].str()?.nilIfBlank
            ?? element["command"].str()?.nilIfBlank
            ?? element["name"].str()?.nilIfBlank
            ?? id
        return JobRow(id: id, status: status, title: title, detail: element["detail"].str())
    }
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
    (result["jobs"].arr() ?? []).compactMap(JobRow.parse)
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
