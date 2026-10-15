import Foundation

/// How the pocket frames are reaching the desktop.
public enum Route: String, Sendable, Equatable {
    case wsLocal
    case wsTailscale
    case wsLan

    /// Short label for the connections chip (no emoji).
    public var label: String {
        switch self {
        case .wsLocal: return "local"
        case .wsTailscale: return "Tailscale"
        case .wsLan: return "LAN"
        }
    }
}

public protocol FrameTransport: AnyObject {
    var route: Route { get }
    var closeReason: String? { get }
    func send(_ text: String) async throws
    func receive() async throws -> String
    func close()
    func ping() async throws
}

public func isLoopbackHost(_ host: String) -> Bool {
    host == "127.0.0.1" || host == "localhost" || host == "::1"
        || host.caseInsensitiveCompare("0:0:0:0:0:0:0:1") == .orderedSame
}

public func isTailscaleHost(_ host: String) -> Bool {
    if host.hasSuffix(".ts.net") { return true }
    let parts = host.split(separator: ".").compactMap { Int($0) }
    return parts.count == 4 && parts[0] == 100 && (64...127).contains(parts[1])
}

public func classifyWsRoute(_ host: String) -> Route {
    if isLoopbackHost(host) { return .wsLocal }
    if isTailscaleHost(host) { return .wsTailscale }
    return .wsLan
}

public func websocketURL(host: String, port: Int) -> URL? {
    guard (1...65535).contains(port), !host.isEmpty else { return nil }
    let encoded = host.contains(":") ? "[\(host)]" : host
    return URL(string: "ws://\(encoded):\(port)")
}

public func transportPlan(host: String?, port: Int) -> [URL] {
    guard let host, !host.isEmpty, let url = websocketURL(host: host, port: port) else { return [] }
    return [url]
}

final class WebSocketOpenWaiter: NSObject, URLSessionWebSocketDelegate, @unchecked Sendable {
    private let mutex = Mutex()
    private var continuation: CheckedContinuation<Void, Error>?
    private var opened = false
    private var failure: Error?

    func wait() async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            enum Outcome {
                case alreadyOpen
                case failed(Error)
                case waiting
            }
            let outcome: Outcome = mutex.withLock {
                if opened { return .alreadyOpen }
                if let failure { return .failed(failure) }
                continuation = cont
                return .waiting
            }
            switch outcome {
            case .alreadyOpen:
                cont.resume()
            case .failed(let error):
                cont.resume(throwing: error)
            case .waiting:
                break
            }
        }
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        let cont: CheckedContinuation<Void, Error>? = mutex.withLock {
            opened = true
            let pending = continuation
            continuation = nil
            return pending
        }
        cont?.resume()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error else { return }
        let cont: CheckedContinuation<Void, Error>? = mutex.withLock {
            failure = error
            let pending = continuation
            continuation = nil
            return pending
        }
        cont?.resume(throwing: PocketError(code: "transport", message: error.localizedDescription))
    }
}

final class URLSessionFrameTransport: FrameTransport {
    let route: Route
    private let task: URLSessionWebSocketTask
    private let session: URLSession
    private let waiter: WebSocketOpenWaiter
    private let queue = DispatchQueue(label: "dev.dsh.pocket.transport")
    private var closed = false
    private(set) var closeReason: String?

    init(task: URLSessionWebSocketTask, session: URLSession, waiter: WebSocketOpenWaiter, route: Route) {
        self.task = task
        self.session = session
        self.waiter = waiter
        self.route = route
    }

    func send(_ text: String) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            queue.async {
                if self.closed {
                    cont.resume(throwing: PocketError(code: "transport", message: "not connected"))
                    return
                }
                self.task.send(.string(text)) { error in
                    if let error {
                        cont.resume(throwing: PocketError(code: "transport", message: error.localizedDescription))
                    } else {
                        cont.resume()
                    }
                }
            }
        }
    }

    func ping() async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            queue.async {
                if self.closed {
                    cont.resume(throwing: PocketError(code: "transport", message: "not connected"))
                    return
                }
                self.task.sendPing { error in
                    if let error {
                        cont.resume(throwing: PocketError(code: "transport", message: error.localizedDescription))
                    } else {
                        cont.resume()
                    }
                }
            }
        }
    }

    func receive() async throws -> String {
        let message = try await task.receive()
        switch message {
        case .string(let text):
            return text
        case .data:
            throw PocketError(code: "transport", message: "binary frames are not supported")
        @unknown default:
            throw PocketError(code: "transport", message: "unknown websocket message")
        }
    }

    func close() {
        finish(reason: nil)
    }

    func fail(_ reason: String) {
        finish(reason: reason)
    }

    private func finish(reason: String?) {
        queue.sync {
            if closed { return }
            closed = true
            closeReason = reason
            if reason == nil {
                task.cancel(with: .goingAway, reason: Data("bye".utf8))
            } else {
                task.cancel(with: .abnormalClosure, reason: reason?.data(using: .utf8))
            }
            session.finishTasksAndInvalidate()
        }
    }
}

enum TransportOpener {
    static func open(url: URL, route: Route, timeoutMs: Int64) async throws -> URLSessionFrameTransport {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = TimeInterval(timeoutMs) / 1000
        config.waitsForConnectivity = true
        let waiter = WebSocketOpenWaiter()
        let session = URLSession(configuration: config, delegate: waiter, delegateQueue: nil)
        let task = session.webSocketTask(with: url)
        let transport = URLSessionFrameTransport(task: task, session: session, waiter: waiter, route: route)
        task.resume()
        do {
            try await withTimeout(ms: timeoutMs) { try await waiter.wait() }
        } catch {
            transport.fail(error.localizedDescription)
            throw error
        }
        return transport
    }
}

func withTimeout<T: Sendable>(ms: Int64, work: @escaping @Sendable () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await work() }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(ms) * 1_000_000)
            throw PocketError(code: "timeout", message: "timed out after \(ms)ms")
        }
        guard let result = try await group.next() else {
            throw PocketError(code: "timeout", message: "timed out after \(ms)ms")
        }
        group.cancelAll()
        return result
    }
}
