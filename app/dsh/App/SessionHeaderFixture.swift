import Foundation
import DSHProtocol

extension AppModel {
    func seedUITestSessionHeader() {
        guard uiTestFixture, let id = chat?.sessionId else { return }
        chat?.agentPreset = "standard"
        chat?.loaded = true
        draftPreset = "cordis"
        ops.insert("sessions.projections")
        let children: [JSONValue] = (1...6).map { index in
            jsonObject([
                "id": .string("header-child-\(index)"),
                "label": .string("Worker \(index)"),
                "mode": .string(index == 6 ? "one-shot" : "continuable"),
                "createdAt": .number(Double(index)),
            ])
        }
        let team = jsonObject([
            "members": .array([
                jsonObject(["id": .string(id), "name": .string("Lead"), "role": .string("lead"), "phase": .string("active")]),
                jsonObject(["id": .string("header-child-1"), "name": .string("Worker 1"), "role": .string("teammate"), "phase": .string("active")]),
            ]),
            "tasks": .array([
                jsonObject([
                    "id": .string("task-1"), "revision": .number(1),
                    "subject": .string("Review session header"),
                    "description": .string("Keep the Team roster separate from the subagent catalog and preserve session navigation."),
                    "status": .string("in_progress"), "ownerName": .string("Worker 1"),
                    "blockedBy": .array([]), "writeScopes": .array([.string("app/dsh/Features/Chat")]),
                    "ready": .bool(false), "writeScopeWarnings": .array([]),
                ]),
            ]),
        ])
        var projection = SessionHeaderProjection()
        projection.apply(frame: jsonObject([
            "kind": .string("sequenced"), "asOfSeq": .number(100),
            "values": jsonObject(["agentTeam": team, "subagentCatalog": .array(children)]),
        ]))
        headerProjections[id] = projection
        sessions.append(SessionSummary(
            sessionId: "header-child-1", title: "Worker 1", running: true,
            parentSessionId: id, origin: "subagent"
        ))
        sessions.append(SessionSummary(
            sessionId: "ordinary-fork", title: "Not a subagent", parentSessionId: id, origin: "fork"
        ))
    }
}
