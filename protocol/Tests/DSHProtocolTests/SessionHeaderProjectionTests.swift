import XCTest
@testable import DSHProtocol

final class SessionHeaderProjectionTests: XCTestCase {
    private func team(_ name: String = "lead", phase: String = "active", failure: String? = nil) -> JSONValue {
        jsonObject([
            "members": .array([jsonObject([
                "id": .string("lead-session"), "name": .string(name),
                "role": .string("lead"), "phase": .string(phase),
            ])]),
            "tasks": .array([]),
            "failure": failure.map(JSONValue.string),
        ])
    }

    private func catalog(_ id: String = "child") -> JSONValue {
        .array([jsonObject([
            "id": .string(id), "label": .string("Research"),
            "mode": .string("continuable"), "createdAt": .number(1234),
        ])])
    }

    private func frame(_ key: String, _ value: JSONValue, _ seq: Int) -> JSONValue {
        .object(["type": .string("projection"), "key": .string(key), "value": value, "seq": .number(Double(seq))])
    }

    private func baseline(_ type: String, _ values: [String: JSONValue], _ seq: Int) -> JSONValue {
        .object([
            "type": .string(type), "cursor": .number(Double(seq)),
            "projections": .object(["asOfSeq": .number(Double(seq)), "values": .object(values)]),
        ])
    }

    func testUnavailableAndEmptyAreDistinct() {
        var store = SessionHeaderProjection()
        XCTAssertNil(store.team)
        XCTAssertNil(store.subagents)
        store.apply(frame: baseline("snapshot", ["agentTeam": .object(["members": .array([]), "tasks": .array([])]), "subagentCatalog": .array([])], 0))
        XCTAssertEqual(store.team?.members, [])
        XCTAssertEqual(store.team?.tasks, [])
        XCTAssertEqual(store.subagents, [])
        store.apply(frame: frame("agentTeam", .null, 1))
        store.apply(frame: frame("subagentCatalog", .null, 1))
        XCTAssertNil(store.team)
        XCTAssertNil(store.subagents)
        XCTAssertTrue(store.errors.isEmpty)
    }

    func testReplayedAndOutOfOrderFramesCannotRegressValues() {
        var store = SessionHeaderProjection()
        store.apply(frame: frame("agentTeam", team("latest"), 8))
        store.apply(frame: frame("agentTeam", team("replay"), 8))
        store.apply(frame: frame("agentTeam", .null, 7))
        store.apply(frame: baseline("resume", ["agentTeam": team("old baseline")], 6))
        XCTAssertEqual(store.team?.members.first?.name, "latest")
        store.apply(frame: frame("agentTeam", team("new"), 9))
        XCTAssertEqual(store.team?.members.first?.name, "new")
    }

    func testEachKeyHasAnIndependentWatermark() {
        var store = SessionHeaderProjection()
        store.apply(frame: frame("agentTeam", team(), 100))
        store.apply(frame: frame("subagentCatalog", catalog(), 2))
        store.apply(frame: baseline("resume", ["agentTeam": team("old"), "subagentCatalog": catalog("second")], 3))
        XCTAssertEqual(store.team?.members.first?.name, "lead")
        XCTAssertEqual(store.subagents?.first?.id, "second")
        XCTAssertEqual(store.subagents?.first?.createdAt, 1234)
    }

    func testBaselineOmissionClearsOnlyValuesNotNewerThanItsCut() {
        var store = SessionHeaderProjection()
        store.apply(frame: frame("agentTeam", team(), 8))
        store.apply(frame: frame("subagentCatalog", catalog(), 3))
        store.apply(frame: baseline("snapshot", [:], 5))
        XCTAssertNotNil(store.team)
        XCTAssertNil(store.subagents)
        store.apply(frame: baseline("resume", [:], 8))
        XCTAssertNil(store.team)
    }

    func testNullRemainsSequencedAndCannotBeReplacedByOlderValues() {
        var store = SessionHeaderProjection()
        store.apply(frame: frame("agentTeam", team(), 2))
        store.apply(frame: frame("agentTeam", .null, 4))
        store.apply(frame: frame("agentTeam", team(), 3))
        XCTAssertNil(store.team)
    }

