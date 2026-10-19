import Foundation

/// Desktop `ui-input-trigger` `MenuView.module.css` `.menu` `max-height:400px`.
public let mentionMenuMaxHeightPoints: Double = 400

/// Desktop `MenuView.module.css` `.menu` `padding: 4px`.
public let mentionMenuPaddingPoints: Double = 4

/// Desktop `MenuView.module.css` `.menu` `bottom: calc(100% + 4px)`.
public let mentionMenuGapAboveComposerPoints: Double = 4

/// Desktop `MenuSurface` `border-radius: var(--dsw-radius-lg)`; Android `T.R12`.
public let mentionMenuSurfaceRadiusPoints: Double = 12

/// Desktop `MenuView.module.css` `.item` `border-radius: var(--dsw-radius-md)`;
/// Android mention row `T.R8`.
public let mentionMenuRowRadiusPoints: Double = 8

/// Desktop `MenuView.module.css` `.item` `min-height: 34px`.
public let mentionMenuRowMinHeightPoints: Double = 34

/// Desktop `MenuView.module.css` `.item` `padding: 6px 8px`.
public let mentionMenuRowPaddingVerticalPoints: Double = 6
public let mentionMenuRowPaddingHorizontalPoints: Double = 8

/// Desktop `MenuView.module.css` `.item` `gap: 6px`.
public let mentionMenuRowGapPoints: Double = 6

/// Desktop `MenuView.module.css` `.item` `font-size: 13px; line-height: 20px`.
public let mentionMenuItemFontSizePoints: Double = 13
public let mentionMenuItemLineHeightPoints: Double = 20

/// Desktop `MenuView.module.css` `.itemName` `max-width: 40%`.
public let mentionMenuItemNameMaxWidthFraction: Double = 0.4

/// Desktop `MenuView.module.css` `.itemDescription` `font-size: 12px; line-height: 18px`.
public let mentionMenuDescriptionFontSizePoints: Double = 12
public let mentionMenuDescriptionLineHeightPoints: Double = 18

/// Desktop `MenuView.module.css` `.sectionTitle` `font-size: 11px; line-height: 16px;
/// font-weight: 500; padding: 5px 8px 2px; min-height: 23px`.
public let mentionMenuSectionTitleFontSizePoints: Double = 11
public let mentionMenuSectionTitleLineHeightPoints: Double = 16
public let mentionMenuSectionTitleFontWeight: Double = 500
public let mentionMenuSectionTitlePaddingTopPoints: Double = 5
public let mentionMenuSectionTitlePaddingBottomPoints: Double = 2
public let mentionMenuSectionTitlePaddingHorizontalPoints: Double = 8
public let mentionMenuSectionTitleMinHeightPoints: Double = 23

/// Desktop `MenuView.module.css` `.sectionTitle:not(:first-child) { margin-top: 3px }`.
public let mentionMenuSectionTitleGapPoints: Double = 3

/// Desktop `MenuView.module.css` `.skeletonRow` `min-height: 34px; padding: 6px 8px`.
public let mentionMenuSkeletonBarHeightPoints: Double = 18

/// Desktop `MenuView.module.css` `.skeletonBar` widths 32% / 48%.
public let mentionMenuSkeletonBarFractions: [Double] = [0.32, 0.48]

/// Desktop `MenuView.module.css` `.crumbs` `padding: 3px 3px 5px; gap: 2px;
/// margin-bottom: 2px; border-bottom: 0.5px`.
public let mentionMenuCrumbPaddingTopPoints: Double = 3
public let mentionMenuCrumbPaddingBottomPoints: Double = 5
public let mentionMenuCrumbPaddingHorizontalPoints: Double = 3
public let mentionMenuCrumbGapPoints: Double = 2
public let mentionMenuCrumbMarginBottomPoints: Double = 2
public let mentionMenuCrumbSeparatorSizePoints: Double = 12
public let mentionMenuCrumbFontSizePoints: Double = 11
public let mentionMenuCrumbLineHeightPoints: Double = 16
public let mentionMenuCrumbPaddingInlinePoints: Double = 5
public let mentionMenuCrumbPaddingBlockPoints: Double = 2

/// Desktop `MenuView.module.css` `.drillHint` / `.drillHintText` `10px / 16px`.
public let mentionMenuDrillHintFontSizePoints: Double = 10
public let mentionMenuDrillHintLineHeightPoints: Double = 16
public let mentionMenuDrillButtonPoints: Double = 18
public let mentionMenuDrillIconSizePoints: Double = 12

/// Android `MentionMenu` `shadowElevation = 8.dp` for desktop
/// `--dsw-elevation-prominent`.
public let mentionMenuShadowRadiusPoints: Double = 8
public let mentionMenuShadowYPoints: Double = 4
public let mentionMenuShadowOpacity: Double = 0.12

