import Foundation
import DSHProtocol

extension AppModel {
    /// One long turn exercises row-level laziness rather than only lazy turn groups.
    /// Synthetic content deliberately keeps the only search hit beyond the preview.
    func seedUITestLargeTrajectory() {
        guard uiTestFixture, var state = chat else { return }
        let clock: Int64 = 1_700_000_000_000
        let body = String(repeating: "Synthetic observation: retain every source paragraph and tool result.\n", count: 160)
        var items: [Item] = [
            .user(Item.User(key: "trajectory-large-user", text: "分析完整长轨迹", at: clock))
        ]
        var steps: [StepRecord] = []
        for step in 1...128 {
            let seq = Int64(step * 3)
            let at = clock + Int64(step) * 1_000
            let callId = "trajectory-call-\(step)"
            let reply = "第 \(step) 步分析\n" + body
                + (step == 128 ? "trajectory-final-needle" : "step-\(step)-complete")
            items.append(.text(Item.Text(
                key: "a\(seq)", text: reply, live: false,
                at: at + 400, seq: seq, turn: 1, step: step
            )))
            items.append(.tool(Item.Tool(
                key: "trajectory-tool-\(step)", callId: callId,
                name: "read", arguments: "{\"path\":\"synthetic/section-\(step).txt\"}",
                status: .ok, result: body,
                startedAt: at + 500, endedAt: at + 800, turn: 1, step: step
            )))
            steps.append(StepRecord(
                seq: seq, turn: 1, step: step,
                stepStartTime: at, messageTime: at + 400, firstTokenTime: at + 50,
                replyText: reply, provider: "synthetic", model: "trajectory-fixture",
                toolCallIds: [callId],
                requestConfigJson: #"{"maxTokens":4096,"temperature":0.2}"#
            ))
        }
        state.items = items
        state.steps = steps
        state.title = "长轨迹回归"
        state.loaded = true
        state.running = false
        state.hasMore = false
        state.loadingOlder = false
        chat = state
    }
}
