public struct HistoryPageRequest: Sendable, Equatable {
    public var throughSeq: Int64
    public var beforeSeq: Int64?
    public var maxMessages: Int
}

/// Phone follow request. `maxMessages` is intentionally absent (Android P0).
public enum FollowRequest {
    public static func args(sessionId: String, afterSeq: Int64? = nil, address: PocketSubagentAddress? = nil) -> JSONValue {
        jsonObject([
            "sessionId": .string(sessionId),
            "afterSeq": afterSeq.map { .number(Double($0)) },
            "parentSessionId": address.map { .string($0.parentSessionId) },
            "subagentMode": address.map { .string($0.mode) },
        ])
    }
}

public enum HistoryPagingPolicy {
    public static let pageSize = 100

    public static func canLoadOlder(hasMore: Bool, loadingOlder: Bool, firstSeq: Int64) -> Bool {
        hasMore && !loadingOlder && firstSeq >= 0
    }

    public static func pageRequest(cursor: Int64, firstSeq: Int64, maxMessages: Int = pageSize) -> HistoryPageRequest {
        precondition(firstSeq >= 0, "firstSeq must be known before paging")
        precondition(maxMessages > 0, "maxMessages must be positive")
        return HistoryPageRequest(
            throughSeq: max(cursor, firstSeq),
            beforeSeq: firstSeq,
            maxMessages: maxMessages
        )
    }
}
