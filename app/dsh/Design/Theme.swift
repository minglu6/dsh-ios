import SwiftUI
import DSHProtocol

enum Appearance: String, CaseIterable, Codable {
    case light, dark, system
}

enum AppLanguage: String, CaseIterable, Codable {
    case zh, en
}

enum BusySend: String, CaseIterable, Codable {
    case queue, steer
    var mode: String { rawValue }
}

enum PerformanceUsage: String, CaseIterable, Codable {
    case compact, detailed
}

enum SessionGroupBy: String, Codable { case workspace, workspaceTree, flat }
enum SessionOrderBy: String, Codable { case manual, updated }
enum ArchivedFilter: String, Codable { case hide, show, only }

final class ThemeState: ObservableObject {
    @Published var dark = false
    private var lastSystemDark = false
    var colors: DswColors { dark ? .dark : .light }

    func resolve(appearance: Appearance, systemDark: Bool) {
        lastSystemDark = systemDark
        switch appearance {
        case .dark: dark = true
        case .light: dark = false
        case .system: dark = systemDark
        }
    }

    /// Apply a local appearance tap without waiting for a SwiftUI `onChange` cycle.
    func applyAppearance(_ appearance: Appearance) {
        resolve(appearance: appearance, systemDark: lastSystemDark)
    }
}

/// App chrome tokens mapped from desktop `--dsw-alias-*` via [ThemeState].
enum T {
    static var colors: DswColors { ThemeStateHolder.shared.colors }
    static var ink: Color { colors.labelPrimary }
    static var accent: Color { colors.buttonInfoFill }
    /// Desktop `--dsw-alias-state-business-primary` (workspace folderActive).
    static var businessPrimary: Color { colors.stateBusinessPrimary }
    static var tint: Color { colors.stateBusinessTertiary }
    static var text2: Color { colors.labelSecondary }
    static var text3: Color { colors.labelTertiary }
    static var caption: Color { colors.labelCaption }
    static var fill: Color { colors.interactiveBgHoverSolid }
    /// Desktop `--dsw-specific-selector` (InputBar plus circle).
    static var selector: Color { colors.specificSelector }
    static var fill2: Color { colors.bgModulePlatform }
    static var drawer: Color { colors.specificSidebarFill }
    static var border: Color { colors.borderL2 }
    /// Desktop `--dsw-alias-border-l1` (`TurnTriggerNodeView` hairline,
    /// `ui-input-trigger` MenuView elevation stroke + crumbs).
    static var borderL1: Color { colors.borderL1 }
    /// Desktop `--dsw-alias-border-l3` (`Button.outline`, files header, ContextMeter track).
    static var borderL3: Color { colors.borderL3 }
    /// Desktop `--dsw-alias-turn-trigger-bg`.
    static var turnTriggerBg: Color {
        Color(hex: turnTriggerBackgroundHex(dark: ThemeStateHolder.shared.dark))
    }
    static var warnBorder: Color { colors.stateWarnSecondary }
    static var warnTint: Color { colors.stateWarnTertiary }
    static var warnText: Color { colors.stateWarnLabel }
    static var scrim: Color { colors.bgMask1 }
    static var bluish: Color { colors.labelPrimaryBluish }
    static var hoverBg: Color { colors.interactiveBgHover }
    static var interactiveBgActive: Color { colors.interactiveBgActive }
    static var tooltipBg: Color { colors.tooltipBg }
    /// Desktop `--dsw-static-neutral-bluish-00` on tooltip (always light).
    static var tooltipFg: Color { Color(hex: pluginInfoTooltipTextHex) }
    static var documentPreviewBg: Color { colors.bgDocumentPreview }
    static var ok: Color { colors.stateSuccessPrimary }
    static var err: Color { colors.stateErrorPrimary }
    static var bg: Color { colors.bgBase }
    static var surface: Color { colors.bgLayer1 }
    static var surface2: Color { colors.bgLayer2 }
    static var surface3: Color { colors.bgLayer3 }
    static var link: Color { colors.link }
    static var bubble: Color { colors.specificBubble }
    static var primaryButton: Color { colors.buttonPrimaryFill }
    static var onPrimary: Color { colors.labelPrimaryForeground }
    static var codeBlock: Color { colors.markdownCodeBlock }
    static var settingsCard: Color { colors.settingsCardFill }
    static var settingsCardStroke: Color { colors.settingsCardStroke }
    static var input: Color { colors.specificLoginInput }
    static var inputMajor: Color { colors.specificInputMajor }
    static var borderStrong: Color { colors.borderL4 }
    static var sidebarActive: Color { colors.specificSidebarNavItemActive }
    static var sidebarActiveAccent: Color { colors.specificSidebarNavItemActiveAccent }
    /// Desktop `ui-trajectory` `.assistantVioletBright` / `.contextGreen`.
    static var trajectoryAssistant: Color { Color(hex: trajectoryAssistantForegroundHex(dark: ThemeStateHolder.shared.dark)) }
    static var trajectoryAssistantBg: Color { Color(hex: trajectoryAssistantBackgroundHex(dark: ThemeStateHolder.shared.dark)) }
    static var trajectoryContext: Color { Color(hex: trajectoryContextForegroundHex(dark: ThemeStateHolder.shared.dark)) }
    static var trajectoryContextBg: Color { Color(hex: trajectoryContextBackgroundHex(dark: ThemeStateHolder.shared.dark)) }
}

enum ThemeStateHolder {
    static let shared = ThemeState()
}

func resolveDarkAppearance(_ appearance: Appearance, systemDark: Bool) -> Bool {
    switch appearance {
    case .dark: return true
    case .light: return false
    case .system: return systemDark
    }
}

/// Keep iPhone popovers as popovers (desktop usage / plugin (i) chrome).
struct PopoverCompactAdaptation: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.4, *) {
            content.presentationCompactAdaptation(.popover)
        } else {
            content
        }
    }
}
