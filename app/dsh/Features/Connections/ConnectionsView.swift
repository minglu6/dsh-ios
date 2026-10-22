import SwiftUI
import UIKit
import DSHProtocol

/// Phone controller connections list. Twin of Android `ConnectionsScreen` /
/// `ConnDeviceRow` — not desktop Settings → 手机连接 (host QR).
struct ConnectionsView: View {
    @ObservedObject var model: AppModel
    @State private var presented: Presented?
    @State private var showScan = false
    @State private var address = ""
    @State private var code = ""
    @State private var name = ""
    @State private var pairing = false
    @State private var renaming = false
    @State private var renameDraft = ""
    @State private var emptyPaste = false
    @State private var useLink = false
    @State private var pairingLink = ""

    private enum Presented: Identifiable, Equatable {
        case pair
        case manage(String)

        var id: String {
            switch self {
            case .pair: return "pair"
            case .manage(let id): return "manage.\(id)"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if !sortedProfiles.isEmpty {
                        section(L.pairedDevices(), cardIdentifier: connectionsPairedCardIdentifier()) {
                            ForEach(Array(sortedProfiles.enumerated()), id: \.element.id) { index, profile in
                                pairedRow(profile, divider: index < sortedProfiles.count - 1)
                            }
                        }
                    }
                    connCard(identifier: connectionsActionsCardIdentifier()) {
                        // Skip: ui-primitives 0.2.1-alpha.5 has no QR artwork
                        // (`connectionsScanUsesOfficialGlyph`). Do not invent one.
                        ConnActionRow(
                            title: L.scanQr(),
                            identifier: connectionsActionRowIdentifier(.scan),
                            system: "qrcode.viewfinder",
                            divider: true
                        ) { showScan = true }
                        ConnActionRow(
                            title: L.enterAddress(),
                            identifier: connectionsActionRowIdentifier(.enterAddress),
                            official: .keyboard,
                            divider: false
                        ) { openAddressSheet() }
                    }
                    Spacer().frame(height: 24)
                }
                .padding(.top, 4)
            }
            .background(T.bg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(T.bg.ignoresSafeArea())
        // Same as settingsShell: `.contain` keeps header children (navBack /
        // connectionsTitle) addressable. An identifier on the VStack alone
        // leaked onto Back / 远程主机 / 更多 / ScrollView, and XCUITest
        // `.frame` then failed with multiple matches.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("connectionsScreen")
        .sheet(item: $presented, onDismiss: { renaming = false }) { item in
            switch item {
            case .pair:
                pairSheet
            case .manage(let id):
                manageSheet(managedProfile(id))
                    .presentationDetents([.medium])
                    .tint(T.ink)
            }
        }
        .fullScreenCover(isPresented: $showScan) {
            QRScannerView(
                onCode: { value in
                    showScan = false
                    if let link = PairingUriPolicy.parse(value) {
                        openAddressSheet(host: link.host, port: link.port, code: link.code)
                    } else {
                        model.errorMessage = L.pairFailed()
                    }
                },
                onCancel: { showScan = false }
            )
            .ignoresSafeArea()
        }
        .task {
            while !Task.isCancelled {
                model.refreshPairedStatus()
                try? await Task.sleep(nanoseconds: 10_000_000_000)
            }
        }
        .onAppear {
            if let pending = model.pendingPair {
                openAddressSheet(host: pending.host, port: pending.port, code: pending.code)
                model.pendingPair = nil
            }
        }
    }

