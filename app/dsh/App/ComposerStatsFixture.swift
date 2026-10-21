import Foundation
import DSHProtocol

extension AppModel {
    func installUITestComposerStats(_ screen: String) {
        guard uiTestFixture, chat != nil else { return }
        hostSettings.installUITestFixture(performanceUsage: screen == "statsCompact" ? .compact : .detailed)
        var activity: [String: JSONValue] = [
            "turns": .number(3), "steps": .number(6),
            "llmMs": .number(32_500), "toolMs": .number(4_300),
            "ttftMs": .number(5_400), "ttftSteps": .number(6),
            "decodeMs": .number(20_000), "decodeTokens": .number(5_080),
        ]
        var values: [String: JSONValue] = [
            "tokenUsage": .object([
                "uncachedInputTokens": .number(38_903),
                "cacheReadTokens": .number(456_192),
                "cacheWriteTokens": .number(screen == "statsCacheWrite" ? 1_300 : 0),
                "outputTokens": .number(5_711),
            ]),
            "contextPressure": .object([
                "projectedTokens": .number(54_700), "contextWindow": .number(1_048_576),
            ]),
            "contextBreakdown": .object([
                "systemTokens": .number(1_024), "toolsTokens": .number(15_000),
                "messageTokens": .number(38_676),
            ]),
        ]
        if screen == "statsUntimed" {
            for key in ["llmMs", "toolMs", "ttftMs", "ttftSteps", "decodeMs", "decodeTokens"] {
                activity[key] = .number(0)
            }
            values = [:]
        } else if screen == "statsNoSpeed" {
            activity["decodeMs"] = .number(0)
            activity["decodeTokens"] = .number(0)
        } else if screen == "statsOutputOnly" {
            values["tokenUsage"] = .object([
                "uncachedInputTokens": .number(0), "cacheReadTokens": .number(0),
                "cacheWriteTokens": .number(0), "outputTokens": .number(500),
            ])
        }
        values["sessionStats"] = .object(activity)
        if screen == "statsMissing" { values = [:] }
        let reducer = TranscriptReducer()
        reducer.apply(.object([
            "type": .string("snapshot"), "cursor": .number(1), "records": .array([]),
            "projections": .object(["asOfSeq": .number(1), "values": .object(values)]),
        ]))
        chat?.composerMetrics = reducer.composerMetrics
    }
}