/// Desktop `MenuView.module.css` `.menu` elevation stroke `0` + MenuSurface
/// `--dsw-elevation-stroke-color`; Android `BorderStroke(0.5.dp, T.Border)`.
public let mentionMenuStrokeWidthPoints: Double = 0.5

/// Desktop conversation `ReferenceChip.module.css` `.chip` `max-width: 240px;
/// gap: 3px` plus `composer-editor.module.css` `.reference` `padding: 0 4px`
/// and `border-radius: var(--dsw-radius-sm)` (6px). Composer icon is
/// `ReferenceIconRegular` `size: 14`.
public let mentionComposerChipIconSizePoints: Double = 14
public let mentionComposerChipMaxWidthPoints: Double = 240
public let mentionComposerChipGapPoints: Double = 3
public let mentionComposerChipPaddingHorizontalPoints: Double = 4
public let mentionComposerChipRadiusPoints: Double = 6
public let mentionComposerChipFontWeight: Double = 400

/// Desktop `ui-primitives` `user-text.module.css` `.refChip` `margin: 0 2px;
/// font-weight: 500` and `.refIcon` `margin-right: 4px`.
public let mentionMessageChipMarginHorizontalPoints: Double = 2
public let mentionMessageChipIconGapPoints: Double = 4
public let mentionMessageChipFontWeight: Double = 500

public enum MentionSection: String, Equatable, Sendable {
    case files
    case subagents
    case sessions
}

public struct MentionRow: Equatable, Sendable, Identifiable {
    public var section: MentionSection
    public var title: String
    public var description: String?
    public var mention: String
    public var filePath: String?
    public var drill: String?

    public var id: String { mention + (filePath ?? "") + section.rawValue }

    public init(
        section: MentionSection,
        title: String,
        description: String? = nil,
        mention: String,
        filePath: String? = nil,
        drill: String? = nil
    ) {
        self.section = section
        self.title = title
        self.description = description
        self.mention = mention
        self.filePath = filePath
        self.drill = drill
    }
}

public struct MentionCrumb: Equatable, Sendable {
    public var label: String
    public var drill: String
    public var current: Bool

    public init(label: String, drill: String, current: Bool = false) {
        self.label = label
        self.drill = drill
        self.current = current
    }
}

public func mentionSectionTitle(_ section: MentionSection, english: Bool) -> String {
    switch section {
    case .files: return english ? "Files & folders" : "文件与文件夹"
    case .subagents: return english ? "Subagents" : "子智能体"
    case .sessions: return english ? "Sessions" : "对话"
    }
}

public func mentionCrumbRootLabel(english: Bool) -> String {
    english ? "Workspace" : "工作区"
}

public func mentionNoCwdLabel(english: Bool) -> String {
    english ? "(no cwd)" : "（无工作目录）"
}

public func mentionDrillHint(english: Bool) -> String {
    english ? "Browse folder" : "进入目录"
}

public func mentionDrillKey() -> String { "Tab" }

public func mentionMenuIdentifier() -> String { "mentionMenu" }

public func mentionChipIdentifier(_ kind: ComposerReferenceKind) -> String {
    "mentionChip.\(kind.rawValue)"
}

/// Open-quote directory token used to keep completion live after Tab drill.
/// Desktop `formatFileMention` for `directory` + quote/whitespace returns
/// `@"path/` without the closing quote.
public func mentionDirectoryDrillToken(_ path: String, quoted: Bool) -> String? {
    let token = fileReferenceToken(path, directory: true, preserveQuote: quoted)
        ?? fileReferenceToken(path, directory: true)
    return token?.hasSuffix("\"") == true ? String(token!.dropLast()) : token
}

public func mentionFileRow(
    _ file: FileReference,
    quoted: Bool,
    withLocation: Bool
) -> MentionRow? {
    let directory = file.kind == "directory" || file.kind == "folder"
    guard let mention = fileReferenceToken(file.path, directory: directory, preserveQuote: quoted) else {
        return nil
    }
    let path = file.path.hasSuffix("/") ? String(file.path.dropLast()) : file.path
    let slash = path.lastIndex(of: "/")
    let name = slash.map { String(path[path.index(after: $0)...]) } ?? path
    let parent = slash.map { String(path[..<$0]) } ?? ""
    return MentionRow(
        section: .files,
        title: name + (directory ? "/" : ""),
        description: withLocation && !parent.isEmpty ? parent : nil,
        mention: mention,
        filePath: file.path,
        drill: directory ? mentionDirectoryDrillToken(file.path, quoted: quoted) : nil
    )
}

