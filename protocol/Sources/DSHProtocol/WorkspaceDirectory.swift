import Foundation

/// Read after watch-ready so changes during the initial listing cannot be missed.
public func observeWorkspaceDirectory(
    list: (String?) async throws -> JSONValue,
    changes: AsyncThrowingStream<JSONValue, Error>?,
    onListing: (JSONValue) -> Void,
    onFailure: (Error) -> Void
) async throws {
    var watchedPath: String?
    func reload() async throws {
        do {
            let result = try await list(watchedPath)
            try Task.checkCancellation()
            onListing(result)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            try Task.checkCancellation()
            onFailure(error)
        }
    }
    guard let changes else {
        try await reload()
        return
    }
    var listed = false
    do {
        for try await frame in changes {
            if frame["kind"].str() == "ready" || frame["kind"].str() == "change" {
                watchedPath = frame["path"].str() ?? watchedPath
                try await reload()
                listed = true
            }
        }
    } catch is CancellationError {
        throw CancellationError()
    } catch {
        try Task.checkCancellation()
        if !listed { try await reload() }
        try Task.checkCancellation()
        if (error as? PocketError)?.code != "workspace-file/watch-unsupported" {
            onFailure(error)
        }
    }
}
