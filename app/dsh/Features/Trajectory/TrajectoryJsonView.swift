import SwiftUI
import UIKit
import DSHProtocol

struct TrajectoryJsonValue: View {
    let source: String
    var error: Bool = false

    @State private var expanded: Set<String> = [""]

    var body: some View {
        let document = trajectoryJsonDocument(source)
        let rows = document.root.map { trajectoryJsonRows($0, expanded: expanded) }
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                TrajectoryCopyButton(source: source, value: document.root)
            }
            if let rows {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    rowView(row)
                }
            } else {
                Text(source)
                    .font(LocalFonts.code())
                    .foregroundStyle(error ? T.err : T.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(error ? T.err.opacity(0.06) : T.fill2, in: RoundedRectangle(cornerRadius: 12))
        .onChange(of: source) { _ in expanded = [""] }
    }

    @ViewBuilder
    private func rowView(_ row: TrajectoryJsonRow) -> some View {
        let open = expanded.contains(row.path)
        HStack(alignment: .top, spacing: 0) {
            if row.expandable && !row.closing {
                Button {
                    if open { expanded.remove(row.path) } else { expanded.insert(row.path) }
                } label: {
                    OfficialGlyph(
                        kind: .chevronRight,
                        size: 10,
                        color: T.text3
                    )
                    .rotationEffect(.degrees(open ? trajectoryThinkingChevronExpandedRotationDegrees : 0))
                    .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .contain)
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(open ? L.t("收起", "Collapse") : L.t("展开", "Expand"))
            } else {
                Color.clear.frame(width: 28, height: 28)
            }
            Text(trajectoryJsonRowText(row, expanded: open))
                .font(LocalFonts.code())
                .foregroundStyle(error ? T.err : T.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
                .textSelection(.enabled)
            if !row.closing && !row.path.isEmpty {
                TrajectoryCopyButton(source: source, value: row.value, path: row.copyPath)
            }
        }
        .padding(.leading, CGFloat(min(row.depth, 10) * 10))
    }
}

private struct TrajectoryCopyButton: View {
    let source: String
    var value: JSONValue?
    var path: String = "$"

    @State private var copyResult: String?
    @State private var menu = false

    private var modes: [TrajectoryJsonCopyMode]? {
        value.map { trajectoryJsonCopyModes($0) }
    }

    var body: some View {
        Button {
            copy(modes?.first)
        } label: {
            OfficialGlyph(
                kind: copyResult == "复制成功" ? .checkOutline : .copyOutline,
                size: 12,
                color: T.text3
            )
            .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(copyResult ?? modes?.first?.label ?? L.copy())
        .simultaneousGesture(LongPressGesture().onEnded { _ in
            if modes != nil { menu = true }
        })
        .confirmationDialog(L.copy(), isPresented: $menu, titleVisibility: .hidden) {
            if let modes {
                ForEach(modes, id: \.self) { mode in
                    Button(mode.label) { copy(mode) }
                }
            }
            Button(L.cancel(), role: .cancel) {}
        }
        .onChange(of: copyResult) { value in
            guard value != nil else { return }
            Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                copyResult = nil
            }
        }
    }

    private func copy(_ mode: TrajectoryJsonCopyMode?) {
        menu = false
        let text: String
        if let value, let mode {
            text = trajectoryJsonCopyText(value, path: path, mode: mode)
        } else {
            text = source
        }
        UIPasteboard.general.string = text
        copyResult = "复制成功"
    }
}
