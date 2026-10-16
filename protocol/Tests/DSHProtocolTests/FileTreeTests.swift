import XCTest
@testable import DSHProtocol

final class FileTreeTests: XCTestCase {
    private func entry(_ name: String, _ type: String) -> WorkspaceFileEntry {
        WorkspaceFileEntry(name: name, type: type)
    }

    func testCacheKeyScopesListingToSessionAndCwd() {
        XCTAssertEqual(fileTreeCacheKey(sessionId: "s1", cwd: "/ws"), "s1|/ws")
        XCTAssertEqual(fileTreeCacheKey(sessionId: nil, cwd: nil), "|")
        XCTAssertNotEqual(fileTreeCacheKey(sessionId: "s1", cwd: "/a"), fileTreeCacheKey(sessionId: "s2", cwd: "/a"))
    }

    func testChildPathJoinsWorkspaceRelativeSegments() {
        XCTAssertEqual(fileTreeChildPath(parent: "", name: "src"), "src")
        XCTAssertEqual(fileTreeChildPath(parent: "src", name: "app"), "src/app")
        XCTAssertEqual(fileTreeChildPath(parent: "src/app", name: "main.swift"), "src/app/main.swift")
    }

    func testRootStartsExpandedAndListsChildrenAtDepthZero() {
        var tree = FileTreeState.root
        XCTAssertEqual(tree.expanded, [""])
        fileTreeMarkLoading(&tree, path: "")
        XCTAssertEqual(fileTreeVisibleRows(tree).map(\.kind), [.loading])
        fileTreeApplyListing(
            &tree,
            path: "",
            entries: [
                entry("README.md", "file"),
                entry("src", "directory"),
                entry(".env", "file"),
                entry("pipe", "other"),
            ],
            truncated: false
        )
        let rows = fileTreeVisibleRows(tree)
        XCTAssertEqual(rows.map(\.path), ["src", ".env", "pipe", "README.md"])
        XCTAssertEqual(rows.map(\.depth), [0, 0, 0, 0])
        XCTAssertEqual(rows.map(\.kind), [.directory(expanded: false), .file, .other, .file])
    }

    func testNumericNameOrderMatchesDesktopCollator() {
        let ordered = fileTreeOrderEntries([
            entry("file10.ts", "file"),
            entry("src", "directory"),
            entry("file2.ts", "file"),
            entry("lib", "directory"),
        ])
        XCTAssertEqual(ordered.map(\.name), ["lib", "src", "file2.ts", "file10.ts"])
        let parsed = parseWorkspaceFileEntries(jsonObject([
            "entries": .array([
                jsonObject(["name": .string("file10.ts"), "type": .string("file")]),
                jsonObject(["name": .string("src"), "type": .string("directory")]),
                jsonObject(["name": .string("file2.ts"), "type": .string("file")]),
            ]),
        ]))
        XCTAssertEqual(parsed.map(\.name), ["src", "file2.ts", "file10.ts"])
    }

    func testExpandLoadsChildrenLazilyAndCollapseKeepsCache() {
        var tree = FileTreeState.root
        fileTreeApplyListing(&tree, path: "", entries: [entry("src", "directory")], truncated: false)
        XCTAssertFalse(fileTreeVisibleRows(tree).contains { $0.path == "src/a.ts" })
        fileTreeToggle(&tree, path: "src")
        XCTAssertTrue(tree.expanded.contains("src"))
        XCTAssertEqual(tree.levels["src"], .loading)
        XCTAssertEqual(fileTreeVisibleRows(tree).map(\.kind), [.directory(expanded: true), .loading])

        fileTreeApplyListing(&tree, path: "src", entries: [entry("a.ts", "file")], truncated: false)
        XCTAssertEqual(fileTreeVisibleRows(tree).map(\.path), ["src", "src/a.ts"])
        XCTAssertEqual(fileTreeVisibleRows(tree)[1].depth, 1)

        fileTreeToggle(&tree, path: "src")
        XCTAssertFalse(tree.expanded.contains("src"))
        XCTAssertEqual(fileTreeVisibleRows(tree).map(\.path), ["src"])
        if case .ready(let entries, _, _) = tree.levels["src"] {
            XCTAssertEqual(entries.map(\.name), ["a.ts"])
        } else {
            XCTFail("collapsed directory must keep its listing")
        }

        fileTreeToggle(&tree, path: "src")
        XCTAssertEqual(fileTreeVisibleRows(tree).map(\.path), ["src", "src/a.ts"])
        fileTreeMarkLoading(&tree, path: "src")
        if case .ready = tree.levels["src"] {
            // keep cache while the reopen re-lists
        } else {
            XCTFail("reopen must not flash loading over a ready cache")
        }
    }

