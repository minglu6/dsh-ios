import SwiftUI

/// Restore the same record after a prepend, only while its session remains active.
struct HistoryScrollAnchor: Equatable {
    let sessionId: String
    let rowKey: String
    var point: UnitPoint = .top
}
