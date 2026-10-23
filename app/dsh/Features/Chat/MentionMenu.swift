import SwiftUI
import UIKit
import DSHProtocol

struct MentionMenuOverlay: View {
    @ObservedObject var model: AppModel
    @ObservedObject var host: CommandMenuHost
    var query: String
    var quoted: Bool
    var availableHeight: CGFloat = 0
    var onPick: (MentionRow) -> Void
    var onDrill: (String) -> Void
    var onDismiss: () -> Void

    @State private var highlight: Int?

    private var rows: [MentionRow] {
        mentionRows(
            files: model.fileMentions,
            sessions: model.sessionMentions,
            listed: model.sessions,
            currentSessionId: model.chat?.sessionId,
            query: query,
            quoted: quoted,
            drilled: model.mentionDrilled,
            now: Int64(Date().timeIntervalSince1970 * 1000),
            english: L.en
        )
    }

    private var crumbs: [MentionCrumb] {
        mentionCrumbs(query: query, quoted: quoted, drilled: model.mentionDrilled, english: L.en)
    }

    private var showSkeleton: Bool {
        model.mentionLoading && rows.isEmpty
    }

    private var cardMaxHeight: CGFloat {
        CGFloat(inputTriggerMenuCardMaxHeight(availableHeight: Double(availableHeight)))
    }

    var body: some View {
        menuCard
            .onAppear { highlight = mentionDefaultHighlight(rowCount: rows.count) }
            .onChange(of: query) { _ in highlight = mentionDefaultHighlight(rowCount: rows.count) }
            .onChange(of: rows.count) { _ in
                if highlight.flatMap({ rows.indices.contains($0) }) != true {
                    highlight = mentionDefaultHighlight(rowCount: rows.count)
                }
            }
            .onChange(of: host.enterRequest) { _ in
                if host.enterRequest > 0, !model.mentionLoading, let h = highlight, rows.indices.contains(h) {
                    onPick(rows[h])
                }
            }
            .onChange(of: host.moveRequest) { _ in
                if host.moveRequest > 0 {
                    highlight = mentionMoveHighlight(current: highlight, direction: host.moveDirection, rowCount: rows.count)
                }
            }
            .onChange(of: host.tabRequest) { _ in
                if host.tabRequest > 0, !model.mentionLoading, let h = highlight, rows.indices.contains(h) {
                    if let drill = rows[h].drill {
                        onDrill(drill)
                    } else {
                        onPick(rows[h])
                    }
                }
            }
    }

