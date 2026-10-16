import SwiftUI
import DSHProtocol

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
            .popover(isPresented: $open, attachmentAnchor: .rect(.bounds), arrowEdge: .bottom) {
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
                                    if let detail = PresetPolicy.description(row, english: L.en), !detail.isEmpty {
                                        Text(detail)
                                            .font(.system(size: 12))
                                            .foregroundStyle(T.caption)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
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
