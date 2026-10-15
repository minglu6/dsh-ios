import Foundation

/// Presentation clock. Events are already reduced before requesting a publication.
public protocol TranscriptClock: Sendable {
    func sleepMilliseconds(_ milliseconds: Int) async
}

public struct RealTranscriptClock: TranscriptClock {
    public init() {}
    public func sleepMilliseconds(_ milliseconds: Int) async {
        try? await Task.sleep(nanoseconds: UInt64(milliseconds) * 1_000_000)
    }
}

/// Virtual clock for protocol tests. Continuations resume only when `advance` reaches their deadline.
public final class ManualTranscriptClock: TranscriptClock, @unchecked Sendable {
    private let mutex = Mutex()
    private var now = 0
    private var waiters: [(deadline: Int, continuation: CheckedContinuation<Void, Never>)] = []

    public init() {}

    public func sleepMilliseconds(_ milliseconds: Int) async {
        await withCheckedContinuation { continuation in
            mutex.withLock {
                waiters.append((now + milliseconds, continuation))
            }
        }
    }

    public var pendingWaiterCount: Int {
        mutex.withLock { waiters.count }
    }

    /// Move virtual time without resuming waiters (kotlinx `advanceTimeBy`).
    public func advanceTime(_ milliseconds: Int) {
        mutex.withLock { now += milliseconds }
    }

    /// Resume waiters whose deadline is due (kotlinx `runCurrent` after time has moved).
    public func runDue() {
        let due: [CheckedContinuation<Void, Never>] = mutex.withLock {
            var keep: [(deadline: Int, continuation: CheckedContinuation<Void, Never>)] = []
            var fire: [CheckedContinuation<Void, Never>] = []
            for waiter in waiters {
                if waiter.deadline <= now {
                    fire.append(waiter.continuation)
                } else {
                    keep.append(waiter)
                }
            }
            waiters = keep
            return fire
        }
        due.forEach { $0.resume() }
    }

    public func advance(_ milliseconds: Int) {
        advanceTime(milliseconds)
        runDue()
    }
}

/// Actor-owned presentation clock. Events are already reduced before requesting a publication.
public final class TranscriptPublisher: @unchecked Sendable {
    private let mutex = Mutex()
    private var pending: Task<Void, Never>?
    private let publish: @Sendable () -> Void
    private let clock: TranscriptClock
    private let delayMs: Int

    public init(
        clock: TranscriptClock = RealTranscriptClock(),
        delayMs: Int = 50,
        publish: @escaping @Sendable () -> Void
    ) {
        self.clock = clock
        self.delayMs = delayMs
        self.publish = publish
    }

    /// Fixed window, not debounce: continuous output cannot keep postponing the next paint.
    public func schedule() {
        mutex.withLock {
            if pending != nil { return }
            pending = Task { [weak self] in
                guard let self else { return }
                await self.clock.sleepMilliseconds(self.delayMs)
                guard !Task.isCancelled else { return }
                self.mutex.withLock { self.pending = nil }
                self.publish()
            }
        }
    }

    /// Structural/terminal state includes all preceding deltas and supersedes a scheduled paint.
    public func flush() {
        cancel()
        publish()
    }

    /// A detached subscription must never publish into its replacement.
    public func cancel() {
        mutex.withLock {
            pending?.cancel()
            pending = nil
        }
    }
}