    func testRemovedDirectoryDropsExpandedDescendants() {
        var tree = FileTreeState.root
        fileTreeApplyListing(&tree, path: "", entries: [entry("src", "directory")], truncated: false)
        fileTreeToggle(&tree, path: "src")
        fileTreeApplyListing(&tree, path: "src", entries: [entry("nested", "directory")], truncated: false)
        fileTreeToggle(&tree, path: "src/nested")
        fileTreeApplyListing(&tree, path: "src/nested", entries: [entry("a.ts", "file")], truncated: false)
        XCTAssertTrue(tree.expanded.contains("src/nested"))
        fileTreeApplyListing(&tree, path: "", entries: [entry("lib", "directory")], truncated: false)
        XCTAssertFalse(tree.expanded.contains("src"))
        XCTAssertFalse(tree.expanded.contains("src/nested"))
        XCTAssertNil(tree.levels["src"])
        XCTAssertNil(tree.levels["src/nested"])
        XCTAssertEqual(fileTreeVisibleRows(tree).map(\.path), ["lib"])
    }

    func testReadyFailureKeepsEntriesAndNotesEmptyTruncated() {
        var tree = FileTreeState.root
        fileTreeApplyListing(&tree, path: "", entries: [], truncated: true)
        var rows = fileTreeVisibleRows(tree)
        XCTAssertEqual(rows.map(\.kind), [.empty, .truncated])
        fileTreeApplyFailure(&tree, path: "", message: "这个目录不在了。可能已被移动或删除。")
        if case .ready(let entries, let truncated, let failure) = tree.levels[""] {
            XCTAssertTrue(entries.isEmpty)
            XCTAssertTrue(truncated)
            XCTAssertEqual(failure, "这个目录不在了。可能已被移动或删除。")
        } else {
            XCTFail("watch failure after a listing must keep the ready cache")
        }
        fileTreeApplyFailure(&tree, path: "gone", message: "这不是一个目录。")
        XCTAssertEqual(tree.levels["gone"], .failed("这不是一个目录。"))
        rows = fileTreeVisibleRows(FileTreeState(levels: ["": .failed("读取失败：offline")], expanded: [""]))
        XCTAssertEqual(rows.single.kind, .failed)
        XCTAssertEqual(rows.single.message, "读取失败：offline")
    }

    func testRootCannotCollapseAndReloadDropsListingsOnly() {
        var tree = FileTreeState.root
        fileTreeApplyListing(&tree, path: "", entries: [entry("src", "directory")], truncated: false)
        fileTreeToggle(&tree, path: "src")
        fileTreeApplyListing(&tree, path: "src", entries: [entry("a.ts", "file")], truncated: false)
        fileTreeToggle(&tree, path: "")
        XCTAssertTrue(tree.expanded.contains(""))
        fileTreeResetListings(&tree)
        XCTAssertEqual(tree.expanded, ["", "src"])
        XCTAssertTrue(tree.levels.isEmpty)
        XCTAssertEqual(fileTreeVisibleRows(tree).map(\.kind), [.loading])
    }

    func testFailureCopyMatchesDesktopSidebarFiles() {
        XCTAssertEqual(
            filesFailureMessage(error: PocketError(code: "workspace-file/not-found", message: "x"), english: false),
            "这个目录不在了。可能已被移动或删除。"
        )
        XCTAssertEqual(
            filesFailureMessage(error: PocketError(code: "workspace-file/outside-workspace", message: "x"), english: false),
            "这个目录在工作区之外，侧栏不会读取它。"
        )
        XCTAssertEqual(
            filesFailureMessage(error: PocketError(code: "workspace-file/not-directory", message: "x"), english: false),
            "这不是一个目录。"
        )
        XCTAssertFalse(filesFailureMessage(error: PocketError(code: "transport", message: "offline"), english: false).contains("Host"))
        XCTAssertEqual(fileTreeFolderSymbol(expanded: false), "folder")
        XCTAssertEqual(fileTreeFolderSymbol(expanded: true), "folder.fill")
        XCTAssertTrue(directoryWatchShouldReload(initialized: false, automatic: false))
        XCTAssertFalse(directoryWatchShouldReload(initialized: true, automatic: false))
        XCTAssertTrue(directoryWatchShouldReload(initialized: true, automatic: true))
    }
}

private extension Array {
    var single: Element {
        guard count == 1, let first else {
            fatalError("expected one element, got \(count)")
        }
        return first
    }
}
