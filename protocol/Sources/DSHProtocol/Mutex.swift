import Foundation

/// Scoped `NSLock` so `lock`/`unlock` are never invoked from an `async` function body.
final class Mutex: @unchecked Sendable {
    private let lock = NSLock()

    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body()
    }
}
