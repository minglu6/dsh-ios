public enum ReconnectBackoffPolicy {
    public static let initialMs: Int64 = 1_000
    public static let maxMs: Int64 = 30_000

    public static func reset() -> Int64 { initialMs }

    public static func next(_ currentMs: Int64) -> Int64 {
        min(currentMs * 2, maxMs)
    }
}
