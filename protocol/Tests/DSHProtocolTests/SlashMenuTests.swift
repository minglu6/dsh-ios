import XCTest
@testable import DSHProtocol

final class SlashMenuTests: XCTestCase {
    private func json(_ text: String) throws -> JSONValue { try JSONValue.parse(text) }

    private func command(_ name: String, client: String? = nil) throws -> JSONValue {
        if let client {
            return try json(#"{"name":"\#(name)","client":"\#(client)"}"#)
        }
        return try json(#"{"name":"\#(name)"}"#)
    }

    func testEmptyQueryKeepsAddCommandsSkillsGroups() throws {
        let commands = try [
            command("export"),
            command("feedback"),
            command("compact"),
            command("goal"),
            command("plan"),
            command("permission"),
            command("deploy"),
            command("file", client: "file"),
            command("model", client: "model"),
        ]
        let skills = [
            SkillEntry(name: "agent-browser", description: "Drive a browser", modelInvocable: true),
            SkillEntry(name: "local-notes", description: "Private notes", modelInvocable: false),
        ]
        let rows = commandMenuDisplayRows(commands: commands, skills: skills, query: "", leading: true, english: false)
        XCTAssertEqual(
            rows.compactMap { row -> String? in
                switch row {
                case .section(let title): return title
                case .command(let command): return command["name"].str()
                case .skill(let skill): return skill.name
                }
            },
            ["添加", "file", "goal", "plan", "feedback", "指令", "compact", "permission", "model", "export", "deploy", "技能", "agent-browser", "local-notes"]
        )
        XCTAssertEqual(commandMenuSectionTitle("add", english: false), "添加")
        XCTAssertEqual(commandMenuSectionTitle("commands", english: false), "指令")
        XCTAssertEqual(commandMenuSectionTitle("skills", english: false), "技能")
        XCTAssertEqual(commandMenuSectionTitle("add", english: true), "Add")
        XCTAssertEqual(commandMenuSectionTitle("commands", english: true), "Commands")
        XCTAssertEqual(commandMenuSectionTitle("skills", english: true), "Skills")
    }

    func testFilterKeepsGroupsAndRanksInsideEach() throws {
        let commands = try [
            command("compact"),
            command("goal"),
            command("file", client: "file"),
            command("compare"),
        ]
        let skills = [
            SkillEntry(name: "compress-notes", description: "", modelInvocable: true),
            SkillEntry(name: "browser", description: "", modelInvocable: true),
        ]
        let rows = commandMenuDisplayRows(commands: commands, skills: skills, query: "comp", leading: true, english: false)
        XCTAssertEqual(
            rows.compactMap { row -> String? in
                switch row {
                case .section(let title): return title
                case .command(let command): return command["name"].str()
                case .skill(let skill): return skill.name
                }
            },
            ["指令", "compact", "compare", "技能", "compress-notes"]
        )
        XCTAssertNil(rows.first { if case .section("添加") = $0 { return true }; return false })
    }

    func testHighlightMovesAcrossGroupsAndEnterUsesCurrentRow() throws {
        let commands = try [command("file", client: "file"), command("compact")]
        let skills = [SkillEntry(name: "notes", description: "", modelInvocable: true)]
        let rows = commandMenuDisplayRows(commands: commands, skills: skills, query: "", leading: true, english: false)
        XCTAssertEqual(commandMenuDefaultHighlight(rows), 1)
        XCTAssertEqual(commandMenuMoveHighlight(rows: rows, current: 1, direction: 1), 3)
        XCTAssertEqual(commandMenuMoveHighlight(rows: rows, current: 3, direction: 1), 5)
        XCTAssertEqual(commandMenuMoveHighlight(rows: rows, current: 5, direction: 1), 1)
        XCTAssertEqual(commandMenuMoveHighlight(rows: rows, current: 1, direction: -1), 5)
        if case .command(let command) = commandMenuHighlightedRow(rows, highlight: 1) {
            XCTAssertEqual(command["name"].str(), "file")
        } else {
            XCTFail("enter must settle the highlighted command")
        }
        if case .skill(let skill) = commandMenuHighlightedRow(rows, highlight: 5) {
            XCTAssertEqual(skill.name, "notes")
        } else {
            XCTFail("wrapped highlight must land on the skill row")
        }
        XCTAssertNil(commandMenuHighlightedRow(rows, highlight: 0))
    }

    func testSlashQueryAndLeadingMatchComposerTrigger() {
        XCTAssertEqual(slashMenuQuery("/"), "")
        XCTAssertEqual(slashMenuQuery("/comp"), "comp")
        XCTAssertEqual(slashMenuQuery("see /tmp"), "tmp")
        XCTAssertTrue(slashMenuIsLeading("/plan"))
        XCTAssertFalse(slashMenuIsLeading("see /tmp"))
        XCTAssertTrue(slashMenuIsLeading(""))
        XCTAssertNil(slashMenuTrigger("hello"))
        XCTAssertEqual(slashMenuTrigger("/x")?.kind, Character("/"))
    }

    func testDismissStaysClosedUntilQueryChangesAndDeletingSlashHides() {
        var menu = SlashMenuState()
        let typed = slashMenuTrigger("/comp")
        XCTAssertTrue(menu.isVisible(trigger: typed))
        menu.dismiss(trigger: typed)
        XCTAssertFalse(menu.isVisible(trigger: typed))
        menu.track(trigger: typed)
        XCTAssertFalse(menu.isVisible(trigger: typed), "same token and query must not reopen")
        let refined = slashMenuTrigger("/compa")
        menu.track(trigger: refined)
        XCTAssertTrue(menu.isVisible(trigger: refined))
        menu.track(trigger: nil)
        XCTAssertFalse(menu.isVisible(trigger: nil))
        XCTAssertNil(menu.dismissed)
    }

    func testPlusLauncherSharesTheMenuAndTogglesClosed() {
        var menu = SlashMenuState()
        XCTAssertFalse(menu.isVisible(trigger: nil))
        menu.togglePlus(trigger: nil)
        XCTAssertTrue(menu.plusOpen)
        XCTAssertTrue(menu.isVisible(trigger: nil))
        menu.togglePlus(trigger: nil)
        XCTAssertFalse(menu.plusOpen)
        XCTAssertFalse(menu.isVisible(trigger: nil))
        menu.togglePlus(trigger: nil)
        let typed = slashMenuTrigger("/")
        menu.track(trigger: typed)
        XCTAssertTrue(menu.isVisible(trigger: typed))
        menu.dismiss(trigger: typed)
        XCTAssertFalse(menu.plusOpen)
        XCTAssertFalse(menu.isVisible(trigger: typed))
        menu.closeAfterPick(trigger: slashMenuTrigger("/file"))
        XCTAssertFalse(menu.isVisible(trigger: slashMenuTrigger("/file")))
    }

    func testChineseCopyWritesRemoteHostNotHost() {
        XCTAssertEqual(commandContributionCollisionMessage("plan", english: false), "指令贡献 /plan 与远程主机指令冲突")
        XCTAssertFalse(commandContributionCollisionMessage("plan", english: false).contains("Host"))
        XCTAssertEqual(commandMenuAvailable(kind: "file", ops: ["attachments.upload"]), true)
        XCTAssertEqual(commandMenuAvailable(kind: "export", ops: ["session.export"]), true)
        XCTAssertEqual(commandMenuAvailable(kind: "goal", ops: ["commands.execute"]), true)
        XCTAssertFalse(commandMenuAvailable(kind: "model", ops: ["commands.execute"]))
    }
}
