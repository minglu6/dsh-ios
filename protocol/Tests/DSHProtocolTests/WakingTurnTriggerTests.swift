import XCTest
@testable import DSHProtocol

/// Desktop `ui-chat` `inbox.ts` `applySplice` + `message.ts` start (compiled
/// `client.js` ~10360–10491). One table: claim replacement, idle steer, Host
/// injections, unclaimed jobs, missing step, canceled splices.
final class WakingTurnTriggerTests: XCTestCase {
    func testDesktopWakingAndTriggerRowTable() {
        let rows: [WakingRow] = [
            WakingRow(
                name: "claimed next-turn message",
                splices: [
                    .claim(target: .nextTurn, id: "m-wake", kind: "tool-jobs", seq: 2),
                ],
                sourceKind: "tool-jobs",
                messageId: "m-wake",
                waking: true
            ),
            WakingRow(
                name: "idle steer (step 1, claimSeq > turnStart, claimedHuman false)",
                splices: [
                    .claim(target: .nextStep, id: "steer", kind: "tool-jobs", seq: 8),
                ],
                sourceKind: "tool-jobs",
                messageId: "steer",
                openStep: 1,
                openTurn: 1,
                turnStartSeq: 5,
                waking: true
            ),
            WakingRow(
                name: "idle steer rejected when claimedHuman",
                splices: [
                    .claim(
                        target: .nextStep,
                        ids: [("steer", "tool-jobs"), ("human", "user")],
                        seq: 8
                    ),
                ],
                sourceKind: "tool-jobs",
                messageId: "steer",
                openStep: 1,
                openTurn: 1,
                turnStartSeq: 5,
                waking: false
            ),
            WakingRow(
                name: "idle steer rejected on later step",
                splices: [
                    .claim(target: .nextStep, id: "steer", kind: "tool-jobs", seq: 8),
                ],
                sourceKind: "tool-jobs",
                messageId: "steer",
                openStep: 2,
                openTurn: 1,
                turnStartSeq: 5,
                waking: false
            ),
            WakingRow(
                name: "idle steer rejected when claim precedes turn/start",
                splices: [
                    .claim(target: .nextStep, id: "steer", kind: "tool-jobs", seq: 3),
                ],
                sourceKind: "tool-jobs",
                messageId: "steer",
                openStep: 1,
                openTurn: 1,
                turnStartSeq: 5,
                waking: false
            ),
            WakingRow(
                name: "Host-injected skill-catalog stays hidden",
                sourceKind: "skill-catalog",
                messageId: "m-skills",
                openStep: 1,
                openTurn: 1,
                turnStartSeq: 5,
                waking: false
            ),
            WakingRow(
                name: "Host-injected time-context stays hidden",
                sourceKind: "time-context",
                messageId: "m-time",
                openStep: 1,
                openTurn: 1,
                turnStartSeq: 5,
                waking: false
            ),
            WakingRow(
                name: "unclaimed tool-jobs stays hidden",
                sourceKind: "tool-jobs",
                messageId: "m-extra",
                openStep: 1,
                openTurn: 1,
                turnStartSeq: 5,
                waking: false
            ),
            WakingRow(
                name: "unclaimed tool-jobs while another id is claimed",
                splices: [
                    .claim(target: .nextTurn, id: "m1", kind: "tool-jobs", seq: 2),
                ],
                sourceKind: "tool-jobs",
                messageId: "m3",
                waking: false
            ),
            WakingRow(
                name: "repeated claim replaces previous (first id no longer waking)",
                splices: [
                    .claim(target: .nextTurn, id: "m1", kind: "tool-jobs", seq: 2),
                    .claim(target: .nextTurn, id: "m2", kind: "tool-jobs", seq: 4),
                ],
                sourceKind: "tool-jobs",
                messageId: "m1",
                waking: false
            ),
            WakingRow(
                name: "repeated claim replaces previous (second id wakes)",
                splices: [
                    .claim(target: .nextTurn, id: "m1", kind: "tool-jobs", seq: 2),
                    .claim(target: .nextTurn, id: "m2", kind: "tool-jobs", seq: 4),
                ],
                sourceKind: "tool-jobs",
                messageId: "m2",
                waking: true
            ),
            WakingRow(
                name: "turn with no step is not idle steer",
                splices: [
                    .claim(target: .nextStep, id: "steer", kind: "tool-jobs", seq: 8),
                ],
                sourceKind: "tool-jobs",
                messageId: "steer",
                openStep: nil,
                openTurn: 1,
                turnStartSeq: 5,
                waking: false
            ),
            WakingRow(
                name: "next-turn claim still wakes when the open turn has no step",
                splices: [
                    .claim(target: .nextTurn, id: "m-wake", kind: "tool-jobs", seq: 2),
                ],
                sourceKind: "tool-jobs",
                messageId: "m-wake",
                openStep: nil,
                openTurn: 1,
                turnStartSeq: 5,
                waking: true
            ),
            WakingRow(
                name: "canceled splice never claims",
                splices: [
                    .claim(
                        target: .nextTurn,
                        id: "m-cancel",
                        kind: "tool-jobs",
                        outcome: "canceled",
                        seq: 3
                    ),
                ],
                sourceKind: "tool-jobs",
                messageId: "m-cancel",
                waking: false
            ),
            WakingRow(
                name: "canceled splice keeps the previous claim",
                splices: [
                    .claim(target: .nextTurn, id: "m1", kind: "tool-jobs", seq: 2),
                    .claim(
                        target: .nextTurn,
                        id: "m9",
                        kind: "tool-jobs",
                        outcome: "canceled",
                        seq: 3
                    ),
                ],
                sourceKind: "tool-jobs",
                messageId: "m1",
                waking: true
            ),
            WakingRow(
                name: "canceled splice does not add the canceled id",
                splices: [
                    .claim(target: .nextTurn, id: "m1", kind: "tool-jobs", seq: 2),
                    .claim(
                        target: .nextTurn,
                        id: "m9",
                        kind: "tool-jobs",
                        outcome: "canceled",
                        seq: 3
                    ),
                ],
                sourceKind: "tool-jobs",
                messageId: "m9",
                waking: false
            ),
            WakingRow(
                name: "requeued claim drops the id from currentClaimed",
                splices: [
                    .claim(target: .nextTurn, id: "notice", kind: "schedule", seq: 3),
                    InboxSpliceFixture(
                        target: .nextTurn,
                        removed: [],
                        insertedIds: ["notice"],
                        seq: 4
                    ),
                ],
                sourceKind: "schedule",
                messageId: "notice",
                openStep: 1,
                openTurn: 1,
                turnStartSeq: 2,
                waking: false
            ),
            WakingRow(
                name: "user source never becomes a turn-trigger",
                splices: [
                    .claim(target: .nextTurn, id: "u1", kind: "user", seq: 2),
                ],
                sourceKind: "user",
                messageId: "u1",
                waking: false
            ),
        ]

        XCTAssertEqual(
            Set(rows.map(\.name)).count,
            rows.count,
            "waking table names must be unique"
        )

        for row in rows {
            let (nextTurn, nextStep) = applySplices(row.splices)
            let step = wakingTriggerStep(openStep: row.openStep, openTurn: row.openTurn)
            let waking = isWakingTurnTrigger(
                sourceKind: row.sourceKind,
                messageId: row.messageId,
                nextTurn: nextTurn,
                nextStep: nextStep,
                step: step,
                turnStartSeq: row.turnStartSeq
            )
            XCTAssertEqual(waking, row.waking, row.name)

            let item = Item.Context(
                key: row.messageId ?? row.name,
                text: row.name,
                sourceKind: row.sourceKind,
                messageId: row.messageId,
                waking: waking
            )
            let folded = foldChatItems(
                [.context(item)],
                policy: presentationPolicyFor(.detailed),
                sessionRunning: false
            )
            let showsTrigger = folded.contains { chatRow in
                if case .turnTrigger = chatRow { return true }
                return false
            }
            XCTAssertEqual(showsTrigger, row.waking && row.sourceKind != "user", row.name)
        }
    }
}

