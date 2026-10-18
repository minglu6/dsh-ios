import SwiftUI
import DSHProtocol

/// Desktop primitives permission / think / agent-preset artwork, 16×16 view box.
struct OfficialGlyph: View {
    enum Kind {
        case think
        case agentPreset
        case permission(String)
        case folderClose
        case folderOpen
        case folderOpenFill
        case keyboard
        case pinOutline
        case pinFill
        case archiveOutline
        case ellipsis
        case slidersTwo
        case workspaceTree
        case flatList
        case globe
        case clockOutline
        case chevronsUpDown
        case archiveOff
        case archiveCheck
        case queue
        case downloadOutline
        case terminalPrompt
        case settingsOutline
        case newChat
        case searchOutline
        case projectAdd
        case plusOutline
        case send
        case trajectoryClock
        case jobsChevron
        case gaugeOutline
        case databaseOutline
        case infoOutline
        case refreshOutline
        case fishLogo
        case userOutline
        case sparkle
        case toolWrench
        case information
        case compacted
        case settingsOutlineRegular
        case chevronDown
        case chevronUp
        case checkOutline
        case likeOutline
        case likeFill
        case dislikeOutline
        case dislikeFill
        case stopRect
        case panelLeft
        case panelRight
        case copyOutline
        case branchOutline
        case chevronLeft
        case chevronRight
        case closeOutline
        case linkOutline
        case rightUp
        case appearanceLight
        case appearanceDark
        case appearanceFollowSystem
        case browseOutline
        case editOutline
        case apiOutline
        case codeOutline
        case planOutline
        case questionOutline
        case usersOutline
        case checklistOutline
        case goalOutline
        case cordisPlugin
        case stopFill
        case computer
        case trashOutline
        case queueOutline
        case sendOutline
        case dataOutline
        case dataOutlineRegular
        case paperclipOutline
        case paperPlaneOutline
        case compactOutline
        case permissionFullAccess
        case warningOutline
        case warningTriangle
        case playOutline
        case pauseOutline

        var accessibilityIdentifier: String {
            switch self {
            case .folderClose: return "official.folderClose"
            case .folderOpen: return "official.folderOpen"
            case .folderOpenFill: return workspaceGroupFolderSymbol(collapsed: false)
            case .keyboard: return connectionsEnterAddressSymbol()
            case .settingsOutline: return "official.settingsOutline"
            case .newChat: return "official.newChat"
            case .searchOutline: return "official.searchOutline"
            case .projectAdd: return "official.projectAdd"
            case .plusOutline: return "official.plusOutline"
            case .send: return "official.send"
            case .trajectoryClock: return "official.trajectoryClock"
            case .jobsChevron: return "official.jobsChevron"
            case .slidersTwo: return viewOptionsTriggerOfficialIdentifier()
            case .workspaceTree: return viewOptionsOfficialIdentifier(.groupWorkspaceTree)
            case .flatList: return viewOptionsOfficialIdentifier(.groupFlat)
            case .clockOutline: return viewOptionsOfficialIdentifier(.orderUpdated)
            case .chevronsUpDown: return viewOptionsOfficialIdentifier(.orderManual)
            case .archiveOff: return viewOptionsOfficialIdentifier(.filterHide)
            case .archiveCheck: return viewOptionsOfficialIdentifier(.filterOnly)
            case .queue: return viewOptionsOfficialIdentifier(.filterShow)
            case .gaugeOutline: return composerActivityGaugeSymbol()
            case .databaseOutline: return composerUsageDatabaseSymbol()
            case .infoOutline: return "official.infoOutline"
            case .refreshOutline: return "official.refreshOutline"
            case .fishLogo: return landingHeroFishSymbol()
            case .userOutline: return "official.userOutline"
            case .sparkle: return "official.sparkle"
            case .toolWrench: return "official.toolWrench"
            case .information: return "official.information"
            case .compacted: return "official.compacted"
            case .settingsOutlineRegular: return "official.settingsOutlineRegular"
            case .chevronDown: return menuChevronDownSymbol()
            case .chevronUp: return menuChevronUpSymbol()
            case .checkOutline: return menuCheckSymbol()
            case .likeOutline: return messageLikeSymbol()
            case .likeFill: return messageLikeFillSymbol()
            case .dislikeOutline: return messageDislikeSymbol()
            case .dislikeFill: return messageDislikeFillSymbol()
            case .stopRect: return composerStopSymbol()
            case .panelLeft: return headerPanelLeftSymbol()
            case .panelRight: return headerPanelRightSymbol()
            case .copyOutline: return messageCopySymbol()
            case .branchOutline: return messageBranchSymbol()
            case .chevronLeft: return menuChevronLeftSymbol()
            case .chevronRight: return menuChevronRightSymbol()
            case .closeOutline: return browserCloseSymbol()
            case .linkOutline: return browserLinkSymbol()
            case .rightUp: return browserRightUpSymbol()
            case .appearanceLight: return appearanceLightSymbol()
            case .appearanceDark: return appearanceDarkSymbol()
            case .appearanceFollowSystem: return appearanceFollowSystemSymbol()
            case .think: return "official.think"
            case .agentPreset: return "official.agentPreset"
            case .globe: return "official.globeOutline"
            case .browseOutline: return "official.browseOutline"
            case .editOutline: return "official.editOutline"
            case .apiOutline: return "official.apiOutline"
            case .codeOutline: return "official.codeOutline"
            case .planOutline: return "official.planOutline"
            case .questionOutline: return "official.questionOutline"
            case .usersOutline: return "official.usersOutline"
            case .checklistOutline: return "official.checklistOutline"
            case .goalOutline: return "official.goalOutline"
            case .cordisPlugin: return "official.cordisPlugin"
            case .stopFill: return jobsStopFillSymbol()
            case .computer: return connectionsNearbyComputerSymbol()
            case .trashOutline: return connectionsManageTrashSymbol()
            case .queueOutline: return chatQueueDockSymbol()
            case .sendOutline: return queueSteerSendSymbol()
            case .dataOutline, .dataOutlineRegular: return settingsModelsSymbol()
            case .paperclipOutline: return commandMenuIconSymbol("file")
            case .paperPlaneOutline: return commandMenuIconSymbol("feedback")
            case .compactOutline: return commandMenuIconSymbol("compact")
            case .permissionFullAccess: return commandMenuIconSymbol("permission")
            case .downloadOutline: return commandMenuIconSymbol("export")
            case .warningOutline: return permissionRiskOfficialSymbol()
            case .warningTriangle: return documentPreviewWarningSymbol()
            case .playOutline: return filesAutoRefreshSymbol(enabled: false)
            case .pauseOutline: return filesAutoRefreshSymbol(enabled: true)
            case .permission: return "official.glyph"
            default: return "official.glyph"
            }
        }

        var hidesAccessibility: Bool {
            switch self {
            case .folderClose, .folderOpen, .folderOpenFill, .keyboard, .settingsOutline, .newChat, .searchOutline, .projectAdd, .trajectoryClock,
                 .slidersTwo, .workspaceTree, .flatList, .clockOutline, .chevronsUpDown, .archiveOff, .archiveCheck, .queue,
                 .gaugeOutline, .databaseOutline, .infoOutline, .refreshOutline, .jobsChevron, .fishLogo,
                 .userOutline, .sparkle, .toolWrench, .information, .compacted, .settingsOutlineRegular,
                 .chevronDown, .chevronUp, .checkOutline, .likeOutline, .likeFill, .dislikeOutline, .dislikeFill,
                 .stopRect, .panelLeft, .panelRight, .copyOutline, .branchOutline, .chevronLeft, .chevronRight,
                 .closeOutline, .linkOutline, .rightUp, .appearanceLight, .appearanceDark, .appearanceFollowSystem,
                 .think, .agentPreset, .globe, .browseOutline, .editOutline, .apiOutline, .codeOutline, .planOutline,
                 .questionOutline, .usersOutline, .checklistOutline, .goalOutline, .cordisPlugin, .stopFill,
                 .computer, .trashOutline, .queueOutline, .sendOutline, .dataOutline, .dataOutlineRegular,
                 .paperclipOutline, .paperPlaneOutline, .compactOutline, .permissionFullAccess,
                 .downloadOutline, .warningOutline, .warningTriangle, .playOutline, .pauseOutline:
                return false
            // plusOutline / send are decorative; ComposerView hosts own
            // official.plusOutline and official.send.
            default: return true
            }
        }
    }

