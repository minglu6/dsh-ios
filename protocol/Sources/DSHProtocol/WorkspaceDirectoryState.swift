import Foundation

/// A completed frame owns both panes and the commit target; draft text never becomes a target.
public final class WorkspaceDirectoryState: @unchecked Sendable {
    public var parent: WorkspaceDirectoryLevel?
    public var child: WorkspaceDirectoryLevel?
    public var selected: WorkspaceDirectoryEntry?
    public var draft: String?
    public var loading = false
    public var error: String?
    public var showHidden = false
    public var onChange: (@Sendable () -> Void)?

    private let list: (String?) async throws -> WorkspaceDirectoryLevel
    private var scan: Task<Void, Never>?
    private var scannedDirectory: (String, String)?
    private var generation = 0

    public init(list: @escaping (String?) async throws -> WorkspaceDirectoryLevel) {
        self.list = list
    }

    private var level: WorkspaceDirectoryLevel? { child ?? parent }
    public var target: String? { selected?.path ?? parent?.path }
    public var crumbs: [WorkspaceDirectoryEntry] { level?.displayCrumbs() ?? [] }

    private func supersede() {
        generation += 1
        scan?.cancel()
        scan = nil
        loading = false
        notify()
    }

    private func notify() { onChange?() }

    public func navigate(path: String? = nil, base: WorkspaceDirectoryLevel? = nil) async {
        supersede()
        let epoch = generation
        loading = true
        error = nil
        notify()
        do {
            try await land(path: path, base: base, preview: false, epoch: epoch)
            if epoch == generation { draft = nil }
        } catch is CancellationError {
            return
        } catch {
            if epoch == generation {
                self.error = error.localizedDescription
                notify()
            }
        }
        if epoch == generation {
            loading = false
            notify()
        }
    }

    public func beginEdit() {
        supersede()
        error = nil
        draft = level?.directory
        notify()
    }

    public func edit(_ value: String) {
        if draft == nil || value == draft { return }
        supersede()
        draft = value
        error = nil
        notify()
        guard let current = level, let directory = directoryPart(current, value) else { return }
        if answers(current, directory) { return }
        let epoch = generation
        scan = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard let self, !Task.isCancelled, epoch == self.generation else { return }
            self.loading = true
            do {
                try await self.land(path: directory, base: nil, preview: true, epoch: epoch)
            } catch is CancellationError {
                return
            } catch {
                // An incomplete path leaves the last readable frame intact.
            }
            if epoch == self.generation {
                self.loading = false
                self.notify()
            }
        }
    }

    public func cancelEdit() async {
        supersede()
        draft = nil
        error = nil
        notify()
        if parent == nil { await navigate() }
    }

    public func visibleEntries(_ level: WorkspaceDirectoryLevel) -> [WorkspaceDirectoryEntry] {
        let directory = draft.flatMap { directoryPart(level, $0) }
        let prefix: String
        if level.path == self.level?.path, let directory, answers(level, directory), let draft {
            prefix = String(draft.dropFirst(directory.count))
        } else {
            prefix = ""
        }
        func matches(_ entry: WorkspaceDirectoryEntry) -> Bool {
            (showHidden || !entry.hidden || prefix.hasPrefix("."))
                && entry.name.lowercased().hasPrefix(prefix.lowercased())
        }
        let narrow = !prefix.isEmpty && level.entries.contains(where: matches)
        return level.entries.filter { entry in
            entry.path == selected?.path || (narrow ? matches(entry) : showHidden || !entry.hidden)
        }
    }

    public func dispose() { supersede() }

    private func land(path: String?, base: WorkspaceDirectoryLevel?, preview: Bool, epoch: Int) async throws {
        let next = try await list(path)
        try Task.checkCancellation()
        guard epoch == generation else { throw CancellationError() }
        let ancestorPath = next.path == next.home ? nil : next.crumbs.dropLast().last?.path
        let ancestorTask: Task<WorkspaceDirectoryLevel, Error>? = ancestorPath.map { ancestorPath in
            Task {
                if let base, base.path == ancestorPath { return base }
                return try await self.list(ancestorPath)
            }
        }
        func commit(_ previous: WorkspaceDirectoryLevel?) {
            let entry = previous?.entries.first { $0.path == next.path }
            parent = entry != nil ? previous : next
            selected = entry
            child = entry != nil ? next : nil
            if preview, let path { scannedDirectory = (path, next.path) }
            notify()
        }
        var previous: WorkspaceDirectoryLevel?
        if let ancestorTask {
            if preview {
                previous = try? await ancestorTask.value
            } else {
                previous = await withTimeoutOrNil(ms: 200) { try await ancestorTask.value }
            }
        }
        try Task.checkCancellation()
        guard epoch == generation else { throw CancellationError() }
        commit(previous)
        loading = false
        if !preview { draft = nil }
        notify()
        if previous == nil, let ancestorTask {
            if let late = try? await ancestorTask.value {
                try Task.checkCancellation()
                guard epoch == generation else { throw CancellationError() }
                commit(late)
            }
        }
    }

    private func answers(_ level: WorkspaceDirectoryLevel, _ directory: String) -> Bool {
        directory == level.directory || (scannedDirectory?.0 == directory && scannedDirectory?.1 == level.path)
    }

    private func directoryPart(_ level: WorkspaceDirectoryLevel, _ value: String) -> String? {
        let cut: String.Index?
        if level.separator == "\\" {
            let back = value.lastIndex(of: "\\")
            let fwd = value.lastIndex(of: "/")
            if let back, let fwd { cut = max(back, fwd) }
            else { cut = back ?? fwd }
        } else {
            cut = value.lastIndex(of: "/")
        }
        guard let cut else { return nil }
        return String(value[...cut])
    }
}

private func withTimeoutOrNil<T: Sendable>(ms: Int64, work: @escaping @Sendable () async throws -> T) async -> T? {
    await withTaskGroup(of: T?.self) { group in
        group.addTask { try? await work() }
        group.addTask {
            try? await Task.sleep(nanoseconds: UInt64(ms) * 1_000_000)
            return nil
        }
        let first = await group.next() ?? nil
        group.cancelAll()
        return first
    }
}
