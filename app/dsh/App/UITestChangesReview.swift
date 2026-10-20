import DSHProtocol

extension AppModel {
    /// Deterministic UI-only comparisons; never used by a connected Host.
    func seedUITestChangesReview(retry: Bool) {
        let files = [
            WorkspaceChangedFile(path: "src/edited.swift", display: "src/edited.swift", added: 1, deleted: 1),
            WorkspaceChangedFile(path: "new.txt", display: "new.txt", added: 1, deleted: 0),
            WorkspaceChangedFile(path: "deleted.txt", display: "deleted.txt", added: 0, deleted: 1),
            WorkspaceChangedFile(path: "image.png", display: "image.png", added: 0, deleted: 0, binary: true),
            WorkspaceChangedFile(path: "huge.log", display: "huge.log", added: 0, deleted: 0, oversized: true),
            WorkspaceChangedFile(path: "empty.txt", display: "empty.txt", added: 0, deleted: 0),
            WorkspaceChangedFile(path: "expired.txt", display: "expired.txt", added: 1, deleted: 0),
            WorkspaceChangedFile(path: "long.txt", display: "long.txt", added: 5001, deleted: 0),
        ]
        uiTestChangesSummary = WorkspaceChangesSummary(
            turn: 1, cwd: "/Users/dev/dsh-ios", files: files, total: files.count, added: 5004, deleted: 2
        )
        uiTestChangesDiffs = [
            0: WorkspaceFileDiff(kind: "text", path: files[0].path, display: files[0].display,
                hunks: [WorkspaceDiffHunk(oldStart: 7, newStart: 7, lines: [
                    " context", "-previousValue", "+replacementValue " + String(repeating: "wrapped source text ", count: 12),
                ])]),
            1: WorkspaceFileDiff(kind: "text", path: files[1].path, display: files[1].display, before: false,
                hunks: [WorkspaceDiffHunk(oldStart: 0, newStart: 1, lines: ["+new-file-content"])]),
            2: WorkspaceFileDiff(kind: "text", path: files[2].path, display: files[2].display, after: false,
                hunks: [WorkspaceDiffHunk(oldStart: 1, newStart: 0, lines: ["-deleted-file-content"])]),
            3: WorkspaceFileDiff(kind: "binary", path: files[3].path, display: files[3].display),
            4: WorkspaceFileDiff(kind: "oversized", path: files[4].path, display: files[4].display),
            5: WorkspaceFileDiff(kind: "text", path: files[5].path, display: files[5].display),
            7: WorkspaceFileDiff(kind: "text", path: files[7].path, display: files[7].display, before: false,
                hunks: [WorkspaceDiffHunk(oldStart: 0, newStart: 1, lines: (1...5001).map { "+line-\($0)" })]),
        ]
        uiTestChangesSummaryFailures = retry ? 1 : 0
        uiTestChangesDiffFailures = retry ? [1] : []
    }
}