    func testMissingProjectionOrMalformedFrameDoesNotClearValidData() {
        var store = SessionHeaderProjection()
        store.apply(frame: frame("agentTeam", team(), 2))
        store.apply(frame: .object(["type": .string("snapshot"), "cursor": .number(3)]))
        store.apply(frame: .object(["type": .string("projection"), "key": .string("agentTeam"), "seq": .number(4)]))
        store.apply(frame: frame("unrelated", .null, 5))
        XCTAssertNotNil(store.team)
    }

    func testMalformedValuesRetainLastValidDataAndExposeError() {
        var store = SessionHeaderProjection()
        store.apply(frame: frame("agentTeam", team(), 2))
        store.apply(frame: frame("agentTeam", team("bad", phase: "completed"), 4))
        XCTAssertEqual(store.team?.members.first?.phase, .active)
        XCTAssertNotNil(store.errors["agentTeam"])
        store.apply(frame: frame("agentTeam", team("stale"), 3))
        XCTAssertEqual(store.team?.members.first?.name, "lead")
        XCTAssertNotNil(store.errors["agentTeam"])
        store.apply(frame: frame("agentTeam", team("recovered"), 5))
        XCTAssertNil(store.errors["agentTeam"])
        XCTAssertEqual(store.team?.members.first?.name, "recovered")
    }

    func testFailurePreservesHostProvidedMembersAndTaskSemantics() throws {
        let value = try JSONValue.parse("""
        {"members":[
          {"id":"lead-session","name":"lead","role":"lead","phase":"active"},
          {"id":"failed-child","name":"Reviewer","role":"teammate","phase":"failed","error":"provider unavailable"}
        ],"failure":"invalid persisted record","tasks":[{
          "id":"task-1","revision":3,"subject":"Review changes","description":"Read all affected files",
          "status":"pending","ownerName":"Reviewer","blockedBy":["task-0"],"ready":false,
          "writeScopes":["src/"],"writeScopeWarnings":["Overlapping write scope"]
        }]}
        """)
        var store = SessionHeaderProjection()
        store.apply(frame: frame("agentTeam", value, 3))
        XCTAssertEqual(store.team?.failure, "invalid persisted record")
        XCTAssertEqual(store.team?.members.last?.phase, .failed)
        XCTAssertEqual(store.team?.members.last?.error, "provider unavailable")
        let task = try XCTUnwrap(store.team?.tasks.first)
        XCTAssertEqual(task.revision, 3)
        XCTAssertEqual(task.subject, "Review changes")
        XCTAssertEqual(task.description, "Read all affected files")
        XCTAssertEqual(task.status, .pending)
        XCTAssertEqual(task.ownerName, "Reviewer")
        XCTAssertEqual(task.blockedBy, ["task-0"])
        XCTAssertFalse(task.ready)
        XCTAssertEqual(task.writeScopes, ["src/"])
        XCTAssertEqual(task.writeScopeWarnings, ["Overlapping write scope"])
        XCTAssertTrue(store.errors.isEmpty)
    }

    func testCachedBlocksYieldToSequencedValuesAndBaselineOmissions() {
        var store = SessionHeaderProjection()
        store.apply(frame: .object(["kind": .string("cached"), "values": .object(["agentTeam": team("cached"), "subagentCatalog": catalog()])]))
        XCTAssertEqual(store.team?.members.first?.name, "cached")
        store.apply(frame: .object(["kind": .string("sequenced"), "asOfSeq": .number(-1), "values": .object(["agentTeam": team("live")])]))
        XCTAssertEqual(store.team?.members.first?.name, "live")
        XCTAssertNil(store.subagents)
        store.apply(frame: .object(["kind": .string("cached"), "values": .object(["agentTeam": team("old cache")])]))
        XCTAssertEqual(store.team?.members.first?.name, "live")
    }

