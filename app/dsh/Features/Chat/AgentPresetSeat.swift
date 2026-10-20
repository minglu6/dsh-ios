import SwiftUI
import DSHProtocol


/// Desktop `EmptyHero` `WorkspaceChip`: ghost trigger + WorkspacePicker MenuSurface.
/// System `Menu` + capsule fill is not the desktop chip.
struct LandingWorkspaceChip: View {
    @ObservedObject var model: AppModel
    @Binding var showDirectoryPicker: Bool
    @State private var open = false

    private var selectedId: String? {
        model.draftWorkspaceId ?? model.workspaces.first?.workspaceId
    }

    private var canCreate: Bool { model.ops.contains("workspace.create") }

    var body: some View {
        Button {
            if workspaceChipOpensDirectoryFlowDirectly(
                workspaceCount: model.workspaces.count,
                canCreate: canCreate
            ) {
                showDirectoryPicker = true
            } else if model.isOnline {
                open.toggle()
            }
        } label: {
            HStack(spacing: 4) {
                OfficialGlyph(
                    kind: model.landingWorkspaceLabel == nil ? .folderClose : .folderOpen,
                    size: CGFloat(workspaceChipIconSizePoints),
                    color: T.ink
                )
                Text(model.landingWorkspaceLabel ?? landingChooseWorkspace(english: L.en))
                    .font(Font.system(size: CGFloat(workspaceChipFontSizePoints), weight: .medium))
                    .lineLimit(1)
                OfficialGlyph(
                    kind: .chevronDown,
                    size: CGFloat(workspaceChipChevronSizePoints),
                    color: T.caption
                )
                .rotationEffect(.degrees(open ? 180 : 0))
            }
            .foregroundStyle(T.ink)
            .padding(.horizontal, 8)
            .frame(minHeight: CGFloat(workspaceChipMinHeightPoints))
            .frame(maxWidth: CGFloat(workspaceChipMaxWidthPoints), alignment: .leading)
        }
        .buttonStyle(.plain)
        .disabled(!model.isOnline)
        .opacity(model.isOnline ? 1 : 0.45)
        .accessibilityLabel(landingChooseWorkspace(english: L.en))
        .accessibilityValue(model.landingWorkspaceLabel ?? "")
        .accessibilityIdentifier("draftWorkspace")
        .popover(
            isPresented: $open,
            attachmentAnchor: .rect(.bounds),
            arrowEdge: composerPickerPopoverOpensAbove ? .bottom : .top
        ) {
            VStack(alignment: .leading, spacing: 0) {
                if model.workspaces.isEmpty {
                    Text(workspacePickerLoading(english: L.en))
                        .font(Font.system(size: 12))
                        .foregroundStyle(T.text2)
                        .padding(8)
                }
                ForEach(model.workspaces) { workspace in
                    let title = workspaceDisplayTitle(
                        title: workspace.title,
                        path: workspace.path,
                        localizedDefault: L.defaultWorkspace()
                    )
                    Button {
                        model.draftWorkspaceId = workspace.workspaceId
                        open = false
                    } label: {
                        HStack(spacing: 8) {
                            OfficialGlyph(
                                kind: .folderClose,
                                size: CGFloat(workspaceChipIconSizePoints),
                                color: T.ink
                            )
                            Text(title)
                                .font(Font.system(size: 13))
                                .foregroundStyle(T.ink)
                                .lineLimit(1)
                            Spacer(minLength: 8)
                            if selectedId == workspace.workspaceId {
                                OfficialGlyph(kind: .checkOutline, size: 12, color: T.ink)
                            }
                        }
                        .padding(.horizontal, 8)
                        .frame(minHeight: CGFloat(permissionMenuRowMinHeightPoints))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                if canCreate {
                    Button {
                        open = false
                        showDirectoryPicker = true
                    } label: {
                        HStack(spacing: 8) {
                            OfficialGlyph(
                                kind: .plusOutline,
                                size: CGFloat(workspaceChipIconSizePoints),
                                color: T.ink
                            )
                            Text(addWorkspaceMenuLabel(english: L.en))
                                .font(Font.system(size: 13))
                                .foregroundStyle(T.ink)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 8)
                        .frame(minHeight: CGFloat(permissionMenuRowMinHeightPoints))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(CGFloat(permissionMenuPaddingPoints))
            .frame(minWidth: 180, maxWidth: CGFloat(workspaceChipMaxWidthPoints))
            .modifier(PopoverCompactAdaptation())
        }
    }
}

/// Desktop landing preset chip with a measured, viewport-bounded menu portal.
struct AgentPresetSeat: View {
    @ObservedObject var model: AppModel
    @Binding var open: Bool
    var coordinateSpace: String

    private var rows: [JSONValue] {
        PresetPolicy.visibleRows(model.presetRoster, codingTools: model.showCodeWorkView)
    }

    private var currentId: String? {
        SessionContextPolicy.draftPresetId(
            pending: model.pendingCreatorPreset, draft: model.draftPreset, roster: model.presetRoster
        )
    }

    private var currentLabel: String {
        SessionContextPolicy.presetName(id: currentId, roster: model.presetRoster, english: L.en)
            ?? (L.en ? "Choose work mode" : "选择工作模式")
    }

    var body: some View {
        Button { if model.isOnline && !rows.isEmpty { open.toggle() } } label: {
                HStack(spacing: 4) {
                    OfficialGlyph(kind: .agentPreset, size: 14, color: T.ink)
                    Text(currentLabel)
                        .font(Font.system(size: CGFloat(agentPresetSeatFontSizePoints), weight: .medium))
                        .lineLimit(1)
                    if !rows.isEmpty {
                        OfficialGlyph(kind: .chevronDown, size: 11, color: T.caption)
                            .rotationEffect(.degrees(open ? 180 : 0))
                    }
                }
                .foregroundStyle(T.ink)
                .padding(.horizontal, 8)
                .frame(minWidth: CGFloat(agentPresetMenuAnchorMinWidthPoints))
                .frame(minHeight: CGFloat(agentPresetSeatMinHeightPoints))
                .frame(maxWidth: CGFloat(agentPresetSeatMaxWidthPoints), alignment: .leading)
            }
            .buttonStyle(.plain)
            .disabled(!model.isOnline || rows.isEmpty)
            .opacity(model.isOnline && !rows.isEmpty ? 1 : 0.45)
            .accessibilityLabel(currentLabel)
            .accessibilityHint(agentPresetSeatHint(english: L.en))
            .accessibilityIdentifier(agentPresetSeatIdentifier())
            .background(
                GeometryReader { geo in
                    Color.clear.preference(
                        key: AgentPresetSeatFrameKey.self,
                        value: geo.frame(in: .named(coordinateSpace))
                    )
                }
            )
    }
}

/// Desktop portal `Menu` + `AgentPresetSeat` name/description rows.
struct AgentPresetMenuLayer: View {
    @ObservedObject var model: AppModel
    var seatFrame: CGRect
    var onClose: () -> Void

    private var rows: [JSONValue] {
        PresetPolicy.visibleRows(model.presetRoster, codingTools: model.showCodeWorkView)
    }

    private var currentId: String? {
        SessionContextPolicy.draftPresetId(
            pending: model.pendingCreatorPreset, draft: model.draftPreset, roster: model.presetRoster
        )
    }

    var body: some View {
        GeometryReader { canvas in
            let maxHeight = CGFloat(agentPresetMenuMaxHeight(viewportHeight: Double(canvas.size.height)))
            let width = min(
                CGFloat(agentPresetMenuMaxWidthPoints),
                max(0, canvas.size.width - CGFloat(agentPresetMenuViewportMarginPoints * 2))
            )
            AnchoredPresetMenuLayout(seatFrame: seatFrame, viewport: canvas.size) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onClose)
                    .accessibilityHidden(true)
                menuCard(maxHeight: maxHeight, width: width)
            }
        }
    }

    private var menuRows: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                let id = row["id"].str() ?? ""
                Button {
                    model.draftPreset = id
                    model.pendingCreatorPreset = nil
                    onClose()
                } label: {
                    HStack(alignment: .top, spacing: CGFloat(agentPresetMenuRowGapPoints)) {
                        VStack(alignment: .leading, spacing: CGFloat(agentPresetMenuItemCopyGapPoints)) {
                            Text(PresetPolicy.name(row, english: L.en))
                                .font(Font.system(size: CGFloat(agentPresetMenuItemNameFontSizePoints)))
                                .foregroundStyle(T.ink)
                                .frame(
                                    minHeight: CGFloat(agentPresetMenuItemNameLineHeightPoints),
                                    alignment: .leading
                                )
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("agentPresetTitle.\(id)")
                            Text(PresetPolicy.description(row, english: L.en).flatMap { $0.isEmpty ? nil : $0 }
                                 ?? agentPresetNoDescription(english: L.en))
                                .font(Font.system(size: CGFloat(agentPresetMenuItemDescFontSizePoints)))
                                .foregroundStyle(T.caption)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("agentPresetDesc.\(id)")
                        }
                        .frame(maxWidth: CGFloat(agentPresetMenuItemMaxWidthPoints), alignment: .leading)
                        Spacer(minLength: 0)
                        if currentId == id {
                            OfficialGlyph(
                                kind: .checkOutline,
                                size: CGFloat(agentPresetMenuCheckSizePoints),
                                color: T.ink
                            )
                        }
                    }
                    .padding(.horizontal, CGFloat(agentPresetMenuRowPaddingHorizontalPoints))
                    .padding(.vertical, CGFloat(agentPresetMenuRowPaddingVerticalPoints))
                    .frame(minHeight: CGFloat(agentPresetMenuRowMinHeightPoints), alignment: .top)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .contain)
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier(agentPresetRowIdentifier(id))
            }
        }
        .padding(CGFloat(agentPresetMenuPaddingPoints))
    }

