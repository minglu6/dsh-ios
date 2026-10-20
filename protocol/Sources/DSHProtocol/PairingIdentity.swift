import Foundation

/// Names used when pairing a phone to a remote host.
///
/// Plugin `pair` writes `args.name` once via `devices.add` (`plugin/src/devices.js`).
/// Reconnect `hello` authenticates the token and does not update that stored name.
/// Desktop「重命名」is `PATCH /pocket/devices`. Phone `renameProfile` is local only.
public struct PairingNames: Sendable, Equatable {
    /// Phone identity sent as pair `args.name` (desktop「已配对设备」).
    public var clientDeviceName: String
    /// Local remark for the remote host; stored only on the phone.
    public var localHostRemark: String

    public init(clientDeviceName: String, localHostRemark: String) {
        self.clientDeviceName = clientDeviceName
        self.localHostRemark = localHostRemark
    }

    /// Pair handshake identity. Always the phone, never `localHostRemark`.
    public func pairAuth(code: String) -> Auth {
        .pair(code: code, deviceName: clientDeviceName)
    }
}

/// Trim + truncate to 64 chars like plugin `devices.js` / `PATCH /pocket/devices`.
public func clipProfileName(_ name: String) throws -> String {
    let trimmed = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(64))
    if trimmed.isEmpty { throw PocketError(code: "bad-request", message: "profile name required") }
    return trimmed
}

/// Split the phone's pairing identity from the local remote-host remark.
///
/// Android `Pocket.pairHost` sends `Auth.Pair(code, Build.MODEL ?: "Android")` and
/// stores `name.ifBlank { host }` only on the phone. The two values must stay
/// independent: the remark must never become pair `args.name`.
public func pairingNames(hostRemark: String, host: String, clientDeviceName: String) throws -> PairingNames {
    let phone = try clipProfileName(clientDeviceName)
    let remarkSource = hostRemark.trimmingCharacters(in: .whitespacesAndNewlines)
    let remark = try clipProfileName(remarkSource.isEmpty ? host : remarkSource)
    return PairingNames(clientDeviceName: phone, localHostRemark: remark)
}

/// hello / pair handshake body. `pair.args.name` is the phone, never the host remark.
public func pocketHandshake(auth: Auth, appVersion: String) -> (op: String, args: JSONValue) {
    switch auth {
    case .token(let token):
        return ("hello", jsonObject([
            "proto": .number(Double(VersionCompatibility.proto)),
            "token": .string(token),
            "app": .string("dsh-ios"),
            "appVersion": .string(appVersion),
        ]))
    case .pair(let code, let name):
        return ("pair", jsonObject([
            "proto": .number(Double(VersionCompatibility.proto)),
            "code": .string(code),
            "name": .string(name),
            "app": .string("dsh-ios"),
            "appVersion": .string(appVersion),
        ]))
    }
}
