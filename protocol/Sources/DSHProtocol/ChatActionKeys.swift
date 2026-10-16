import Foundation

/// Precomputed chat-action coordinates so each row is O(1) instead of scanning the transcript.
public enum ChatActionKeys {
    /// Last committed assistant text key per turn (live streams and blank replies excluded).
    public static func lastCommittedAnswerKeys(_ items: [Item]) -> [Int: String] {
        var keys: [Int: String] = [:]
        for item in items {
            if case .text(let text) = item, let turn = text.turn, isCommittedAnswer(text) {
                keys[turn] = text.key
            }
        }
        return keys
    }
}
