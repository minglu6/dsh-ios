public struct HistoryPageRequest: Sendable, Equatable {
    public var throughSeq: Int64
    public var beforeSeq: Int64?
    public var maxMessages: Int
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