public func mentionSessionRow(
    _ candidate: SessionReference,
    listed: SessionSummary?,
    currentSessionId: String?,
    now: Int64,
    english: Bool
) -> MentionRow {
    let child = listed?.origin == "subagent" && listed?.parentSessionId == currentSessionId
        || candidate.kind == "subagent"
    let updated = listed?.updatedAt ?? candidate.updatedAt ?? candidate.createdAt
    let age = updated.map { formatSessionTime(at: $0, now: now, english: english) }
    let location: String?
    if candidate.sameWorkspace == true {
        location = nil
    } else if let cwd = candidate.cwd ?? listed?.cwd {
        location = cwd
    } else if candidate.sameWorkspace == false {
        location = mentionNoCwdLabel(english: english)
    } else {
        location = nil
    }
    let description = [location, age].compactMap { $0 }.joined(separator: " · ")
    return MentionRow(
        section: child ? .subagents : .sessions,
        title: candidate.title ?? candidate.mention,
        description: description.isEmpty ? nil : description,
        mention: candidate.mention
    )
}

public func mentionCrumbs(query: String, quoted: Bool, drilled: Bool, english: Bool) -> [MentionCrumb] {
    if !drilled || !query.contains("/") { return [] }
    let prefix = query[..<(query.lastIndex(of: "/") ?? query.endIndex)]
    let segments = prefix.split(separator: "/").map(String.init).filter { !$0.isEmpty }
    var crumbs = [MentionCrumb(label: mentionCrumbRootLabel(english: english), drill: quoted ? "@\"" : "@")]
    for (index, segment) in segments.enumerated() {
        let path = segments[0...index].joined(separator: "/")
        guard let token = mentionDirectoryDrillToken(path, quoted: quoted) else { return [] }
        crumbs.append(MentionCrumb(label: segment, drill: token, current: index == segments.count - 1))
    }
    return crumbs
}

public func mentionRows(
    files: [FileReference],
    sessions: [SessionReference],
    listed: [SessionSummary],
    currentSessionId: String?,
    query: String,
    quoted: Bool,
    drilled: Bool,
    now: Int64,
    english: Bool
) -> [MentionRow] {
    let crumbs = mentionCrumbs(query: query, quoted: quoted, drilled: drilled, english: english)
    let withLocation = crumbs.isEmpty
    let summaries = Dictionary(uniqueKeysWithValues: listed.map { ($0.sessionId, $0) })
    let fileRows = files.compactMap { mentionFileRow($0, quoted: quoted, withLocation: withLocation) }
    let sessionRows = quoted ? [] : sessions.map { candidate in
        mentionSessionRow(
            candidate,
            listed: candidate.sessionId.flatMap { summaries[$0] },
            currentSessionId: currentSessionId,
            now: now,
            english: english
        )
    }
    return fileRows
        + sessionRows.filter { $0.section == .subagents }
        + sessionRows.filter { $0.section == .sessions }
}

public func mentionDefaultHighlight(rowCount: Int) -> Int? {
    rowCount == 0 ? nil : 0
}

public func mentionMoveHighlight(current: Int?, direction: Int, rowCount: Int) -> Int? {
    if rowCount <= 0 { return nil }
    let start = current ?? (direction > 0 ? -1 : 0)
    return (start + direction + rowCount) % rowCount
}

/// Wire form sent with the prompt: the original `@path` / `@"path"` /
/// `@[title](dsh-session:id)` tokens. Desktop `codec.serialize` is identity
/// on `ref`.
public func mentionPromptText(_ text: String) -> String {
    text
}

public func mentionPromptReferences(_ text: String) -> [ComposerReference] {
    composerReferences(text)
}

public func mentionMenuTrigger(_ text: String, cursor: Int? = nil) -> ComposerTrigger? {
    let at = cursor ?? text.count
    guard let trigger = composerTrigger(text, cursor: at), trigger.kind == Character("@") else { return nil }
    return trigger
}

/// Typed `@` stays open until Escape / outside tap / pick. A dismissed token
/// stays closed until the query changes — desktop MenuView `onDismiss`.
public struct MentionMenuState: Equatable, Sendable {
    public var dismissed: SlashMenuDismissal?

    public init(dismissed: SlashMenuDismissal? = nil) {
        self.dismissed = dismissed
    }

    public func isVisible(trigger: ComposerTrigger?) -> Bool {
        guard let trigger, trigger.kind == Character("@") else { return false }
        if let dismissed, dismissed.query == trigger.query, dismissed.start == trigger.start, dismissed.end == trigger.end {
            return false
        }
        return true
    }

    public mutating func track(trigger: ComposerTrigger?) {
        guard let trigger, trigger.kind == Character("@") else {
            if dismissed != nil, trigger == nil { dismissed = nil }
            return
        }
        if let dismissed, dismissed.query != trigger.query || dismissed.start != trigger.start || dismissed.end != trigger.end {
            self.dismissed = nil
        }
    }

    public mutating func dismiss(trigger: ComposerTrigger?) {
        if let trigger, trigger.kind == Character("@") {
            dismissed = SlashMenuDismissal(query: trigger.query, start: trigger.start, end: trigger.end)
        } else {
            dismissed = nil
        }
    }

    public mutating func closeAfterPick(trigger: ComposerTrigger?) {
        dismiss(trigger: trigger)
    }
}
