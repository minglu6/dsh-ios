import Foundation

/// Transcript image bubbles. Port of Android `session.attachment` + ImageBubble decode.
public enum SessionAttachment {
    public static let previewMaxDimension = 660

    public static func args(sessionId: String, attachmentId: String) -> JSONValue {
        jsonObject([
            "sessionId": .string(sessionId),
            "attachmentId": .string(attachmentId),
        ])
    }

    public static func decodeBytes(_ result: JSONValue) -> Data? {
        guard let encoded = result["data"].str(), !encoded.isEmpty else { return nil }
        return Data(base64Encoded: encoded)
    }

    public static func sampleSize(width: Int, height: Int, maxDimension: Int = previewMaxDimension) -> Int {
        var sample = 1
        var largest = max(width, height)
        while largest / sample > maxDimension { sample *= 2 }
        return sample
    }
}