private enum InboxTarget {
    case nextTurn
    case nextStep
}

private struct InboxSpliceFixture {
    var target: InboxTarget
    var removed: [InboxClaimIdentity]
    var insertedIds: [String] = []
    var outcome: String?
    var seq: Int64

    static func claim(
        target: InboxTarget,
        id: String,
        kind: String,
        outcome: String? = nil,
        seq: Int64
    ) -> InboxSpliceFixture {
        claim(target: target, ids: [(id, kind)], outcome: outcome, seq: seq)
    }

    static func claim(
        target: InboxTarget,
        ids: [(String, String)],
        outcome: String? = nil,
        seq: Int64
    ) -> InboxSpliceFixture {
        InboxSpliceFixture(
            target: target,
            removed: ids.map { InboxClaimIdentity(id: $0.0, sourceKind: $0.1) },
            outcome: outcome,
            seq: seq
        )
    }
}

private struct WakingRow {
    var name: String
    var splices: [InboxSpliceFixture] = []
    var sourceKind: String?
    var messageId: String?
    var openStep: Int?
    var openTurn: Int?
    var turnStartSeq: Int64?
    var waking: Bool
}

private func applySplices(_ splices: [InboxSpliceFixture]) -> (InboxClaimState, InboxClaimState) {
    var nextTurn = InboxClaimState.empty
    var nextStep = InboxClaimState.empty
    for splice in splices {
        let applied = applyInboxClaim(
            previous: splice.target == .nextTurn ? nextTurn : nextStep,
            removed: splice.removed,
            insertedIds: splice.insertedIds,
            outcome: splice.outcome,
            seq: splice.seq
        )
        switch splice.target {
        case .nextTurn: nextTurn = applied
        case .nextStep: nextStep = applied
        }
    }
    return (nextTurn, nextStep)
}