    func testCatalogIsNotSynthesizedIntoTeamAndMalformedRowsAreNotDroppedSilently() throws {
        var store = SessionHeaderProjection()
        store.apply(frame: frame("subagentCatalog", catalog(), 1))
        XCTAssertNil(store.team)
        let malformed = try JSONValue.parse("""
        [{"id":"good","createdAt":0,"mode":"one-shot"},{"id":"bad","createdAt":1,"mode":"continuable"}]
        """)
        store.apply(frame: frame("subagentCatalog", malformed, 2))
        XCTAssertEqual(store.subagents?.map(\.id), ["child"])
        XCTAssertNotNil(store.errors["subagentCatalog"])
        let modes = try JSONValue.parse("""
        [{"id":"once","createdAt":0,"mode":"one-shot"},
         {"id":"external","createdAt":1,"mode":"external"},
         {"id":"unknown","createdAt":2,"mode":"unknown"}]
        """)
        store.apply(frame: frame("subagentCatalog", modes, 3))
        XCTAssertEqual(store.subagents?.map(\.mode), ["one-shot", "external", "unknown"])
        XCTAssertNil(store.errors["subagentCatalog"])
    }

    func testBaselineAbsenceWatermarkRejectsLateFrames() {
        var store = SessionHeaderProjection()
        store.apply(frame: frame("agentTeam", team(), 2))
        store.apply(frame: baseline("snapshot", [:], 8))
        store.apply(frame: frame("agentTeam", team("late"), 7))
        store.apply(frame: frame("subagentCatalog", catalog(), 8))
        XCTAssertNil(store.team)
        XCTAssertNil(store.subagents)
        store.apply(frame: frame("agentTeam", team("fresh"), 9))
        XCTAssertEqual(store.team?.members.first?.name, "fresh")
    }

    func testMigrationRequiredRetainsLiveDataAndMarksUnavailable() {
        var store = SessionHeaderProjection()
        store.apply(frame: baseline("snapshot", ["agentTeam": team("live"), "subagentCatalog": catalog()], 8))
        store.apply(frame: .object([
            "kind": .string("migration-required"),
            "values": .object(["agentTeam": team("old checkpoint"), "subagentCatalog": .array([])]),
        ]))
        XCTAssertEqual(store.team?.members.first?.name, "live")
        XCTAssertEqual(store.subagents?.first?.id, "child")
        XCTAssertNotNil(store.errors["agentTeam"])
        XCTAssertNotNil(store.errors["subagentCatalog"])
        store.apply(frame: frame("agentTeam", team("stale"), 7))
        XCTAssertEqual(store.team?.members.first?.name, "live")
        store.apply(frame: baseline("resume", ["agentTeam": team("recovered"), "subagentCatalog": .array([])], 9))
        XCTAssertTrue(store.errors.isEmpty)
        XCTAssertEqual(store.team?.members.first?.name, "recovered")
    }

    func testNullQueryResultClearsDataWithoutInventingEmptyValues() {
        var store = SessionHeaderProjection()
        store.apply(frame: baseline("snapshot", ["agentTeam": team(), "subagentCatalog": catalog()], 8))
        store.apply(frame: .null)
        XCTAssertNil(store.team)
        XCTAssertNil(store.subagents)
        XCTAssertNotNil(store.errors["agentTeam"])
        XCTAssertNotNil(store.errors["subagentCatalog"])
        store.apply(frame: frame("agentTeam", team("stale"), 7))
        XCTAssertNil(store.team)
        store.apply(frame: frame("agentTeam", team("new"), 9))
        XCTAssertEqual(store.team?.members.first?.name, "new")
        XCTAssertNil(store.errors["agentTeam"])
    }

    func testInvalidTaskStatusDoesNotBecomeCompleted() throws {
        var store = SessionHeaderProjection()
        let invalid = try JSONValue.parse("""
        {"members":[],"tasks":[{"id":"task-1","revision":1,"subject":"Task","description":"Details",
        "status":"failed","blockedBy":[],"writeScopes":[],"ready":false,"writeScopeWarnings":[]}]}
        """)
        store.apply(frame: frame("agentTeam", invalid, 1))
        XCTAssertNil(store.team)
        XCTAssertNotNil(store.errors["agentTeam"])
    }
}
