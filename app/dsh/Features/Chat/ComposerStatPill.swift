import SwiftUI
import DSHProtocol

/// Desktop PlainPill / DialogPill share their appearance, not their button trait.
struct ComposerStatPill<Icon: View>: View {
    let text: String
    let icon: Icon
    let clickable: Bool
    let open: Bool
    let restingInk: Color
    let activeInk: Color
    let activeBackground: Color
    let action: () -> Void

    var body: some View {
        if clickable {
            Button(action: action) { label }
                .buttonStyle(.plain)
        } else {
            label
        }
    }

    private var label: some View {
        HStack(spacing: CGFloat(composerStatisticsPillIconGapPoints)) {
            icon
            Text(text)
                .font(.system(size: CGFloat(composerStatisticsPillFontSizePoints)))
                .monospacedDigit()
                .lineLimit(1)
        }
        .foregroundStyle(open ? activeInk : restingInk)
        .frame(minHeight: CGFloat(composerStatisticsPillLineHeightPoints))
        .padding(.vertical, CGFloat(composerStatisticsPillPaddingVerticalPoints))
        .padding(.horizontal, CGFloat(composerStatisticsPillPaddingHorizontalPoints))
        .background(
            open ? activeBackground : Color.clear,
            in: RoundedRectangle(cornerRadius: CGFloat(composerStatisticsPillRadiusPoints), style: .circular)
        )
    }
}
