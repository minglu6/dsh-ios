import Foundation

public struct HeaderSubagentRow: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let mode: String
    public let running: Bool?
}

/// A present catalog is authoritative, including an empty one. Legacy discovery may use
/// explicitly marked child sessions, but ordinary forks must never be counted as subagents.
public func sessionHeaderSubagents(
    parentSessionId: String,
    catalog: [SubagentCatalogEntry]?,
    sessions: [SessionSummary]
) -> [HeaderSubagentRow] {
    var summaries: [String: SessionSummary] = [:]
    for row in sessions { summaries[row.sessionId] = row }
    var seen: Set<String> = [parentSessionId]
    if let catalog {
        return catalog.compactMap { entry in
            guard seen.insert(entry.id).inserted else { return nil }
            let summary = summaries[entry.id]
            return HeaderSubagentRow(
                id: entry.id, title: entry.label ?? summary?.title ?? entry.id,
                mode: entry.mode, running: summary?.running
            )
        }
    }
    return sessions.compactMap { row in
        guard row.origin == "subagent", row.parentSessionId == parentSessionId,
              seen.insert(row.sessionId).inserted else { return nil }
        return HeaderSubagentRow(
            id: row.sessionId, title: row.title ?? row.sessionId,
            mode: "unknown", running: row.running
        )
    }
}

public func sessionHeaderSubagentCount(_ count: Int, english: Bool) -> String {
    english ? "\(count) subagent\(count == 1 ? "" : "s")" : "\(count) 个子智能体"
}
