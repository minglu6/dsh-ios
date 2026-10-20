import SwiftUI
import DSHProtocol

/// Display-only Flash release marker. Matches desktop
/// `@deepseek-ai/dsh-client-ui-deepseek-model-label-1017` (`Tag` success tone)
/// and Android `ModelLabel`. The badge is never part of the model route.
struct ModelLabel: View {
    let name: String
    let badge: String?
    var color: Color = T.ink
    var font: Font = PhoneTypography.font(size: 13)
    var nameIdentifier: String? = nil

    var body: some View {
        HStack(spacing: CGFloat(modelReleaseBadgeGapPoints)) {
            Text(name)
                .font(font)
                .foregroundStyle(color)
                .lineLimit(1)
                .truncationMode(.tail)
                .modifier(OptionalAccessibilityIdentifier(nameIdentifier))
            if let badge {
                Text(badge)
                    .font(PhoneTypography.font(size: CGFloat(modelReleaseBadgeFontSizePoints), weight: .medium))
                    .foregroundStyle(T.ok)
                    .lineLimit(1)
                    .padding(.horizontal, CGFloat(modelReleaseBadgePaddingHorizontalPoints))
                    .padding(.vertical, CGFloat(modelReleaseBadgePaddingVerticalPoints))
                    .background(
                        T.ok.opacity(modelReleaseBadgeFillOpacity),
                        in: Capsule()
                    )
                    .fixedSize()
                    .layoutPriority(1)
                    .accessibilityHidden(true)
            }
        }
        .modifier(OptionalAccessibilityIdentifier(badge == nil ? nil : modelReleaseBadgeIdentifier()))
    }
}

private struct OptionalAccessibilityIdentifier: ViewModifier {
    let identifier: String?

    init(_ identifier: String?) {
        self.identifier = identifier
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        if let identifier {
            content.accessibilityIdentifier(identifier)
        } else {
            content
        }
    }
}