    let kind: Kind
    var size: CGFloat = 14
    var color: Color = T.text3

    var body: some View {
        Canvas { context, canvas in
            var ctx = context
            switch kind {
            case .fishLogo:
                let scale = canvas.width / CGFloat(fishLogoViewBoxWidth)
                ctx.scaleBy(x: scale, y: scale)
            case .keyboard:
                let scale = min(canvas.width, canvas.height) / CGFloat(connectionsKeyboardViewBox)
                ctx.scaleBy(x: scale, y: scale)
            case .computer:
                let scale = min(canvas.width, canvas.height) / CGFloat(connectionsComputerViewBox)
                ctx.scaleBy(x: scale, y: scale)
            default:
                let scale = min(canvas.width, canvas.height) / 16
                ctx.scaleBy(x: scale, y: scale)
            }
            let stroke = StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round)
            switch kind {
            case .think:
                ctx.stroke(Path(SVGPath.cgPath(Self.thinkOrbitA)), with: .color(color), style: stroke)
                ctx.stroke(Path(SVGPath.cgPath(Self.thinkOrbitB)), with: .color(color), style: stroke)
                ctx.fill(Path(SVGPath.cgPath(Self.thinkCore)), with: .color(color))
            case .agentPreset:
                ctx.fill(Path(SVGPath.cgPath(Self.presetFill)), with: .color(color))
                ctx.stroke(Path(SVGPath.cgPath(Self.presetHead)), with: .color(color), style: stroke)
                ctx.stroke(Path(SVGPath.cgPath(Self.presetLeft)), with: .color(color), style: stroke)
                ctx.stroke(Path(SVGPath.cgPath(Self.presetRight)), with: .color(color), style: stroke)
            case .permission(let value):
                drawPermission(&ctx, value: value, color: color, stroke: stroke)
            case .folderClose:
                ctx.stroke(Path(SVGPath.cgPath(Self.folderCloseBody)), with: .color(color), style: stroke)
                ctx.stroke(Path(SVGPath.cgPath(Self.folderCloseLine)), with: .color(color), style: stroke)
            case .folderOpen:
                ctx.stroke(Path(SVGPath.cgPath(Self.folderOpenFront)), with: .color(color), style: stroke)
                ctx.stroke(Path(SVGPath.cgPath(Self.folderOpenBack)), with: .color(color), style: stroke)
            case .folderOpenFill:
                ctx.fill(
                    Path(SVGPath.cgPath(workspaceFolderOpenFillShadePath)),
                    with: .color(color.opacity(workspaceFolderOpenFillShadeOpacity))
                )
                ctx.fill(Path(SVGPath.cgPath(workspaceFolderOpenFillPocketPath)), with: .color(color))
                ctx.fill(Path(SVGPath.cgPath(workspaceFolderOpenFillTabPath)), with: .color(color))
            case .keyboard:
                ctx.fill(
                    Path(SVGPath.cgPath(connectionsKeyboardFramePath)),
                    with: .color(color),
                    style: FillStyle(eoFill: true)
                )
                for key in connectionsKeyboardKeyPaths {
                    ctx.fill(Path(SVGPath.cgPath(key)), with: .color(color))
                }
            case .computer:
                ctx.fill(
                    Path(SVGPath.cgPath(connectionsComputerPath)),
                    with: .color(color),
                    style: FillStyle(eoFill: true)
                )
            case .pinOutline, .pinFill:
                ctx.stroke(Path(SVGPath.cgPath(Self.pinBody)), with: .color(color), style: stroke)
                ctx.stroke(Path(SVGPath.cgPath(Self.pinNeedle)), with: .color(color), style: stroke)
            case .archiveOutline:
                ctx.stroke(Path(SVGPath.cgPath(Self.archiveLid)), with: .color(color), style: stroke)
                ctx.stroke(Path(SVGPath.cgPath(Self.archiveBox)), with: .color(color), style: stroke)
                ctx.stroke(Path(SVGPath.cgPath(Self.archiveSlot)), with: .color(color), style: stroke)
            case .ellipsis:
                ctx.fill(Path(SVGPath.cgPath(Self.ellipsisA)), with: .color(color))
                ctx.fill(Path(SVGPath.cgPath(Self.ellipsisB)), with: .color(color))
                ctx.fill(Path(SVGPath.cgPath(Self.ellipsisC)), with: .color(color))
            case .slidersTwo:
                ctx.stroke(Path(SVGPath.cgPath(Self.slidersA)), with: .color(color), style: stroke)
                ctx.stroke(Path(SVGPath.cgPath(Self.slidersB)), with: .color(color), style: stroke)
                let knobR = CGFloat(viewOptionsSlidersKnobRadius)
                var topKnob = Path()
                topKnob.addEllipse(in: CGRect(
                    x: CGFloat(viewOptionsSlidersKnobTopCenterX) - knobR,
                    y: CGFloat(viewOptionsSlidersKnobTopCenterY) - knobR,
                    width: knobR * 2,
                    height: knobR * 2
                ))
                var bottomKnob = Path()
                bottomKnob.addEllipse(in: CGRect(
                    x: CGFloat(viewOptionsSlidersKnobBottomCenterX) - knobR,
                    y: CGFloat(viewOptionsSlidersKnobBottomCenterY) - knobR,
                    width: knobR * 2,
                    height: knobR * 2
                ))
                ctx.stroke(topKnob, with: .color(color), style: stroke)
                ctx.stroke(bottomKnob, with: .color(color), style: stroke)
            case .workspaceTree:
                ctx.stroke(Path(SVGPath.cgPath(Self.workspaceTreeBody)), with: .color(color), style: stroke)
                ctx.stroke(Path(SVGPath.cgPath(Self.workspaceTreeLegs)), with: .color(color), style: stroke)
            case .flatList:
                ctx.stroke(Path(SVGPath.cgPath(Self.flatListRows)), with: .color(color), style: stroke)
                ctx.stroke(Path(SVGPath.cgPath(Self.flatListDots)), with: .color(color), style: stroke)
            case .globe:
                ctx.stroke(Path(SVGPath.cgPath(Self.globeRim)), with: .color(color), style: stroke)
                ctx.stroke(Path(SVGPath.cgPath(Self.globeEquator)), with: .color(color), style: stroke)
                ctx.stroke(Path(SVGPath.cgPath(Self.globeMeridianA)), with: .color(color), style: stroke)
                ctx.stroke(Path(SVGPath.cgPath(Self.globeMeridianB)), with: .color(color), style: stroke)
            case .clockOutline:
                ctx.stroke(Path(SVGPath.cgPath(Self.clockRim)), with: .color(color), style: stroke)
                ctx.stroke(Path(SVGPath.cgPath(Self.clockHands)), with: .color(color), style: stroke)
            case .chevronsUpDown:
                ctx.stroke(Path(SVGPath.cgPath(Self.chevronsUp)), with: .color(color), style: stroke)
                ctx.stroke(Path(SVGPath.cgPath(Self.chevronsDown)), with: .color(color), style: stroke)
            case .archiveOff:
                var lid = Path()
                lid.addRoundedRect(
                    in: CGRect(x: 1.9, y: 2.1, width: 12.2, height: 3.4),
                    cornerSize: CGSize(width: 1.1, height: 1.1)
                )
                ctx.stroke(lid, with: .color(color), style: stroke)
                ctx.stroke(Path(SVGPath.cgPath(Self.archiveOffBox)), with: .color(color), style: stroke)
                ctx.stroke(Path(SVGPath.cgPath(Self.archiveOffSlash)), with: .color(color), style: stroke)
            case .archiveCheck:
                var lid = Path()
                lid.addRoundedRect(
                    in: CGRect(x: 1.9, y: 2.1, width: 12.2, height: 3.4),
                    cornerSize: CGSize(width: 1.1, height: 1.1)
                )
                ctx.stroke(lid, with: .color(color), style: stroke)
                ctx.stroke(Path(SVGPath.cgPath(Self.archiveOffBox)), with: .color(color), style: stroke)
                ctx.stroke(Path(SVGPath.cgPath(Self.archiveCheckMark)), with: .color(color), style: stroke)
            case .queue, .queueOutline:
                ctx.stroke(Path(SVGPath.cgPath(Self.queueLineA)), with: .color(color), style: stroke)
                ctx.stroke(Path(SVGPath.cgPath(Self.queueLineB)), with: .color(color), style: stroke)
                ctx.stroke(Path(SVGPath.cgPath(Self.queueBubble)), with: .color(color), style: stroke)
            case .downloadOutline:
                ctx.stroke(Path(SVGPath.cgPath(Self.downloadStem)), with: .color(color), style: stroke)
                ctx.stroke(Path(SVGPath.cgPath(Self.downloadArrow)), with: .color(color), style: stroke)
                ctx.stroke(Path(SVGPath.cgPath(Self.downloadTray)), with: .color(color), style: stroke)
            case .terminalPrompt:
                let term = StrokeStyle(lineWidth: 1.55, lineCap: .round, lineJoin: .round)
                ctx.scaleBy(x: 16 / 36, y: 16 / 36)
                ctx.stroke(Path(SVGPath.cgPath(Self.terminalPrompt)), with: .color(color), style: term)
                ctx.stroke(Path(SVGPath.cgPath(Self.terminalCursor)), with: .color(color), style: term)
            case .settingsOutline:
                let medium = StrokeStyle(
                    lineWidth: CGFloat(sidebarSettingsTriggerIconStrokeWidth),
                    lineCap: .butt,
                    lineJoin: .miter,
                    miterLimit: 10
                )
                ctx.stroke(Path(SVGPath.cgPath(sidebarSettingsOutlineHubPath)), with: .color(color), style: medium)
                ctx.stroke(Path(SVGPath.cgPath(sidebarSettingsOutlineRingPath)), with: .color(color), style: medium)
            case .newChat:
                let regular = StrokeStyle(
                    lineWidth: CGFloat(sidebarNewChatIconStrokeWidth),
                    lineCap: .butt,
                    lineJoin: .miter,
                    miterLimit: 10
                )
                ctx.stroke(Path(SVGPath.cgPath(sidebarNewChatBubblePath)), with: .color(color), style: regular)
                ctx.stroke(Path(SVGPath.cgPath(sidebarNewChatPlusVerticalPath)), with: .color(color), style: regular)
                ctx.stroke(Path(SVGPath.cgPath(sidebarNewChatPlusHorizontalPath)), with: .color(color), style: regular)
            case .searchOutline:
                let regular = StrokeStyle(
                    lineWidth: CGFloat(sidebarSearchIconStrokeWidth),
                    lineCap: .butt,
                    lineJoin: .miter,
                    miterLimit: 10
                )
                ctx.stroke(Path(SVGPath.cgPath(sidebarSearchCirclePath)), with: .color(color), style: regular)
                ctx.stroke(Path(SVGPath.cgPath(sidebarSearchHandlePath)), with: .color(color), style: regular)
            case .projectAdd:
                let regular = StrokeStyle(
                    lineWidth: CGFloat(sidebarProjectAddIconStrokeWidth),
                    lineCap: .butt,
                    lineJoin: .miter,
                    miterLimit: 10
                )
                ctx.fill(Path(SVGPath.cgPath(sidebarProjectAddFolderPath)), with: .color(color))
                ctx.stroke(Path(SVGPath.cgPath(sidebarProjectAddPlusHorizontalPath)), with: .color(color), style: regular)
                ctx.stroke(Path(SVGPath.cgPath(sidebarProjectAddPlusVerticalPath)), with: .color(color), style: regular)
            case .plusOutline:
                let medium = StrokeStyle(
                    lineWidth: CGFloat(composerAddIconStrokeWidth),
                    lineCap: .butt,
                    lineJoin: .miter,
                    miterLimit: 10
                )
                ctx.stroke(Path(SVGPath.cgPath(composerAddPlusVerticalPath)), with: .color(color), style: medium)
                ctx.stroke(Path(SVGPath.cgPath(composerAddPlusHorizontalPath)), with: .color(color), style: medium)
            case .send:
                ctx.fill(Path(SVGPath.cgPath(composerSendPath)), with: .color(color))
            case .trajectoryClock:
                let toolbar = StrokeStyle(
                    lineWidth: CGFloat(trajectoryToolbarClockIconUserStrokeWidth),
                    lineCap: .round,
                    lineJoin: .round
                )
                var rim = Path()
                let radius = CGFloat(trajectoryToolbarClockCircleRadius)
                let origin = CGPoint(
                    x: CGFloat(trajectoryToolbarClockCircleCenterX) - radius,
                    y: CGFloat(trajectoryToolbarClockCircleCenterY) - radius
                )
                rim.addEllipse(in: CGRect(origin: origin, size: CGSize(width: radius * 2, height: radius * 2)))
                ctx.stroke(rim, with: .color(color), style: toolbar)
                ctx.stroke(Path(SVGPath.cgPath(trajectoryToolbarClockHandsPath)), with: .color(color), style: toolbar)
            case .jobsChevron:
                let regular = StrokeStyle(
                    lineWidth: CGFloat(jobsActionTriggerIconStrokeWidth),
                    lineCap: .butt,
                    lineJoin: .miter,
                    miterLimit: 10
                )
                ctx.stroke(Path(SVGPath.cgPath(jobsActionTriggerChevronPath)), with: .color(color), style: regular)
            case .gaugeOutline:
                ctx.stroke(Path(SVGPath.cgPath(composerActivityGaugeArcPath)), with: .color(color), style: stroke)
                ctx.stroke(Path(SVGPath.cgPath(composerActivityGaugeNeedlePath)), with: .color(color), style: stroke)
                ctx.fill(Path(SVGPath.cgPath(composerActivityGaugeHubPath)), with: .color(color))
            case .databaseOutline:
                ctx.stroke(Path(SVGPath.cgPath(composerUsageDatabaseTopPath)), with: .color(color), style: stroke)
                ctx.stroke(Path(SVGPath.cgPath(composerUsageDatabaseLeftPath)), with: .color(color), style: stroke)
                ctx.stroke(Path(SVGPath.cgPath(composerUsageDatabaseRightPath)), with: .color(color), style: stroke)
                ctx.stroke(Path(SVGPath.cgPath(composerUsageDatabaseMidPath)), with: .color(color), style: stroke)
                ctx.stroke(Path(SVGPath.cgPath(composerUsageDatabaseBottomPath)), with: .color(color), style: stroke)
            case .infoOutline:
                ctx.scaleBy(x: 16 / CGFloat(pluginInfoIconViewBox), y: 16 / CGFloat(pluginInfoIconViewBox))
                ctx.fill(Path(SVGPath.cgPath(pluginInfoOutlineRingPath)), with: .color(color))
                ctx.fill(Path(SVGPath.cgPath(pluginInfoOutlineDotPath)), with: .color(color))
                ctx.fill(Path(SVGPath.cgPath(pluginInfoOutlineStemPath)), with: .color(color))
            case .refreshOutline:
                ctx.stroke(Path(SVGPath.cgPath(pluginRefreshOutlineArcPath)), with: .color(color), style: stroke)
                ctx.stroke(Path(SVGPath.cgPath(pluginRefreshOutlineHeadPath)), with: .color(color), style: stroke)
            case .fishLogo:
                ctx.fill(Path(SVGPath.cgPath(fishLogoPath)), with: .color(color))
            case .userOutline:
                let regular = StrokeStyle(
                    lineWidth: CGFloat(trajectoryKindIconStrokeWidth),
                    lineCap: .butt,
                    lineJoin: .miter,
                    miterLimit: 10
                )
                ctx.stroke(Path(SVGPath.cgPath(trajectoryUserHeadPath)), with: .color(color), style: regular)
                ctx.stroke(Path(SVGPath.cgPath(trajectoryUserShoulderPath)), with: .color(color), style: regular)
            case .sparkle:
                let regular = StrokeStyle(
                    lineWidth: CGFloat(trajectoryKindIconStrokeWidth),
                    lineCap: .butt,
                    lineJoin: .miter,
                    miterLimit: 10
                )
                ctx.stroke(Path(SVGPath.cgPath(trajectorySparkleLargePath)), with: .color(color), style: regular)
                ctx.stroke(Path(SVGPath.cgPath(trajectorySparkleMediumPath)), with: .color(color), style: regular)
                ctx.stroke(Path(SVGPath.cgPath(trajectorySparkleSmallPath)), with: .color(color), style: regular)
            case .toolWrench:
                let wrench = StrokeStyle(
                    lineWidth: CGFloat(trajectoryToolWrenchStrokeWidth),
                    lineCap: .round,
                    lineJoin: .round
                )
                ctx.stroke(Path(SVGPath.cgPath(trajectoryToolWrenchPath)), with: .color(color), style: wrench)
            case .information:
                let ring = StrokeStyle(
                    lineWidth: CGFloat(trajectoryInformationStrokeWidth),
                    lineCap: .round,
                    lineJoin: .round
                )
                let stem = StrokeStyle(
                    lineWidth: CGFloat(trajectoryInformationStemStrokeWidth),
                    lineCap: .round,
                    lineJoin: .round
                )
                let cx = CGFloat(trajectoryInformationCircleCenter)
                let cr = CGFloat(trajectoryInformationCircleRadius)
                var circle = Path()
                circle.addEllipse(in: CGRect(x: cx - cr, y: cx - cr, width: cr * 2, height: cr * 2))
                ctx.stroke(circle, with: .color(color), style: ring)
                let dx = CGFloat(trajectoryInformationDotCenterX)
                let dy = CGFloat(trajectoryInformationDotCenterY)
                let dr = CGFloat(trajectoryInformationDotRadius)
                var dot = Path()
                dot.addEllipse(in: CGRect(x: dx - dr, y: dy - dr, width: dr * 2, height: dr * 2))
                ctx.fill(dot, with: .color(color))
                ctx.stroke(Path(SVGPath.cgPath(trajectoryInformationStemPath)), with: .color(color), style: stem)
            case .compacted:
                let compacted = StrokeStyle(
                    lineWidth: CGFloat(trajectoryCompactedStrokeWidth),
                    lineCap: .round,
                    lineJoin: .round
                )
                ctx.stroke(Path(SVGPath.cgPath(trajectoryCompactedTopLeftPath)), with: .color(color), style: compacted)
                ctx.stroke(Path(SVGPath.cgPath(trajectoryCompactedTopRightPath)), with: .color(color), style: compacted)
                ctx.stroke(Path(SVGPath.cgPath(trajectoryCompactedBottomLeftPath)), with: .color(color), style: compacted)
                ctx.stroke(Path(SVGPath.cgPath(trajectoryCompactedBottomRightPath)), with: .color(color), style: compacted)
            case .settingsOutlineRegular:
                let regular = StrokeStyle(
                    lineWidth: CGFloat(trajectoryKindIconStrokeWidth),
                    lineCap: .butt,
                    lineJoin: .miter,
                    miterLimit: 10
                )
                ctx.stroke(Path(SVGPath.cgPath(sidebarSettingsOutlineHubPath)), with: .color(color), style: regular)
                ctx.stroke(Path(SVGPath.cgPath(sidebarSettingsOutlineRingPath)), with: .color(color), style: regular)
            case .chevronDown:
                ctx.stroke(Path(SVGPath.cgPath(jobsActionTriggerChevronPath)), with: .color(color), style: stroke)
            case .chevronUp:
                ctx.stroke(Path(SVGPath.cgPath(menuChevronUpPath)), with: .color(color), style: stroke)
            case .checkOutline:
                ctx.stroke(Path(SVGPath.cgPath(menuCheckOutlinePath)), with: .color(color), style: stroke)
            case .likeOutline:
                ctx.stroke(Path(SVGPath.cgPath(messageLikePath)), with: .color(color), style: stroke)
            case .likeFill:
                ctx.fill(Path(SVGPath.cgPath(messageLikePath)), with: .color(color))
                ctx.stroke(Path(SVGPath.cgPath(messageLikePath)), with: .color(color), style: stroke)
            case .dislikeOutline:
                ctx.stroke(Path(SVGPath.cgPath(messageDislikePath)), with: .color(color), style: stroke)
            case .dislikeFill:
                ctx.fill(Path(SVGPath.cgPath(messageDislikePath)), with: .color(color))
                ctx.stroke(Path(SVGPath.cgPath(messageDislikePath)), with: .color(color), style: stroke)
            case .stopRect:
                let rect = CGRect(
                    x: CGFloat(composerStopRectX),
                    y: CGFloat(composerStopRectY),
                    width: CGFloat(composerStopRectWidth),
                    height: CGFloat(composerStopRectHeight)
                )
                ctx.fill(
                    Path(roundedRect: rect, cornerRadius: CGFloat(composerStopRectRadius)),
                    with: .color(color)
                )
            case .panelLeft:
                drawPanelLeft(&ctx, color: color, stroke: stroke)
            case .panelRight:
                ctx.translateBy(x: 16, y: 0)
                ctx.scaleBy(x: -1, y: 1)
                drawPanelLeft(&ctx, color: color, stroke: stroke)
            case .copyOutline:
                let copyRect = CGRect(
                    x: CGFloat(messageCopyRectX),
                    y: CGFloat(messageCopyRectY),
                    width: CGFloat(messageCopyRectWidth),
                    height: CGFloat(messageCopyRectHeight)
                )
                ctx.stroke(
                    Path(roundedRect: copyRect, cornerRadius: CGFloat(messageCopyRectRadius)),
                    with: .color(color),
                    style: stroke
                )
                ctx.fill(Path(SVGPath.cgPath(messageCopyBackPath)), with: .color(color))
            case .branchOutline:
                ctx.stroke(Path(SVGPath.cgPath(messageBranchUpperPath)), with: .color(color), style: stroke)
                ctx.stroke(Path(SVGPath.cgPath(messageBranchLowerPath)), with: .color(color), style: stroke)
                let r = CGFloat(messageBranchCircleRadius)
                let cx = CGFloat(messageBranchCircleCenterX)
                var top = Path()
                top.addEllipse(in: CGRect(
                    x: cx - r,
                    y: CGFloat(messageBranchCircleTopY) - r,
                    width: r * 2,
                    height: r * 2
                ))
                var bottom = Path()
                bottom.addEllipse(in: CGRect(
                    x: cx - r,
                    y: CGFloat(messageBranchCircleBottomY) - r,
                    width: r * 2,
                    height: r * 2
                ))
                ctx.stroke(top, with: .color(color), style: stroke)
                ctx.stroke(bottom, with: .color(color), style: stroke)
            case .chevronLeft:
                ctx.stroke(Path(SVGPath.cgPath(menuChevronLeftPath)), with: .color(color), style: stroke)
            case .chevronRight:
                ctx.stroke(Path(SVGPath.cgPath(menuChevronRightPath)), with: .color(color), style: stroke)
            case .closeOutline:
                ctx.stroke(Path(SVGPath.cgPath(browserCloseOutlineAPath)), with: .color(color), style: stroke)
                ctx.stroke(Path(SVGPath.cgPath(browserCloseOutlineBPath)), with: .color(color), style: stroke)
            case .linkOutline:
                ctx.stroke(Path(SVGPath.cgPath(browserLinkOutlineAPath)), with: .color(color), style: stroke)
                ctx.stroke(Path(SVGPath.cgPath(browserLinkOutlineBPath)), with: .color(color), style: stroke)
            case .rightUp:
                ctx.fill(Path(SVGPath.cgPath(browserRightUpFillPath)), with: .color(color))
                ctx.stroke(Path(SVGPath.cgPath(browserRightUpStrokePath)), with: .color(color), style: stroke)
            case .appearanceLight:
                let medium = StrokeStyle(
                    lineWidth: CGFloat(appearanceCubeIconStrokeWidth),
                    lineCap: .butt,
                    lineJoin: .miter,
                    miterLimit: 10
                )
                ctx.stroke(Path(SVGPath.cgPath(appearanceLightCorePath)), with: .color(color), style: medium)
                for ray in appearanceLightRayPaths {
                    ctx.stroke(Path(SVGPath.cgPath(ray)), with: .color(color), style: medium)
                }
            case .appearanceDark:
                let medium = StrokeStyle(
                    lineWidth: CGFloat(appearanceCubeIconStrokeWidth),
                    lineCap: .butt,
                    lineJoin: .miter,
                    miterLimit: 10
                )
                ctx.stroke(Path(SVGPath.cgPath(appearanceDarkPath)), with: .color(color), style: medium)
            case .appearanceFollowSystem:
                let medium = StrokeStyle(
                    lineWidth: CGFloat(appearanceCubeIconStrokeWidth),
                    lineCap: .butt,
                    lineJoin: .miter,
                    miterLimit: 10
                )
                ctx.stroke(Path(SVGPath.cgPath(appearanceFollowSystemScreenPath)), with: .color(color), style: medium)
                ctx.stroke(Path(SVGPath.cgPath(appearanceFollowSystemStandPath)), with: .color(color), style: medium)
            case .browseOutline:
                let regular = Self.regularStroke
                ctx.fill(Path(SVGPath.cgPath(chatBrowsePagePath)), with: .color(color))
                ctx.stroke(Path(SVGPath.cgPath(chatBrowseCaptionTopPath)), with: .color(color), style: regular)
                ctx.stroke(Path(SVGPath.cgPath(chatBrowseCaptionMidPath)), with: .color(color), style: regular)
            case .editOutline:
                ctx.fill(Path(SVGPath.cgPath(chatEditPagePath)), with: .color(color))
                ctx.stroke(Path(SVGPath.cgPath(chatEditStrokePath)), with: .color(color), style: Self.regularStroke)
            case .apiOutline:
                ctx.stroke(Path(SVGPath.cgPath(chatApiChevronPath)), with: .color(color), style: Self.regularStroke)
                ctx.stroke(Path(SVGPath.cgPath(chatApiBarPath)), with: .color(color), style: Self.regularStroke)
            case .codeOutline:
                ctx.stroke(Path(SVGPath.cgPath(chatCodeSlashLeftPath)), with: .color(color), style: Self.regularStroke)
                ctx.stroke(Path(SVGPath.cgPath(chatCodeSlashRightPath)), with: .color(color), style: Self.regularStroke)
                ctx.stroke(Path(SVGPath.cgPath(chatCodeRuleTopPath)), with: .color(color), style: Self.regularStroke)
                ctx.stroke(Path(SVGPath.cgPath(chatCodeRuleBottomPath)), with: .color(color), style: Self.regularStroke)
            case .planOutline:
                ctx.fill(Path(SVGPath.cgPath(chatPlanPagePath)), with: .color(color))
                ctx.fill(Path(SVGPath.cgPath(chatPlanPencilPath)), with: .color(color))
                ctx.fill(Path(SVGPath.cgPath(chatPlanPencilBasePath)), with: .color(color))
                ctx.stroke(Path(SVGPath.cgPath(chatPlanCaptionTopPath)), with: .color(color), style: Self.regularStroke)
                ctx.stroke(Path(SVGPath.cgPath(chatPlanCaptionMidPath)), with: .color(color), style: Self.regularStroke)
            case .questionOutline:
                ctx.stroke(Path(SVGPath.cgPath(chatQuestionRingPath)), with: .color(color), style: Self.regularStroke)
                ctx.stroke(Path(SVGPath.cgPath(chatQuestionHookPath)), with: .color(color), style: Self.regularStroke)
                ctx.stroke(Path(SVGPath.cgPath(chatQuestionDotPath)), with: .color(color), style: Self.regularStroke)
            case .usersOutline:
                ctx.stroke(Path(SVGPath.cgPath(chatUsersHeadPath)), with: .color(color), style: Self.regularStroke)
                ctx.stroke(Path(SVGPath.cgPath(chatUsersShoulderPath)), with: .color(color), style: Self.regularStroke)
                ctx.stroke(Path(SVGPath.cgPath(chatUsersRearHeadPath)), with: .color(color), style: Self.regularStroke)
                ctx.stroke(Path(SVGPath.cgPath(chatUsersRearShoulderPath)), with: .color(color), style: Self.regularStroke)
            case .checklistOutline:
                ctx.stroke(Path(SVGPath.cgPath(chatChecklistDotTopPath)), with: .color(color), style: Self.regularStroke)
                ctx.stroke(Path(SVGPath.cgPath(chatChecklistLineTopPath)), with: .color(color), style: Self.regularStroke)
                ctx.stroke(Path(SVGPath.cgPath(chatChecklistDotBottomPath)), with: .color(color), style: Self.regularStroke)
                ctx.stroke(Path(SVGPath.cgPath(chatChecklistLineBottomPath)), with: .color(color), style: Self.regularStroke)
            case .goalOutline:
                ctx.stroke(Path(SVGPath.cgPath(chatGoalOuterArcPath)), with: .color(color), style: Self.regularStroke)
                ctx.stroke(Path(SVGPath.cgPath(chatGoalInnerArcPath)), with: .color(color), style: Self.regularStroke)
                ctx.stroke(Path(SVGPath.cgPath(chatGoalPointerPath)), with: .color(color), style: Self.regularStroke)
                ctx.stroke(Path(SVGPath.cgPath(chatGoalFlagPath)), with: .color(color), style: Self.regularStroke)
            case .cordisPlugin:
                ctx.fill(Path(SVGPath.cgPath(chatCordisPluginFillPath)), with: .color(color))
                let r = CGFloat(chatCordisPluginCircleRadius)
                let c = CGFloat(chatCordisPluginCircleCenter)
                var ring = Path()
                ring.addEllipse(in: CGRect(x: c - r, y: c - r, width: r * 2, height: r * 2))
                ctx.stroke(ring, with: .color(color), style: Self.regularStroke)
            case .stopFill:
                ctx.fill(Path(SVGPath.cgPath(jobsStopFillPath)), with: .color(color))
            case .trashOutline:
                ctx.stroke(Path(SVGPath.cgPath(iconTrashOutlineLidPath)), with: .color(color), style: Self.regularStroke)
                ctx.stroke(Path(SVGPath.cgPath(iconTrashOutlineHandlePath)), with: .color(color), style: Self.regularStroke)
                ctx.stroke(Path(SVGPath.cgPath(iconTrashOutlineBodyPath)), with: .color(color), style: Self.regularStroke)
                ctx.stroke(Path(SVGPath.cgPath(iconTrashOutlineLeftRibPath)), with: .color(color), style: Self.regularStroke)
                ctx.stroke(Path(SVGPath.cgPath(iconTrashOutlineRightRibPath)), with: .color(color), style: Self.regularStroke)
            case .sendOutline:
                ctx.fill(Path(SVGPath.cgPath(queueSteerSendFillPath)), with: .color(color))
                ctx.stroke(Path(SVGPath.cgPath(queueSteerSendStemPath)), with: .color(color), style: Self.regularStroke)
            case .dataOutline:
                drawDataOutline(&ctx, color: color, strokeWidth: CGFloat(appearanceCubeIconStrokeWidth))
            case .dataOutlineRegular:
                drawDataOutline(&ctx, color: color, strokeWidth: CGFloat(commandMenuIconStrokeWidth))
            case .paperclipOutline:
                ctx.stroke(Path(SVGPath.cgPath(iconPaperclipOutlinePath)), with: .color(color), style: Self.regularStroke)
            case .paperPlaneOutline:
                ctx.stroke(Path(SVGPath.cgPath(iconPaperPlaneOutlineBodyPath)), with: .color(color), style: Self.regularStroke)
                ctx.stroke(Path(SVGPath.cgPath(iconPaperPlaneOutlineFoldPath)), with: .color(color), style: Self.regularStroke)
            case .compactOutline:
                ctx.stroke(
                    Path(SVGPath.cgPath(iconCompactOutlineRingPath)),
                    with: .color(color.opacity(iconCompactOutlineRingOpacity)),
                    style: Self.regularStroke
                )
                ctx.stroke(Path(SVGPath.cgPath(iconCompactOutlineArcPath)), with: .color(color), style: Self.regularStroke)
            case .permissionFullAccess:
                drawPermission(&ctx, value: "danger-full-access", color: color, stroke: stroke)
            case .warningOutline:
                ctx.stroke(Path(SVGPath.cgPath(iconWarningOutlineRingPath)), with: .color(color), style: Self.regularStroke)
                ctx.stroke(Path(SVGPath.cgPath(iconWarningOutlineStemPath)), with: .color(color), style: Self.regularStroke)
                ctx.stroke(Path(SVGPath.cgPath(iconWarningOutlineDotPath)), with: .color(color), style: Self.regularStroke)
            case .warningTriangle:
                let round = StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round)
                ctx.stroke(Path(SVGPath.cgPath(iconWarningTriangleOutlinePath)), with: .color(color), style: round)
                ctx.stroke(Path(SVGPath.cgPath(iconWarningTriangleBangPath)), with: .color(color), style: round)
            case .playOutline:
                ctx.stroke(Path(SVGPath.cgPath(iconWarningOutlineRingPath)), with: .color(color), style: Self.regularStroke)
                ctx.stroke(Path(SVGPath.cgPath(iconPlayOutlineTrianglePath)), with: .color(color), style: Self.regularStroke)
            case .pauseOutline:
                ctx.stroke(Path(SVGPath.cgPath(iconWarningOutlineRingPath)), with: .color(color), style: Self.regularStroke)
                ctx.stroke(Path(SVGPath.cgPath(iconPauseOutlineLeftPath)), with: .color(color), style: Self.regularStroke)
                ctx.stroke(Path(SVGPath.cgPath(iconPauseOutlineRightPath)), with: .color(color), style: Self.regularStroke)
            }
        }
        .frame(width: canvasWidth, height: canvasHeight)
        .modifier(OfficialGlyphAccess(kind: kind))
    }

    /// HeroFish `size` is width; height keeps FISH_LOGO_VIEWBOX 23.16:17.04.
    private var canvasWidth: CGFloat { size }
    private var canvasHeight: CGFloat {
        switch kind {
        case .fishLogo:
            return size * CGFloat(fishLogoViewBoxHeight) / CGFloat(fishLogoViewBoxWidth)
        default:
            return size
        }
    }

    private static let regularStroke = StrokeStyle(
        lineWidth: 1,
        lineCap: .butt,
        lineJoin: .miter,
        miterLimit: 10
    )

    private func drawPanelLeft(_ ctx: inout GraphicsContext, color: Color, stroke: StrokeStyle) {
        ctx.stroke(Path(SVGPath.cgPath(headerPanelFramePath)), with: .color(color), style: stroke)
        ctx.stroke(Path(SVGPath.cgPath(headerPanelDividerPath)), with: .color(color), style: stroke)
    }

    /// Settings-shell Medium uses `ICON_MEDIUM_STROKE` 1.3; `/model` Regular uses 1.
    /// Split cases instead of `kind ==` — `Kind` has associated values.
    private func drawDataOutline(_ ctx: inout GraphicsContext, color: Color, strokeWidth: CGFloat) {
        let dataStroke = StrokeStyle(
            lineWidth: strokeWidth,
            lineCap: .butt,
            lineJoin: .miter,
            miterLimit: 10
        )
        ctx.fill(Path(SVGPath.cgPath(settingsDataOutlineFillPath)), with: .color(color))
        ctx.stroke(Path(SVGPath.cgPath(settingsDataOutlineGearPath)), with: .color(color), style: dataStroke)
    }

    private func drawPermission(_ ctx: inout GraphicsContext, value: String, color: Color, stroke: StrokeStyle) {
        switch value {
        case "read-only":
            ctx.stroke(Path(SVGPath.cgPath(Self.readCheck)), with: .color(color), style: stroke)
            ctx.stroke(Path(SVGPath.cgPath(Self.shield)), with: .color(color), style: StrokeStyle(lineWidth: 1, lineJoin: .round))
        case "workspace-write":
            ctx.fill(Path(SVGPath.cgPath(Self.writeShield)), with: .color(color))
            ctx.stroke(Path(SVGPath.cgPath(Self.writeLineA)), with: .color(color), style: stroke)
            ctx.stroke(Path(SVGPath.cgPath(Self.writeLineB)), with: .color(color), style: stroke)
            ctx.fill(Path(SVGPath.cgPath(Self.writePencil)), with: .color(color))
            ctx.fill(Path(SVGPath.cgPath(Self.writeBase)), with: .color(color))
        case "danger-full-access":
            ctx.stroke(Path(SVGPath.cgPath(Self.shield)), with: .color(color), style: StrokeStyle(lineWidth: 1, lineJoin: .round))
            ctx.stroke(Path(SVGPath.cgPath(Self.fullBangStem)), with: .color(color), style: stroke)
            ctx.stroke(Path(SVGPath.cgPath(Self.fullBangDot)), with: .color(color), style: stroke)
        case "auto":
            ctx.stroke(Path(SVGPath.cgPath(Self.shield)), with: .color(color), style: StrokeStyle(lineWidth: 1, lineJoin: .round))
            ctx.stroke(Path(SVGPath.cgPath(Self.autoA)), with: .color(color), style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
        default:
            break
        }
    }

    private static let thinkOrbitA = "M10.2854 5.71481C12.9673 8.39663 14.1182 11.5938 12.8562 12.8559C11.5942 14.1179 8.39706 12.9669 5.71518 10.2851C3.03333 7.60323 1.88236 4.40608 3.14441 3.14403C4.40644 1.882 7.6036 3.03297 10.2854 5.71481Z"
    private static let thinkOrbitB = "M10.2854 10.2851C7.6036 12.9669 4.40644 14.1179 3.14441 12.8559C1.88236 11.5938 3.03333 8.39663 5.71518 5.71481C8.39706 3.03297 11.5942 1.882 12.8562 3.14403C14.1182 4.40608 12.9673 7.60323 10.2854 10.2851Z"
    private static let thinkCore = "M8.86291 8.0002C8.86291 8.47549 8.47762 8.86087 8.00224 8.86087C7.52694 8.86087 7.1416 8.47549 7.1416 8.0002C7.1416 7.52485 7.52694 7.13953 8.00224 7.13953C8.47762 7.13953 8.86291 7.52485 8.86291 8.0002Z"
    private static let presetFill = "M6.51867 12.3282C7.29816 12.6011 8.16475 12.6514 9.02269 12.4216C9.57879 12.2726 10.0784 12.0185 10.5087 11.6888C10.7819 12.0555 11.1606 12.3304 11.5913 12.4805C10.9688 13.029 10.2149 13.4478 9.35911 13.6771C8.13946 14.0038 6.90632 13.8971 5.82126 13.4533C6.15821 13.1562 6.4021 12.7652 6.51867 12.3282ZM9.17629 2.89409C11.1101 3.34433 12.739 4.81872 13.2889 6.87043C13.4219 7.3665 13.4811 7.8649 13.4774 8.35466C13.0924 8.13213 12.6422 8.01837 12.1741 8.05276L12.1711 8.05257C12.1539 7.77199 12.109 7.48889 12.0334 7.20684C11.6363 5.72533 10.5048 4.6372 9.13549 4.22844C9.25559 3.87667 9.29214 3.49087 9.22309 3.09892C9.2108 3.02922 9.19451 2.96108 9.17629 2.89409ZM4.7311 3.89107L4.78302 4.11879C4.87648 4.4488 5.04146 4.74263 5.25579 4.98896C3.98078 6.01355 3.35848 7.72904 3.8089 9.41059C3.81828 9.44559 3.82866 9.48025 3.83885 9.51479C3.38217 9.61268 2.98548 9.84137 2.68107 10.1556C2.63414 10.022 2.5897 9.88632 2.55244 9.74726C1.93301 7.43489 2.86717 5.07173 4.71504 3.76697L4.7311 3.89107Z"
    private static let presetHead = "M7.99136 5.28105C8.87501 5.28105 9.59136 4.56471 9.59136 3.68105C9.59136 2.7974 8.87501 2.08105 7.99136 2.08105C7.1077 2.08105 6.39136 2.7974 6.39136 3.68105C6.39136 4.56471 7.1077 5.28105 7.99136 5.28105Z"
    private static let presetLeft = "M3.94009 12.9417C4.82374 12.9417 5.54009 12.2254 5.54009 11.3417C5.54009 10.458 4.82374 9.7417 3.94009 9.7417C3.05643 9.7417 2.34009 10.458 2.34009 11.3417C2.34009 12.2254 3.05643 12.9417 3.94009 12.9417Z"
    private static let presetRight = "M12.0851 12.9417C12.9688 12.9417 13.6851 12.2254 13.6851 11.3417C13.6851 10.458 12.9688 9.7417 12.0851 9.7417C11.2015 9.7417 10.4851 10.458 10.4851 11.3417C10.4851 12.2254 11.2015 12.9417 12.0851 12.9417Z"
    private static let readCheck = "M5.08545 8.13775L7.18455 10.2368C7.26636 10.3187 7.4003 10.3142 7.47649 10.2271L11.5148 5.61194"
    private static let shield = "M6.59624 2.14853C7.50155 1.80917 8.49914 1.80919 9.40444 2.14859L13.9245 3.84317V7.11961C13.9245 11.6089 10.5565 13.5975 8.00035 14.5779C5.44423 13.5975 2.07544 11.6089 2.07544 7.11961V3.84317L6.59624 2.14853Z"
    private static let writeShield = "M6.4209 1.68067C7.43922 1.299 8.56177 1.29898 9.58008 1.68067L14.0996 3.375C14.2946 3.44811 14.4236 3.63455 14.4238 3.84278V6.89063C14.1115 6.71853 13.7761 6.58312 13.4238 6.48926V4.18946L9.22852 2.61621C8.43657 2.31947 7.56341 2.31939 6.77148 2.61621L2.5752 4.18946V7.11914C2.5752 11.1796 5.52369 13.056 8 14.0391C8.27653 13.9293 8.55827 13.8067 8.8418 13.6729C9.07101 13.9468 9.33228 14.1929 9.62012 14.4053C9.12409 14.6579 8.63578 14.8696 8.17871 15.0449C8.0637 15.0889 7.93628 15.0889 7.82129 15.0449C5.22011 14.0472 1.5752 11.9381 1.5752 7.11914V3.84278C1.57541 3.63469 1.70463 3.44821 1.89941 3.375L6.4209 1.68067Z"
    private static let writeLineA = "M5.26392 6.60339H10.7361"
    private static let writeLineB = "M5.26392 9.86902H8.32833"
    private static let writePencil = "M10.0317 13.2229C10.263 13.3929 10.4943 13.563 10.7256 13.733C10.7932 13.6482 10.8608 13.5634 10.9284 13.4786C12.1455 11.9522 13.3626 10.4258 14.5798 8.89935C14.6474 8.81455 14.715 8.72975 14.7826 8.64495C14.4143 8.37419 14.046 8.10344 13.6777 7.83268C13.6169 7.92252 13.5562 8.01236 13.4954 8.10219C12.4016 9.71926 11.3078 11.3363 10.214 12.9534C10.1532 13.0432 10.0924 13.1331 10.0317 13.2229Z"
    private static let writeBase = "M12.6516 12.6696C12.6516 12.925 12.6516 13.1804 12.6516 13.4359C12.6952 13.4378 12.7387 13.4398 12.7823 13.4417C13.5663 13.4768 14.3504 13.5118 15.1345 13.5469C15.178 13.5488 15.2216 13.5508 15.2651 13.5527C15.2651 13.2194 15.2651 12.8861 15.2651 12.5527C15.2216 12.5547 15.178 12.5566 15.1345 12.5586C14.3504 12.5936 13.5663 12.6287 12.7823 12.6637C12.7387 12.6657 12.6952 12.6676 12.6516 12.6696Z"
    private static let fullBangStem = "M8 4.39209V9.89209"
    private static let fullBangDot = "M8 10.8081V11.8081"
    private static let autoA = "M5.75 10.15L8 4.95L10.25 10.15M6.43 8.59H9.57"
    private static let folderCloseBody = "M1.50439 3.11059C1.50439 2.55831 1.95211 2.1106 2.50439 2.1106H5.43389C5.67773 2.1106 5.91318 2.19969 6.09593 2.36113L7.71649 3.79265C7.89924 3.95409 8.1347 4.04319 8.3785 4.04319H13.4958C14.0481 4.04319 14.4958 4.4909 14.4958 5.04319V12.8894C14.4958 13.4417 14.0481 13.8894 13.4958 13.8894H2.50439C1.95211 13.8894 1.50439 13.4417 1.50439 12.8894V4.04319V3.11059Z"
    private static let folderCloseLine = "M3.63501 7.66614H12.3647"
    private static let folderOpenFront = "M12.3994 13.5986H2.04956C1.49728 13.5986 1.04956 13.1509 1.04956 12.5986V3.40137C1.04956 2.84908 1.49728 2.40137 2.04956 2.40137H4.76632C5.01016 2.40137 5.24561 2.49046 5.42836 2.6519L7.04892 4.08342"
    private static let folderOpenBack = "M2.55911 7.93683C2.67584 7.49906 3.07229 7.19446 3.52536 7.19446H13.6491C14.3061 7.19446 14.7846 7.81725 14.6153 8.45209L13.4411 12.856C13.3244 13.2938 12.9279 13.5984 12.4748 13.5984H2.35113C1.69411 13.5984 1.21562 12.9756 1.38489 12.3407L2.55911 7.93683Z"
    private static let pinBody = "M9.96976 1.70572L13.1554 3.93629L10.9019 8.12317L11.5158 11.605L10.7192 12.7427L2.52767 7.00693L3.3243 5.86922L6.80612 5.25528L9.96976 1.70572Z"
    private static let pinNeedle = "M6.05285 9.47511C6.27284 9.16094 6.70586 9.08458 7.02003 9.30457C7.3342 9.52455 7.41055 9.95757 7.19057 10.2717L3.98587 14.4708L3.21223 13.9291L6.05285 9.47511Z"
    private static let archiveLid = "M13.5 2.5H2.5C1.94772 2.5 1.5 2.94772 1.5 3.5V4.5C1.5 5.05228 1.94772 5.5 2.5 5.5H13.5C14.0523 5.5 14.5 5.05228 14.5 4.5V3.5C14.5 2.94772 14.0523 2.5 13.5 2.5Z"
    private static let archiveBox = "M2.5 5.5V13.5C2.5 13.7652 2.60536 14.0196 2.79289 14.2071C2.98043 14.3946 3.23478 14.5 3.5 14.5H12.5C12.7652 14.5 13.0196 14.3946 13.2071 14.2071C13.3946 14.0196 13.5 13.7652 13.5 13.5V5.5"
    private static let archiveSlot = "M6.5 9.5H9.5"
    private static let ellipsisA = "M3 9C3.55228 9 4 8.55228 4 8C4 7.44772 3.55228 7 3 7C2.44772 7 2 7.44772 2 8C2 8.55228 2.44772 9 3 9Z"
    private static let ellipsisB = "M8 9C8.55228 9 9 8.55228 9 8C9 7.44772 8.55228 7 8 7C7.44772 7 7 7.44772 7 8C7 8.55228 7.44772 9 8 9Z"
    private static let ellipsisC = "M13 9C13.5523 9 14 8.55228 14 8C14 7.44772 13.5523 7 13 7C12.4477 7 12 7.44772 12 8C12 8.55228 12.4477 9 13 9Z"
    private static let slidersA = "M2.3 5H8.15M12.05 5H13.7"
    private static let slidersB = "M2.3 11H3.95M7.85 11H13.7"
    private static let workspaceTreeBody = "M14 12.05c0 .8-.65 1.45-1.46 1.45H3.46C2.65 13.5 2 12.85 2 12.05v-8.1c0-.8.65-1.45 1.46-1.45h2.4c.49 0 .94.24 1.21.65l.5.73c.27.4.73.65 1.21.65h3.76c.8 0 1.46.65 1.46 1.45v6.02Z"
    private static let workspaceTreeLegs = "M8.7 8.1V11M11.2 8.1V11"
    private static let flatListRows = "M6 3.5H13.5M6 8H13.5M6 12.5H13.5"
    private static let flatListDots = "M2.6 3.5H2.61M2.6 8H2.61M2.6 12.5H2.61"
    private static let globeRim = "M7.99986 14.0887C11.3626 14.0887 14.0886 11.3627 14.0886 7.99998C14.0886 4.63727 11.3626 1.91125 7.99986 1.91125C4.63715 1.91125 1.91113 4.63727 1.91113 7.99998C1.91113 11.3627 4.63715 14.0887 7.99986 14.0887Z"
    private static let globeEquator = "M2.34619 8H13.6538"
    private static let globeMeridianA = "M7.99976 14.0889C9.23509 14.0889 10.1743 11.3629 10.1743 8.00006C10.1743 4.63739 9.23509 1.91138 7.99976 1.91138"
    private static let globeMeridianB = "M7.99973 14.0889C6.76445 14.0889 5.8252 11.3629 5.8252 8.00006C5.8252 4.63739 6.76445 1.91138 7.99973 1.91138"
    private static let clockRim = "M8 14C11.3137 14 14 11.3137 14 8C14 4.68629 11.3137 2 8 2C4.68629 2 2 4.68629 2 8C2 11.3137 4.68629 14 8 14Z"
    private static let clockHands = "M8 4.31V8.46L11 10.08"
    private static let chevronsUp = "m5.1 6 2.9-2.9L10.9 6"
    private static let chevronsDown = "m5.1 10 2.9 2.9 2.9-2.9"
    private static let archiveOffBox = "M2.95 5.7v4.8a2.9 2.9 0 0 0 2.9 2.9h4.3a2.9 2.9 0 0 0 2.9-2.9V5.7"
    private static let archiveOffSlash = "m2.2 1.3 11.6 12.8"
    private static let archiveCheckMark = "m6 9.35 1.4 1.4 2.6-2.6"
    private static let queueLineA = "M5 6.75H11"
    private static let queueLineB = "M5 9H8"
    private static let queueBubble = "M2.37067 11.2497C1.5872 9.89252 1.32042 8.29798 1.61945 6.7597C1.91847 5.22141 2.76317 3.84293 3.99801 2.87809C5.23285 1.91325 6.7747 1.427 8.33964 1.50888C9.90458 1.59076 11.3873 2.23526 12.5147 3.32369C13.6422 4.41232 14.3384 5.8717 14.4751 7.43304C14.6118 8.99438 14.1797 10.5525 13.2585 11.8205C12.3372 13.0885 10.9889 13.9809 9.4617 14.3334C8.18666 14.6277 6.8587 14.529 5.64964 14.0601C5.17095 13.8745 4.76937 13.4929 4.26509 13.3963C3.67389 13.2832 2.95232 13.5595 2.0377 14.3334"
    private static let downloadStem = "M8 1.95317V10.0469"
    private static let downloadArrow = "M4.25 6.29688L8 10.0469L11.75 6.29688"
    private static let downloadTray = "M1.5 10.0469V13.158C1.5 13.3937 1.60536 13.6198 1.79289 13.7865C1.98043 13.9532 2.23478 14.0469 2.5 14.0469H13.5C13.7652 14.0469 14.0196 13.9532 14.2071 13.7865C14.3946 13.6198 14.5 13.3937 14.5 13.158V10.0469"
    private static let terminalPrompt = "M10 11L16.606 17.606C16.6841 17.6841 16.6841 17.8107 16.606 17.8888L10 24.4948"
    private static let terminalCursor = "M20.1211 24.4946H26.8685"

    static func process(_ kind: String) -> Kind {
        switch kind {
        case "thinking": return .think
        case "read", "readImage", "webFetch": return .browseOutline
        case "search": return .searchOutline
        case "edit", "write": return .editOutline
        case "commands": return .apiOutline
        case "code": return .codeOutline
        case "webSearch": return .globe
        case "subagents": return .agentPreset
        case "plan": return .planOutline
        case "questions": return .questionOutline
        case "tools": return .sparkle
        default:
            preconditionFailure("OfficialGlyph.process unknown PROCESS_ICONS kind \(kind)")
        }
    }

    static func tool(_ icon: ToolProcessIcon) -> Kind {
        switch icon {
        case .browse: return .browseOutline
        case .search: return .searchOutline
        case .command: return .apiOutline
        case .write, .edit: return .editOutline
        case .code: return .codeOutline
        case .generic: return .sparkle
        case .users: return .usersOutline
        case .checklist: return .checklistOutline
        case .clock: return .clockOutline
        case .goal: return .goalOutline
        case .plugin: return .cordisPlugin
        case .agent: return .agentPreset
        case .branch: return .branchOutline
        }
    }

    /// Desktop `ui-commands` `HOST_FACES` + `/file` paperclip + `/model` data.
    static func commandMenu(_ kind: String?) -> Kind {
        switch kind {
        case "file": return .paperclipOutline
        case "model": return .dataOutlineRegular
        case "goal": return .goalOutline
        case "plan": return .planOutline
        case "feedback": return .paperPlaneOutline
        case "compact": return .compactOutline
        case "permission": return .permissionFullAccess
        case "export": return .downloadOutline
        default: return .codeOutline
        }
    }
}

private struct OfficialGlyphAccess: ViewModifier {
    let kind: OfficialGlyph.Kind

    func body(content: Content) -> some View {
        if kind.hidesAccessibility {
            content.accessibilityHidden(true)
        } else {
            // Canvas is not an a11y element by default, so a bare identifier
            // is absorbed by the nearest Button / labeled parent. Force a
            // leaf image so XCUITest can resolve official.* as descendants.
            // A parent Button that also sets `.accessibilityIdentifier` still
            // combines/overwrites this leaf unless it uses `.contain`.
            content
                .accessibilityElement()
                .accessibilityIdentifier(kind.accessibilityIdentifier)
                .accessibilityAddTraits(.isImage)
        }
    }
}
