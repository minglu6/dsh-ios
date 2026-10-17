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
                    .font(.system(size: CGFloat(workspaceChipFontSizePoints), weight: .medium))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: CGFloat(workspaceChipChevronSizePoints)))
                    .foregroundStyle(T.caption)
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
        .popover(
            isPresented: $open,
            attachmentAnchor: .rect(.bounds),
            arrowEdge: composerPickerPopoverOpensAbove ? .bottom : .top
        ) {
            VStack(alignment: .leading, spacing: 0) {
                if model.workspaces.isEmpty {
                    Text(workspacePickerLoading(english: L.en))
                        .font(.system(size: 12))
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
                                .font(.system(size: 13))
                                .foregroundStyle(T.ink)
                                .lineLimit(1)
                            Spacer(minLength: 8)
                            if selectedId == workspace.workspaceId {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(T.ink)
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
                            Image(systemName: D.plus)
                                .font(.system(size: CGFloat(workspaceChipIconSizePoints)))
                                .foregroundStyle(T.ink)
                            Text(addWorkspaceMenuLabel(english: L.en))
                                .font(.system(size: 13))
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

/// Desktop `AgentPresetSeat`: landing-only ghost chip, custom menu of name + description.
struct AgentPresetSeat: View {
    @ObservedObject var model: AppModel
    @State private var open = false

    private var rows: [JSONValue] {
        PresetPolicy.visibleRows(model.presetRoster, codingTools: model.showCodeWorkView)
    }

    private var currentId: String {
        let draft = model.draftPreset.trimmingCharacters(in: .whitespacesAndNewlines)
        if !draft.isEmpty { return draft }
        return rows.first { $0["isDefault"].bool() == true }?["id"].str()
            ?? rows.first?["id"].str()
            ?? ""
    }

    private var currentLabel: String {
        if let row = rows.first(where: { $0["id"].str() == currentId }) {
            return PresetPolicy.name(row, english: L.en)
        }
        return L.agentPresets()
    }

    var body: some View {
        if rows.isEmpty {
            EmptyView()
        } else {
            Button { if model.isOnline { open.toggle() } } label: {
                HStack(spacing: 4) {
                    OfficialGlyph(kind: .agentPreset, size: 14, color: T.ink)
                    Text(currentLabel)
                        .font(.system(size: CGFloat(agentPresetSeatFontSizePoints), weight: .medium))
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11))
                        .foregroundStyle(T.caption)
                        .rotationEffect(.degrees(open ? 180 : 0))
                }
                .foregroundStyle(T.ink)
                .padding(.horizontal, 8)
                .frame(minHeight: CGFloat(agentPresetSeatMinHeightPoints))
                .frame(maxWidth: CGFloat(agentPresetSeatMaxWidthPoints), alignment: .leading)
            }
            .buttonStyle(.plain)
            .disabled(!model.isOnline)
            .opacity(model.isOnline ? 1 : 0.45)
            .accessibilityLabel(currentLabel)
            .accessibilityHint(agentPresetSeatHint(english: L.en))
            .popover(
                isPresented: $open,
                attachmentAnchor: .rect(.bounds),
                arrowEdge: composerPickerPopoverOpensAbove ? .bottom : .top
            ) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        let id = row["id"].str() ?? ""
                        Button {
                            model.draftPreset = id
                            open = false
                        } label: {
                            HStack(alignment: .top, spacing: 8) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(PresetPolicy.name(row, english: L.en))
                                        .font(.system(size: 13))
                                        .foregroundStyle(T.ink)
                                    Text(PresetPolicy.description(row, english: L.en).flatMap { $0.isEmpty ? nil : $0 }
                                         ?? agentPresetNoDescription(english: L.en))
                                        .font(.system(size: 12))
                                        .foregroundStyle(T.caption)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 8)
                                if currentId == id {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(T.ink)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(CGFloat(permissionMenuPaddingPoints))
                .frame(minWidth: 156, maxWidth: 280)
                .modifier(PopoverCompactAdaptation())
            }
        }
    }
}