    private func menuCard(maxHeight: CGFloat, width: CGFloat) -> some View {
        MenuViewViewport(maxHeight: maxHeight) {
            menuRows
        }
        .frame(width: width)
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
        .accessibilityIdentifier(agentPresetMenuIdentifier())
    }
}

struct AgentPresetSeatFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}

/// Measure and place in one layout pass. A preference measured after `.offset`
/// can leave the initial zero-size placement outside the phone viewport.
private struct AnchoredPresetMenuLayout: Layout {
    let seatFrame: CGRect
    let viewport: CGSize

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        viewport
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        subviews[0].place(at: bounds.origin, anchor: .topLeading, proposal: ProposedViewSize(bounds.size))
        let margin = CGFloat(agentPresetMenuViewportMarginPoints)
        let width = min(CGFloat(agentPresetMenuMaxWidthPoints), max(0, bounds.width - 2 * margin))
        let maxHeight = CGFloat(agentPresetMenuMaxHeight(viewportHeight: Double(bounds.height)))
        let measured = subviews[1].sizeThatFits(ProposedViewSize(width: width, height: maxHeight))
        let height = min(measured.height, maxHeight)
        let origin = agentPresetMenuOrigin(
            seat: (Double(seatFrame.minX), Double(seatFrame.minY), Double(seatFrame.width), Double(seatFrame.height)),
            menuSize: (Double(width), Double(height)),
            viewport: (Double(bounds.width), Double(bounds.height))
        )
        subviews[1].place(
            at: CGPoint(x: bounds.minX + CGFloat(origin.x), y: bounds.minY + CGFloat(origin.y)),
            anchor: .topLeading, proposal: ProposedViewSize(width: width, height: height)
        )
    }
}