    private var sortedProfiles: [Profile] {
        model.profiles.sorted {
            if $0.lastUsedAt != $1.lastUsedAt { return $0.lastUsedAt > $1.lastUsedAt }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    private func managedProfile(_ id: String) -> Profile {
        guard let profile = model.profiles.first(where: { $0.id == id }) else {
            fatalError("manage sheet for missing profile \(id)")
        }
        return profile
    }

    private var header: some View {
        HStack {
            Button(action: model.pop) { OfficialGlyph(kind: .chevronLeft, size: 16, color: T.ink) }
                .accessibilityElement(children: .contain)
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("navBack")
            Text(L.connections())
                .font(Font.headline)
                .foregroundStyle(T.ink)
                .accessibilityIdentifier("connectionsTitle")
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(T.surface)
    }

    private func section<Content: View>(
        _ title: String,
        cardIdentifier: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(Font.system(size: CGFloat(connectionsSectionTitleFontSizePoints)))
                .foregroundStyle(T.ink)
                .frame(height: CGFloat(connectionsSectionTitleLineHeightPoints), alignment: .leading)
                .padding(.horizontal, 22)
                .padding(.top, CGFloat(connectionsSectionTitlePaddingTopPoints))
                .padding(.bottom, CGFloat(connectionsSectionTitlePaddingBottomPoints))
            connCard(identifier: cardIdentifier) { content() }
        }
    }

    /// Android `Card`: desktop settings-card fill/stroke, then 6pt outer
    /// vertical margin so stacked cards do not touch.
    private func connCard<Content: View>(
        identifier: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) { content() }
            .background(T.settingsCard, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(T.settingsCardStroke, lineWidth: 0.5))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(identifier)
            .padding(.horizontal, 16)
            .padding(.vertical, CGFloat(connectionsCardVerticalPaddingPoints))
    }

    private func pairedRow(_ profile: Profile, divider: Bool) -> some View {
        let current = profile.id == model.activeId
        let dot = model.status[profile.id]
        let routeLabel = profile.needsRepair ? "" : (model.routes[profile.id]?.label ?? profile.kind)
        return ConnDeviceRow(
            name: profile.name,
            statusLine: connectionsStatusLine(
                status: profile.needsRepair ? L.repairNeeded() : dotText(dot),
                routeLabel: routeLabel,
                current: current ? L.currentDevice() : nil
            ),
            detail: profile.needsRepair ? nil : profile.subtitle,
            warn: profile.needsRepair,
            divider: divider,
            rowIdentifier: connectionsPairedRowIdentifier(),
            onClick: { presented = .manage(profile.id) },
            onSwitch: current ? nil : {
                model.connect(profileId: profile.id)
                model.pop()
            },
            leading: { StatusDot(color: dotColor(dot)) }
        )
    }

    private func manageSheet(_ profile: Profile) -> some View {
        // Not NavigationStack: that is system bar chrome (and can leak the
        // accent tint). Android `ProfileManageSheet` is ConnSheet + OptionRow
        // with desktop `D.refresh` / `D.edit` / `D.trash`. Phone still needs
        // a dismiss control, styled as desktop Button.ghost.
        VStack(alignment: .leading, spacing: 0) {
            connSheetCancel(identifier: connectionsManageCancelIdentifier()) {
                presented = nil
            }
            if renaming {
                Text(L.rename())
                    .font(Font.system(size: CGFloat(connectionsSheetTitleFontSizePoints), weight: .semibold))
                    .foregroundStyle(T.ink)
                    .padding(.horizontal, CGFloat(connectionsSheetContentPaddingPoints))
                    .padding(.vertical, 6)
                TextField(L.rename(), text: $renameDraft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(Font.system(size: CGFloat(connectionsFieldFontSizePoints)))
                    .padding(.horizontal, CGFloat(connectionsFieldHorizontalPaddingPoints))
                    .padding(.vertical, CGFloat(connectionsFieldVerticalPaddingPoints))
                    .background(
                        T.input,
                        in: RoundedRectangle(cornerRadius: CGFloat(connectionsFieldRadiusPoints))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: CGFloat(connectionsFieldRadiusPoints))
                            .stroke(T.borderStrong, lineWidth: CGFloat(dswButtonOutlineWidthPoints))
                    )
                    .padding(.horizontal, CGFloat(connectionsSheetContentPaddingPoints))
                    .padding(.top, 12)
                HStack(spacing: 10) {
                    Button(L.cancel()) { renaming = false }
                        .buttonStyle(.plain)
                        .font(Font.system(size: CGFloat(dswButtonFontSizePoints)))
                        .frame(maxWidth: .infinity)
                        .frame(height: CGFloat(connectionsSheetButtonHeightPoints))
                        .foregroundStyle(T.ink)
                        .overlay(
                            RoundedRectangle(cornerRadius: CGFloat(dswButtonRadiusMdPoints))
                                .stroke(T.borderL3, lineWidth: CGFloat(dswButtonOutlineWidthPoints))
                        )
                    Button {
                        do {
                            try model.renameProfile(profile.id, name: renameDraft)
                            renaming = false
                        } catch {
                            model.errorMessage = error.localizedDescription
                        }
                    } label: {
                        Text(L.save())
                            .font(Font.system(size: CGFloat(dswButtonFontSizePoints)))
                            .frame(maxWidth: .infinity)
                            .frame(height: CGFloat(connectionsSheetButtonHeightPoints))
                            .foregroundStyle(T.onPrimary)
                            .background(
                                T.primaryButton,
                                in: RoundedRectangle(cornerRadius: CGFloat(dswButtonRadiusMdPoints))
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(renameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(
                        renameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? dswButtonDisabledOpacity : 1
                    )
                }
                .padding(.horizontal, CGFloat(connectionsSheetContentPaddingPoints))
                .padding(.top, 16)
                Spacer()
            } else {
                HStack(spacing: 10) {
                    StatusDot(color: dotColor(model.status[profile.id]))
                    Text(profile.name)
                        .font(Font.system(size: CGFloat(connectionsSheetTitleFontSizePoints), weight: .semibold))
                        .foregroundStyle(T.ink)
                }
                .padding(.horizontal, CGFloat(connectionsSheetContentPaddingPoints))
                .padding(.vertical, 6)
                Text(
                    connectionsStatusLine(
                        status: profile.needsRepair ? L.repairNeeded() : dotText(model.status[profile.id]),
                        routeLabel: profile.needsRepair ? "" : (model.routes[profile.id]?.label ?? profile.kind),
                        current: profile.id == model.activeId ? L.currentDevice() : nil
                    )
                )
                .font(Font.system(size: 12))
                .foregroundStyle(T.text3)
                .padding(.horizontal, CGFloat(connectionsSheetContentPaddingPoints))
                .padding(.vertical, 4)
                if !profile.needsRepair {
                    Text(profile.subtitle)
                        .font(Font.system(size: 12, design: .monospaced))
                        .foregroundStyle(T.caption)
                        .padding(.horizontal, CGFloat(connectionsSheetContentPaddingPoints))
                        .padding(.bottom, 4)
                }
                VStack(spacing: 0) {
                    manageAction(
                        L.repairPair(),
                        official: .refreshOutline,
                        identifier: connectionsManageRepairIdentifier()
                    ) {
                        openAddressSheet(
                            host: profile.needsRepair ? nil : profile.host,
                            port: profile.needsRepair ? nil : profile.port,
                            name: profile.name
                        )
                    }
                    manageAction(
                        L.rename(),
                        official: .editOutline,
                        identifier: connectionsManageRenameIdentifier()
                    ) {
                        renameDraft = profile.name
                        renaming = true
                    }
                    manageAction(
                        L.delete(),
                        official: .trashOutline,
                        identifier: connectionsManageDeleteIdentifier()
                    ) {
                        presented = nil
                        model.removeProfile(profile.id)
                    }
                }
                .padding(.top, 8)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, CGFloat(connectionsSheetDragHandleAreaPoints))
        .background(T.surface)
        .tint(T.ink)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(connectionsManageSheetIdentifier())
        .onAppear { renaming = false }
    }

    /// Android `ConnOptionRow`: 18pt official glyph + 16pt title, `T.Ink`.
    /// The row is one SwiftUI `Button` (VoiceOver / XCUI `.buttons`). The
    /// official glyph is a sibling, not a Button child — a parent Button
    /// identifier would swallow `official.trashOutline` / refresh / edit
    /// (OfficialGlyphAccess). The 18pt leading slot matches the icon so
    /// the button still owns the full-row tap.
    private func manageAction(
        _ title: String,
        official: OfficialGlyph.Kind,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        ZStack(alignment: .leading) {
            OfficialGlyph(kind: official, size: 18, color: T.ink)
                .padding(.leading, CGFloat(connectionsSheetContentPaddingPoints))
                .allowsHitTesting(false)
            Button(action: action) {
                HStack(spacing: 14) {
                    Color.clear.frame(width: 18, height: 18)
                    Text(title)
                        .font(Font.system(size: 16))
                        .foregroundStyle(T.ink)
                    Spacer()
                }
                .padding(.horizontal, CGFloat(connectionsSheetContentPaddingPoints))
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityIdentifier(identifier)
        }
    }

    private func dotColor(_ dot: Dot?) -> Color {
        switch dot {
        case .online: return T.ok
        case .connecting: return T.accent
        case .unauthorized: return T.warnText
        default: return T.text3
        }
    }

    private func dotText(_ dot: Dot?) -> String {
        switch dot {
        case .online: return L.online()
        case .connecting: return L.connecting()
        case .unauthorized: return L.repairNeeded()
        default: return L.offline()
        }
    }

    private func openAddressSheet(host: String? = nil, port: Int? = nil, code: String = "", name: String = "") {
        if let host, let port {
            address = "\(host):\(port)"
        } else {
            address = ""
        }
        self.code = code
        emptyPaste = false
        useLink = false
        pairingLink = ""
        self.name = name
        presented = .pair
    }

    private var parsedLink: PairingLink? { PairingUriPolicy.parse(pairingLink) }

    private var invalidLink: Bool {
        !pairingLink.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && parsedLink == nil
    }

    private var canPair: Bool {
        useLink ? parsedLink != nil
            : (parseHostPort(address) != nil && code.count == 6 && code.allSatisfy(\.isNumber))
    }

    private var pairSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text(L.addressInputHint())
                    .font(.caption)
                    .foregroundStyle(T.text3)
                Picker(L.t("输入方式", "Input method"), selection: $useLink) {
                    Text(L.t("手动输入", "Manual entry")).tag(false)
                    Text(L.pastePairingLink()).tag(true)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("connectionsInputMethod")
                if useLink {
                    field(
                        L.t("配对链接", "Pairing link"),
                        text: $pairingLink,
                        hint: "dshpocket://pair?h=…&c=…",
                        mono: true,
                        identifier: "connectionsPairingLinkField"
                    )
                    Button(L.pastePairingLink()) {
                        let value = UIPasteboard.general.string ?? ""
                        emptyPaste = value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        if !emptyPaste { pairingLink = value }
                    }
                    .foregroundStyle(T.ink)
                    .accessibilityIdentifier(connectionsPastePairingLinkIdentifier())
                    if emptyPaste {
                        Text(L.t("剪贴板中没有链接。", "No link on the clipboard."))
                            .font(.caption)
                            .foregroundStyle(T.err)
                    } else if invalidLink {
                        Text(L.invalidPairingLink())
                            .font(.caption)
                            .foregroundStyle(T.err)
                            .accessibilityIdentifier(connectionsInvalidPairingLinkIdentifier())
                    }
                    if let link = parsedLink {
                        Text("\(link.host):\(link.port) · \(L.pairingCode()) \(link.code)")
                            .font(.caption.monospaced())
                            .foregroundStyle(T.text3)
                            .accessibilityIdentifier("connectionsParsedLink")
                    }
                } else {
                    field(
                        L.addressField(),
                        text: $address,
                        hint: "192.168.1.20:7690",
                        mono: true,
                        identifier: connectionsAddressFieldIdentifier()
                    )
                    field(
                        L.pairingCode(),
                        text: $code,
                        hint: "123456",
                        mono: true,
                        identifier: connectionsCodeFieldIdentifier()
                    )
                }
                field(L.nameField(), text: $name, hint: L.nameHint(), mono: false)
                Spacer()
                Button {
                    Task { await startPair() }
                } label: {
                    HStack {
                        if pairing { ProgressView().tint(T.onPrimary) }
                        Text(pairing ? L.pairingBusy() : L.pairAction())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(T.onPrimary)
                    .background(T.primaryButton, in: RoundedRectangle(cornerRadius: 8))
                }
                .disabled(pairing || !canPair)
                .accessibilityIdentifier("connectionsStartPair")
            }
            .padding(18)
            .background(T.bg)
            .navigationTitle(L.enterAddress())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.cancel()) { presented = nil }
                }
            }
            .onChange(of: pairingLink) { _ in emptyPaste = false }
        }
    }

    private func field(
        _ label: String,
        text: Binding<String>,
        hint: String,
        mono: Bool,
        identifier: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(Font.caption).foregroundStyle(T.text3)
            TextField(hint, text: text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(mono ? Font.body.monospaced() : Font.body)
                .padding(12)
                .background(T.input, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(T.border, lineWidth: 0.5))
                .accessibilityLabel(label)
                .accessibilityIdentifierIfPresent(identifier)
        }
    }

    private func startPair() async {
        guard canPair else { return }
        pairing = true
        defer { pairing = false }
        do {
            if useLink, let link = parsedLink {
                try await model.pair(link: link, name: name)
            } else if let parsed = parseHostPort(address) {
                try await model.pair(name: name, host: parsed.0, port: parsed.1, code: code)
            } else {
                throw PocketError(code: "pair", message: L.pairFailed())
            }
            presented = nil
            model.pop()
        } catch let error as PocketError where error.code == "timeout" {
            model.errorMessage = L.pairTimeout()
        } catch {
            model.errorMessage = error.localizedDescription
        }
    }
}

/// Desktop deviceRow twin: status dot + name + status line (`在线 · Tailscale · 当前`) + host:port.
private struct ConnDeviceRow<Leading: View>: View {
    var name: String
    var statusLine: String
    var detail: String?
    var warn: Bool
    var divider: Bool
    var rowIdentifier: String
    var onClick: () -> Void
    var onSwitch: (() -> Void)?
    var leading: Leading

    init(
        name: String,
        statusLine: String,
        detail: String?,
        warn: Bool,
        divider: Bool,
        rowIdentifier: String,
        onClick: @escaping () -> Void,
        onSwitch: (() -> Void)? = nil,
        @ViewBuilder leading: () -> Leading
    ) {
        self.name = name
        self.statusLine = statusLine
        self.detail = detail
        self.warn = warn
        self.divider = divider
        self.rowIdentifier = rowIdentifier
        self.onClick = onClick
        self.onSwitch = onSwitch
        self.leading = leading()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                leading
                Button(action: onClick) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(name)
                            .font(Font.system(size: 16))
                            .foregroundStyle(warn ? T.warnText : T.ink)
                            .lineLimit(1)
                        Text(statusLine)
                            .font(Font.system(size: 12))
                            .foregroundStyle(T.text3)
                            .lineLimit(1)
                        if let detail {
                            Text(detail)
                                .font(Font.system(size: 12, design: .monospaced))
                                .foregroundStyle(T.caption)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(rowIdentifier)
                if let onSwitch {
                    Button(L.switchDevice(), action: onSwitch)
                        .font(Font.subheadline)
                        .foregroundStyle(T.ink)
                        .disabled(warn)
                        .opacity(warn ? 0.4 : 1)
                }
                Button(action: onClick) {
                    OfficialGlyph(kind: .chevronRight, size: 14, color: T.caption)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L.moreActions())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            if divider {
                Divider().padding(.horizontal, 16)
            }
        }
    }
}

/// Desktop settingsRow action: icon + title + chevron.
private struct ConnActionRow: View {
    var title: String
    var identifier: String
    var official: OfficialGlyph.Kind? = nil
    var system: String? = nil
    var divider: Bool
    var onClick: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Button + `.contain` lets XCUITest retarget a child glyph and
            // never fire `action`. Hit-test the row like Android ConnActionRow.
            HStack(spacing: 12) {
                Group {
                    if let official {
                        OfficialGlyph(kind: official, size: 18, color: T.ink)
                    } else if let system {
                        Image(systemName: system)
                            .font(.system(size: 18))
                            .foregroundStyle(T.ink)
                    } else {
                        fatalError("ConnActionRow requires official or system icon")
                    }
                }
                .frame(width: 18, height: 18)
                Text(title)
                    .font(Font.system(size: 16))
                    .foregroundStyle(T.ink)
                Spacer()
                OfficialGlyph(kind: .chevronRight, size: 14, color: T.caption)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(perform: onClick)
            // VoiceOver: one labeled button. Not a SwiftUI `Button` + `.contain`
            // — that retargets XCUI taps onto the child glyph and never fires.
            // `.combine` would swallow keyboard / QR
            // skip leaves (see OfficialGlyphAccess). `.contain` keeps those
            // descendants queryable; label + isButton is the activatable row.
            .accessibilityElement(children: .contain)
            .accessibilityLabel(title)
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier(identifier)
            if divider {
                Divider().padding(.horizontal, 16)
            }
        }
    }
}

/// Ghost「取消」on ConnSheet. Android `PocketSheet` has no cancel row —
/// it dismisses by swipe. Phone still needs a control; 44pt hit is
/// `connectionsSheetCancelMinHeightPoints`.
private func connSheetCancel(identifier: String, action: @escaping () -> Void) -> some View {
    Button(L.cancel(), action: action)
        .buttonStyle(.plain)
        .font(Font.system(size: CGFloat(dswButtonFontSizePoints)))
        .foregroundStyle(T.ink)
        .padding(.horizontal, CGFloat(connectionsSheetContentPaddingPoints))
        .frame(minHeight: CGFloat(connectionsSheetCancelMinHeightPoints), alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityIdentifier(identifier)
}

private extension View {
    @ViewBuilder
    func accessibilityIdentifierIfPresent(_ identifier: String?) -> some View {
        if let identifier {
            self.accessibilityIdentifier(identifier)
        } else {
            self
        }
    }
}

private struct StatusDot: View {
    var color: Color

    var body: some View {
        Circle().fill(color).frame(width: 8, height: 8)
    }
}

