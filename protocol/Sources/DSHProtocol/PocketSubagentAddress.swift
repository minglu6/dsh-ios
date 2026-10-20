import Foundation

/// A child session is addressed through its parent, not masqueraded as a root session.
public struct PocketSubagentAddress: Sendable, Equatable {
    public let parentSessionId: String
    public let mode: String

    public init(parentSessionId: String, mode: String) {
        self.parentSessionId = parentSessionId
        self.mode = mode
    }

    public var isReadOnly: Bool { mode != "continuable" }
}
