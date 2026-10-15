import Foundation

public func requireSettingsSuccess(_ result: JSONValue) throws {
    if result["ok"].bool() == false || result["application"].str() == "failed" {
        throw PocketError(
            code: result["error"]["code"].str() ?? "error",
            message: result["error"]["message"].str() ?? result["message"].str() ?? "unavailable"
        )
    }
}

public func settingsFailure(_ error: Error, secret: String = "") -> String {
    let message = (error as? PocketError)?.message ?? error.localizedDescription
    if secret.isEmpty { return message }
    return message.replacingOccurrences(of: secret, with: "••••••")
}

public func settingsPathValue(_ root: JSONValue, _ path: [String]) -> JSONValue {
    path.reduce(root) { $0[$1] }
}