    private var menuCard: some View {
        ScrollViewReader { proxy in
            MenuViewViewport(maxHeight: cardMaxHeight) {
                VStack(alignment: .leading, spacing: 0) {
                    if !crumbs.isEmpty { crumbBar }
                    if showSkeleton {
                        skeleton
                    } else {
                        rowList
                    }
                }
                .padding(CGFloat(mentionMenuPaddingPoints))
            }
            .onChange(of: highlight) { value in
                if let value { proxy.scrollTo(value, anchor: .center) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(T.settingsCard)
        .overlay(
            RoundedRectangle(cornerRadius: CGFloat(mentionMenuSurfaceRadiusPoints), style: .circular)
                .stroke(T.borderL1, lineWidth: CGFloat(mentionMenuStrokeWidthPoints))
        )
        .clipShape(RoundedRectangle(cornerRadius: CGFloat(mentionMenuSurfaceRadiusPoints), style: .circular))
        .shadow(
            color: Color.black.opacity(mentionMenuShadowOpacity),
            radius: CGFloat(mentionMenuShadowRadiusPoints),
            y: CGFloat(mentionMenuShadowYPoints)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(mentionMenuIdentifier())
    }

    private var crumbBar: some View {
        HStack(spacing: CGFloat(mentionMenuCrumbGapPoints)) {
            ForEach(Array(crumbs.enumerated()), id: \.offset) { index, crumb in
                if index > 0 {
                    OfficialGlyph(kind: .chevronRight, size: CGFloat(mentionMenuCrumbSeparatorSizePoints), color: T.text3)
                }
                Button {
                    onDrill(crumb.drill)
                } label: {
                    Text(crumb.label)
                        .font(Font.system(size: CGFloat(mentionMenuCrumbFontSizePoints)))
                        .foregroundStyle(crumb.current ? T.ink : T.text3)
                        .lineLimit(1)
                        .padding(.horizontal, CGFloat(mentionMenuCrumbPaddingInlinePoints))
                        .padding(.vertical, CGFloat(mentionMenuCrumbPaddingBlockPoints))
                }
                .buttonStyle(.plain)
                .disabled(crumb.current)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, CGFloat(mentionMenuCrumbPaddingTopPoints))
        .padding(.bottom, CGFloat(mentionMenuCrumbPaddingBottomPoints))
        .padding(.horizontal, CGFloat(mentionMenuCrumbPaddingHorizontalPoints))
        .overlay(alignment: .bottom) {
            T.borderL1.frame(height: CGFloat(mentionMenuStrokeWidthPoints))
        }
        .padding(.bottom, CGFloat(mentionMenuCrumbMarginBottomPoints))
        .accessibilityLabel(L.t("目录导航", "Folder navigation"))
    }

    private var skeleton: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(mentionMenuSkeletonBarFractions.enumerated()), id: \.offset) { _, fraction in
                HStack {
                    Capsule()
                        .fill(T.fill2)
                        .frame(height: CGFloat(mentionMenuSkeletonBarHeightPoints))
                        .frame(maxWidth: .infinity)
                        .padding(.trailing, CGFloat((1 - fraction) * 120))
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, CGFloat(mentionMenuRowPaddingHorizontalPoints))
                .padding(.vertical, CGFloat(mentionMenuRowPaddingVerticalPoints))
                .frame(minHeight: CGFloat(mentionMenuRowMinHeightPoints))
            }
        }
        .accessibilityLabel(L.t("正在加载…", "Loading…"))
    }

    private var rowList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                if index == 0 || rows[index - 1].section != row.section {
                    Text(mentionSectionTitle(row.section, english: L.en))
                        .font(Font.system(size: CGFloat(mentionMenuSectionTitleFontSizePoints), weight: .medium))
                        .foregroundStyle(T.text3)
                        .padding(.top, index == 0 ? CGFloat(mentionMenuSectionTitlePaddingTopPoints) : CGFloat(mentionMenuSectionTitlePaddingTopPoints + mentionMenuSectionTitleGapPoints))
                        .padding(.bottom, CGFloat(mentionMenuSectionTitlePaddingBottomPoints))
                        .padding(.horizontal, CGFloat(mentionMenuSectionTitlePaddingHorizontalPoints))
                        .frame(minHeight: CGFloat(mentionMenuSectionTitleMinHeightPoints), alignment: .leading)
                }
                rowButton(row, index: index)
            }
        }
    }

    private func rowButton(_ row: MentionRow, index: Int) -> some View {
        let active = highlight == index
        return HStack(spacing: 0) {
            HStack(spacing: CGFloat(mentionMenuRowGapPoints)) {
                OfficialGlyph(
                    kind: mentionGlyph(row),
                    size: CGFloat(mentionMenuIconSizePoints),
                    color: T.text3
                )
                MentionNameDescription {
                    Text(row.title)
                        .font(Font.system(size: CGFloat(mentionMenuItemFontSizePoints)))
                        .foregroundStyle(T.ink)
                        .lineLimit(1)
                    if let description = row.description {
                        Text(description)
                            .font(Font.system(size: CGFloat(mentionMenuDescriptionFontSizePoints)))
                            .foregroundStyle(T.text3)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: CGFloat(mentionMenuItemLineHeightPoints), alignment: .leading)
            }
            .padding(.horizontal, CGFloat(mentionMenuRowPaddingHorizontalPoints))
            .padding(.vertical, CGFloat(mentionMenuRowPaddingVerticalPoints))
            .frame(minHeight: CGFloat(mentionMenuRowMinHeightPoints))
            .contentShape(Rectangle())
            .onTapGesture {
                highlight = index
                onPick(row)
            }
            if row.drill != nil {
                if active {
                    HStack(spacing: 3) {
                        Text(mentionDrillHint(english: L.en))
                            .foregroundStyle(T.caption)
                            .font(Font.system(size: CGFloat(mentionMenuDrillHintFontSizePoints)))
                        Text(mentionDrillKey())
                            .font(Font.system(size: CGFloat(mentionMenuDrillHintFontSizePoints)))
                            .foregroundStyle(T.caption)
                            .padding(.horizontal, 4)
                            .background(T.hoverBg, in: RoundedRectangle(cornerRadius: CGFloat(dswRadiusXsPoints), style: .continuous))
                    }
                    .padding(.trailing, 4)
                }
                Button {
                    highlight = index
                    if let drill = row.drill { onDrill(drill) }
                } label: {
                    OfficialGlyph(
                        kind: .chevronRight,
                        size: CGFloat(mentionMenuDrillIconSizePoints),
                        color: T.text3
                    )
                    .frame(width: CGFloat(mentionMenuDrillButtonPoints), height: CGFloat(mentionMenuDrillButtonPoints))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(mentionDrillHint(english: L.en))
                .accessibilityIdentifier("mentionDrill:\(row.filePath ?? row.title)")
            }
        }
        .background(active ? T.hoverBg : Color.clear, in: RoundedRectangle(cornerRadius: CGFloat(mentionMenuRowRadiusPoints), style: .continuous))
        .id(index)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(active ? [.isSelected] : [])
    }

    private func mentionGlyph(_ row: MentionRow) -> OfficialGlyph.Kind {
        if row.drill != nil { return .folderClose }
        if row.filePath != nil { return .browseOutline }
        return .queueOutline
    }
}

struct UserMentionText: View {
    let text: String
    var color: Color = T.ink
    var pending = false

    var body: some View {
        MentionWrap(alignment: .leading, spacing: 0, lineSpacing: 2) {
            ForEach(Array(mentionRuns(text).enumerated()), id: \.offset) { _, run in
                switch run {
                case .text(let value):
                    SelectableText(value, font: LocalFonts.uiText(), color: UIColor(color.opacity(pending ? 0.6 : 1)), identifier: "userMentionText.run")
                case .chip(let ref):
                    MentionChipLabel(ref: ref, composer: false)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("userMentionText")
    }
}

enum MentionRun: Equatable {
    case text(String)
    case chip(ComposerReference)
}

func mentionRuns(_ source: String) -> [MentionRun] {
    let refs = composerReferences(source)
    var runs: [MentionRun] = []
    var cursor = 0
    for ref in refs {
        if ref.start > cursor {
            runs.append(.text(mentionSubstring(source, cursor, ref.start)))
        }
        runs.append(.chip(ref))
        cursor = ref.end
    }
    if cursor < source.count {
        runs.append(.text(mentionSubstring(source, cursor, source.count)))
    }
    if runs.isEmpty { runs.append(.text(source)) }
    return runs
}

/// Desktop `ui-primitives` `ReferenceChip` / conversation editor chip.
struct MentionChipLabel: View {
    let ref: ComposerReference
    var composer = false

    var body: some View {
        let icon = composer ? mentionComposerChipIconSizePoints : mentionChipIconSizePoints
        let gap = composer ? mentionComposerChipGapPoints : mentionMessageChipIconGapPoints
        HStack(spacing: CGFloat(gap)) {
            OfficialGlyph(
                kind: mentionGlyph(ref.kind),
                size: CGFloat(icon),
                color: T.businessPrimary
            )
            Text(ref.label)
                .font(LocalFonts.text().weight(composer ? .regular : .medium))
                .foregroundStyle(T.businessPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, CGFloat(composer ? mentionComposerChipPaddingHorizontalPoints : mentionMessageChipMarginHorizontalPoints))
        .frame(maxWidth: CGFloat(mentionComposerChipMaxWidthPoints), alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: CGFloat(composer ? mentionComposerChipRadiusPoints : 0), style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(mentionChipIdentifier(ref.kind))
    }
}

/// Word-wrap text runs and atomic chips the way desktop `UserTextRun` +
/// `ReferenceChip` share one line box.
struct MentionWrap<Content: View>: View {
    var alignment: HorizontalAlignment = .leading
    var spacing: CGFloat = 0
    var lineSpacing: CGFloat = 0
    @ViewBuilder var content: Content

    var body: some View {
        FlowLayout(alignment: alignment, spacing: spacing, lineSpacing: lineSpacing) {
            content
        }
    }
}

/// Desktop `.itemName { max-width: 40% }` with the description taking the rest.
private struct MentionNameDescription: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var height: CGFloat = 0
        for view in subviews {
            height = max(height, view.sizeThatFits(.unspecified).height)
        }
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let name = subviews.first else { return }
        let nameMax = bounds.width * CGFloat(mentionMenuItemNameMaxWidthFraction)
        let nameSize = name.sizeThatFits(ProposedViewSize(width: nameMax, height: bounds.height))
        let nameWidth = min(nameSize.width, nameMax)
        name.place(
            at: CGPoint(x: bounds.minX, y: bounds.midY - nameSize.height / 2),
            proposal: ProposedViewSize(width: nameWidth, height: nameSize.height)
        )
        if subviews.count > 1 {
            let description = subviews[1]
            let remain = max(0, bounds.width - nameWidth)
            let descSize = description.sizeThatFits(ProposedViewSize(width: remain, height: bounds.height))
            description.place(
                at: CGPoint(x: bounds.maxX - min(descSize.width, remain), y: bounds.midY - descSize.height / 2),
                proposal: ProposedViewSize(width: min(descSize.width, remain), height: descSize.height)
            )
        }
    }
}

private struct FlowLayout: Layout {
    var alignment: HorizontalAlignment
    var spacing: CGFloat
    var lineSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(subviews: subviews, maxWidth: resolvedMaxWidth(proposal.width), origin: .zero, placing: false)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        _ = arrange(subviews: subviews, maxWidth: bounds.width, origin: bounds.origin, placing: true)
    }

    /// Hug used width. Returning the proposed max width here is what made
    /// short user bubbles stretch to the trailing edge after #83 swapped
    /// `Text` for mention-run `FlowLayout`.
    private func arrange(
        subviews: Subviews,
        maxWidth: CGFloat,
        origin: CGPoint,
        placing: Bool
    ) -> CGSize {
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var line: [(LayoutSubview, CGSize)] = []
        var usedWidth: CGFloat = 0

        func flush() {
            guard !line.isEmpty else { return }
            let lineWidth = line.reduce(0) { $0 + $1.1.width } + CGFloat(max(line.count - 1, 0)) * spacing
            var originX = origin.x
            if maxWidth.isFinite {
                if alignment == .trailing {
                    originX = origin.x + maxWidth - lineWidth
                } else if alignment == .center {
                    originX = origin.x + (maxWidth - lineWidth) / 2
                }
            }
            if placing {
                var placed = originX
                for (view, size) in line {
                    view.place(
                        at: CGPoint(x: placed, y: origin.y + y + (lineHeight - size.height) / 2),
                        proposal: ProposedViewSize(size)
                    )
                    placed += size.width + spacing
                }
            }
            usedWidth = max(usedWidth, lineWidth)
            line.removeAll()
        }

        for view in subviews {
            let size = fittedSize(view, maxWidth: maxWidth)
            if x > 0 && maxWidth.isFinite && x + size.width > maxWidth {
                flush()
                y += lineHeight + lineSpacing
                x = 0
                lineHeight = 0
            }
            line.append((view, size))
            lineHeight = max(lineHeight, size.height)
            x += size.width + spacing
        }
        flush()
        return CGSize(width: usedWidth, height: y + lineHeight)
    }

    private func resolvedMaxWidth(_ proposed: CGFloat?) -> CGFloat {
        if let proposed, proposed > 0, proposed.isFinite { return proposed }
        return .infinity
    }

    private func fittedSize(_ view: LayoutSubview, maxWidth: CGFloat) -> CGSize {
        let ideal = view.sizeThatFits(.unspecified)
        if maxWidth.isFinite, ideal.width > maxWidth || !ideal.width.isFinite {
            let wrapped = view.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
            return CGSize(width: min(wrapped.width, maxWidth), height: wrapped.height)
        }
        return ideal
    }
}

func mentionGlyph(_ kind: ComposerReferenceKind) -> OfficialGlyph.Kind {
    switch kind {
    case .session: return .queueOutline
    case .file: return .browseOutline
    case .directory: return .folderClose
    }
}

func mentionSubstring(_ text: String, _ start: Int, _ end: Int) -> String {
    if start >= end || start >= text.count { return "" }
    let lower = text.index(text.startIndex, offsetBy: max(0, start))
    let upper = text.index(text.startIndex, offsetBy: min(text.count, end))
    return String(text[lower..<upper])
}
