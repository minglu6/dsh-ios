#if DEBUG
import Foundation
import CoreFoundation
import DSHProtocol

extension AppModel {
    func installUITestTodoLifecycle() {
        guard uiTestFixture else { return }
        showDrawer = false
        routeStack = []
        receiveUITestTodoFollow(TodoLifecycleFrames.snapshot(), reset: true)
        uiTestTodoLifecycleDriver = UITestTodoLifecycleDriver { [weak self] action in
            Task { @MainActor in
                guard let self, self.uiTestFixture else { return }
                for frame in TodoLifecycleFrames.frames(for: action) {
                    self.receiveUITestTodoFollow(frame)
                }
            }
        }
    }
}

/// Cross-process controls carry no state: every action delivers Host follow frames.
/// Retained by AppModel only for this DEBUG fixture; no production UI is changed.
final class UITestTodoLifecycleDriver: @unchecked Sendable {
    private static let prefix = "dev.dsh.uitest.todoLifecycle."
    private static let actions = ["complete", "projectionNull", "projectionEmpty", "turnStart", "snapshotNull", "resumeNull", "resumeMissing"]
    private let receive: @Sendable (String) -> Void

    init(receive: @escaping @Sendable (String) -> Void) {
        self.receive = receive
        for action in Self.actions {
            CFNotificationCenterAddObserver(
                CFNotificationCenterGetDarwinNotifyCenter(),
                Unmanaged.passUnretained(self).toOpaque(),
                { _, observer, name, _, _ in
                    guard let observer, let name else { return }
                    let driver = Unmanaged<UITestTodoLifecycleDriver>.fromOpaque(observer).takeUnretainedValue()
                    let name = name.rawValue as String
                    driver.receive(String(name.dropFirst(UITestTodoLifecycleDriver.prefix.count)))
                },
                (Self.prefix + action) as CFString,
                nil,
                .deliverImmediately
            )
        }
    }

    deinit {
        CFNotificationCenterRemoveEveryObserver(CFNotificationCenterGetDarwinNotifyCenter(), Unmanaged.passUnretained(self).toOpaque())
    }
}

private enum TodoLifecycleFrames {
    private static let completed: JSONValue = .array([
        .object(["content": .string("保留本轮完成任务"), "status": .string("completed")]),
        .object(["content": .string("历史工具记录仍可查看"), "status": .string("completed")]),
    ])
    private static let arguments = #"{"todos":[{"content":"保留本轮完成任务","status":"completed"},{"content":"历史工具记录仍可查看","status":"completed"}]}"#

    private static var records: [JSONValue] {
        [
            event("turn/start", seq: 1, data: .object(["turn": .number(1)])),
            event("tool/call", seq: 2, data: .object([
                "callId": .string("todo-history"), "name": .string("todo_write"),
                "arguments": .string(arguments), "turn": .number(1), "step": .number(1),
            ])),
            event("todo/write", seq: 3, data: .object(["todos": completed])),
            event("tool/result", seq: 4, data: .object([
                "message": .object([
                    "toolCallId": .string("todo-history"),
                    "content": .array([.object(["type": .string("text"), "text": .string("todo-history-result-retained")])]),
                ]),
            ])),
        ]
    }

    static func snapshot(clear: Bool = false) -> JSONValue {
        .object([
            "type": .string("snapshot"), "cursor": .number(clear ? 10 : 4),
            "hasMore": .bool(false), "records": .array(records + (clear ? completion : [])),
            "projections": .object([
                "asOfSeq": .number(clear ? 10 : 4),
                "values": .object(["todos": clear ? .null : completed]),
            ]),
        ])
    }

    private static var completion: [JSONValue] {
        [
            assistant("本轮任务已完成", seq: 5),
            event("turn/end", seq: 6, data: .object(["turn": .number(1), "reason": .object(["kind": .string("completed")])])),
        ]
    }

    static func frames(for action: String) -> [JSONValue] {
        switch action {
        case "complete": return completion
        case "turnStart": return [event("turn/start", seq: 10, data: .object(["turn": .number(2)]))]
        case "projectionNull", "projectionEmpty":
            return [.object([
                "type": .string("projection"), "key": .string("todos"), "seq": .number(10),
                "value": action == "projectionNull" ? .null : .array([]),
            ])]
        case "snapshotNull": return [snapshot(clear: true)]
        case "resumeNull", "resumeMissing":
            let missing = action == "resumeMissing"
            return [.object([
                "type": .string("resume"), "cursor": .number(10),
                "records": .array(missing ? [assistant("缺失投影仍保留任务", seq: 7)] : []),
                "projections": .object([
                    "asOfSeq": .number(10),
                    "values": .object(missing ? [:] : ["todos": .null]),
                ]),
            ])]
        default:
            preconditionFailure("Unknown todo lifecycle fixture action: \(action)")
        }
    }

    private static func assistant(_ text: String, seq: Int) -> JSONValue {
        event("assistant/message", seq: seq, data: .object([
            "turn": .number(1), "step": .number(1),
            "message": .object([
                "id": .string("todo-answer-\(seq)"),
                "content": .array([.object(["type": .string("text"), "text": .string(text)])]),
            ]),
        ]))
    }

    private static func event(_ type: String, seq: Int, data: JSONValue) -> JSONValue {
        .object([
            "type": .string("event"),
            "event": .object([
                "type": .string(type), "seq": .number(Double(seq)),
                "time": .number(1_700_000_000_000 + Double(seq * 1_000)), "data": data,
            ]),
        ])
    }
}
#endif
