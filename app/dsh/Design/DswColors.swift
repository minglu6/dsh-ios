import SwiftUI
import DSHProtocol

/// Desktop `--dsw-alias-*` tokens from `@deepseek-ai/dsh-client-ui-theme@0.2.1-alpha.5`.
struct DswColors {
    let bgBase: Color
    let bgLayer1: Color
    let bgLayer2: Color
    let bgLayer3: Color
    let bgModulePlatform: Color
    let bgMask1: Color
    let bgDocumentPreview: Color
    let borderL2: Color
    let borderL3: Color
    let borderL4: Color
    let brandPrimaryNew: Color
    let buttonInfoFill: Color
    let buttonPrimaryFill: Color
    let interactiveBgHover: Color
    let interactiveBgHoverSolid: Color
    let interactiveBgActive: Color
    let tooltipBg: Color
    let labelCaption: Color
    let labelPrimary: Color
    let labelPrimaryBluish: Color
    let labelPrimaryForeground: Color
    let labelSecondary: Color
    let labelTertiary: Color
    let link: Color
    let markdownCodeBlock: Color
    let settingsCardFill: Color
    let settingsCardStroke: Color
    /// Desktop `--dsw-alias-state-business-primary` (workspace `.folderActive`).
    let stateBusinessPrimary: Color
    let stateBusinessTertiary: Color
    let stateErrorPrimary: Color
    let stateSuccessPrimary: Color
    let stateWarnLabel: Color
    let stateWarnSecondary: Color
    let stateWarnTertiary: Color
    let specificBubble: Color
    let specificSelector: Color
    let specificInputMajor: Color
    let specificLoginInput: Color
    let specificSidebarFill: Color
    let specificSidebarNavItemActive: Color
    let specificSidebarNavItemActiveAccent: Color

    static let light = DswColors(
        bgBase: Color(hex: 0xFFFFFFFF),
        bgLayer1: Color(hex: 0xFFFFFFFF),
        bgLayer2: Color(hex: 0xFFFFFFFF),
        bgLayer3: Color(hex: 0xFFFFFFFF),
        bgModulePlatform: Color(hex: 0xFFF5F6F7),
        bgMask1: Color(hex: 0x3D000000),
        bgDocumentPreview: Color(hex: 0xFFEBEEF2),
        borderL2: Color(hex: 0x1A000000),
        borderL3: Color(hex: dswAliasBorderL3LightHex),
        borderL4: Color(hex: 0x29000000),
        brandPrimaryNew: Color(hex: 0xFF4176E6),
        buttonInfoFill: Color(hex: 0xFF4176E6),
        buttonPrimaryFill: Color(hex: 0xFF0F1115),
        interactiveBgHover: Color(hex: 0x0F263148),
        interactiveBgHoverSolid: Color(hex: 0xFFF1F3F5),
        interactiveBgActive: Color(hex: 0x1A263148),
        tooltipBg: Color(hex: 0xFF2C2C2E),
        labelCaption: Color(hex: 0xFFADB2B8),
        labelPrimary: Color(hex: 0xFF0F1115),
        labelPrimaryBluish: Color(hex: 0xFF0E3074),
        labelPrimaryForeground: Color(hex: 0xFFFFFFFF),
        labelSecondary: Color(hex: 0xFF61666B),
        labelTertiary: Color(hex: 0xFF81858C),
        link: Color(hex: 0xFF4176E6),
        markdownCodeBlock: Color(hex: 0xFFF9FAFB),
        settingsCardFill: Color(hex: 0xFFFFFFFF),
        settingsCardStroke: Color(hex: 0x29000000),
        stateBusinessPrimary: Color(hex: 0xFF4176E6),
        stateBusinessTertiary: Color(hex: 0xFFE4EDFD),
        stateErrorPrimary: Color(hex: 0xFFEC1313),
        stateSuccessPrimary: Color(hex: 0xFF22C55E),
        stateWarnLabel: Color(hex: 0xFFDD8629),
        stateWarnSecondary: Color(hex: 0xFFF7AD31),
        stateWarnTertiary: Color(hex: 0xFFFEF5E7),
        specificBubble: Color(hex: 0xFFEDF3FE),
        specificSelector: Color(hex: composerAddButtonSelectorLightHex),
        specificInputMajor: Color(hex: 0xFFFFFFFF),
        specificLoginInput: Color(hex: 0xFFF9FAFB),
        specificSidebarFill: Color(hex: 0xFFF9FAFB),
        specificSidebarNavItemActive: Color(hex: 0xFFEBEEF2),
        specificSidebarNavItemActiveAccent: Color(hex: 0xFFE4EDFD)
    )

    static let dark = DswColors(
        bgBase: Color(hex: 0xFF151517),
        bgLayer1: Color(hex: 0xFF232324),
        bgLayer2: Color(hex: 0xFF2C2C2E),
        bgLayer3: Color(hex: 0xFF353638),
        bgModulePlatform: Color(hex: 0xFF353638),
        bgMask1: Color(hex: 0x80000000),
        bgDocumentPreview: Color(hex: 0xFF151517),
        borderL2: Color(hex: 0x1FFFFFFF),
        borderL3: Color(hex: dswAliasBorderL3DarkHex),
        borderL4: Color(hex: 0x33FFFFFF),
        brandPrimaryNew: Color(hex: 0xFF5686FE),
        buttonInfoFill: Color(hex: 0xFF7AAAFF),
        buttonPrimaryFill: Color(hex: 0xFFF9FAFB),
        interactiveBgHover: Color(hex: 0x14FFFFFF),
        interactiveBgHoverSolid: Color(hex: 0xFF353638),
        interactiveBgActive: Color(hex: 0x24FFFFFF),
        tooltipBg: Color(hex: 0xFF43454A),
        labelCaption: Color(hex: 0xFF81858C),
        labelPrimary: Color(hex: 0xFFF9FAFB),
        labelPrimaryBluish: Color(hex: 0xFFF9FAFB),
        labelPrimaryForeground: Color(hex: 0xFF0F1115),
        labelSecondary: Color(hex: 0xFFCFD3D6),
        labelTertiary: Color(hex: 0xFFADB2B8),
        link: Color(hex: 0xFF7AAAFF),
        markdownCodeBlock: Color(hex: 0xFF1B1B1C),
        settingsCardFill: Color(hex: 0xFF2C2C2E),
        settingsCardStroke: Color(hex: 0x33FFFFFF),
        stateBusinessPrimary: Color(hex: 0xFF7AAAFF),
        stateBusinessTertiary: Color(hex: 0xFF34415B),
        stateErrorPrimary: Color(hex: 0xFFF25A5A),
        stateSuccessPrimary: Color(hex: 0xFF22C55E),
        stateWarnLabel: Color(hex: 0xFFDD8629),
        stateWarnSecondary: Color(hex: 0xFFF7AD31),
        stateWarnTertiary: Color(hex: 0xFF27241F),
        specificBubble: Color(hex: 0xFF2C2C2E),
        specificSelector: Color(hex: composerAddButtonSelectorDarkHex),
        specificInputMajor: Color(hex: 0xFF2C2C2E),
        specificLoginInput: Color(hex: 0xFF1B1B1C),
        specificSidebarFill: Color(hex: 0xFF1B1B1C),
        specificSidebarNavItemActive: Color(hex: 0xFF43454A),
        specificSidebarNavItemActiveAccent: Color(hex: 0xFF353638)
    )
}

extension Color {
    init(hex: UInt32) {
        let a = Double((hex >> 24) & 0xFF) / 255
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
