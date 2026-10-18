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

    private enum Presented: Identifiable, Equatable {
        case pairLink
        case pair
        case manage(String)

        var id: String {
            switch self {
            case .pairLink: return "pairLink"
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
                    if !model.nearby.isEmpty {
                        section(L.nearbyDevices(), cardIdentifier: connectionsNearbyCardIdentifier()) {
                            ForEach(Array(model.nearby.enumerated()), id: \.element.id) { index, host in
                                nearbyRow(host, divider: index < model.nearby.count - 1)
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
                            title: L.pairingLink(),
                            identifier: connectionsActionRowIdentifier(.pairingLink),
                            official: .linkOutline,
                            divider: true
                        ) { presented = .pairLink }
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
            case .pairLink:
                PairLinkSheet(
                    onDismiss: { presented = nil },
                    onResult: { link in
                        openAddressSheet(host: link.host, port: link.port, code: link.code)
                    }
                )
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
                .font(.headline)
                .foregroundStyle(T.ink)
                .accessibilityIdentifier("connectionsTitle")
            Spacer()
            Menu {
                // Android overflow also offers NEARBY_WIFI_DEVICES; iOS Local Network
                // is system-prompted by NWBrowser — no equivalent request API.
                Button(L.diagnosticsCopy()) { Task { _ = await model.copyDiagnostics() } }
            } label: {
                OfficialGlyph(kind: .ellipsis, size: 16, color: T.ink).padding(8)
            }
            .accessibilityLabel(L.moreActions())
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
                .font(.system(size: CGFloat(connectionsSectionTitleFontSizePoints)))
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

    private func nearbyRow(_ host: DiscoveredHost, divider: Bool) -> some View {
        ConnDeviceRow(
            name: host.deviceName,
            statusLine: L.lan(),
            detail: "\(host.host):\(host.port)",
            warn: false,
            divider: divider,
            rowIdentifier: connectionsNearbyRowIdentifier(),
            onClick: {
                openAddressSheet(host: host.host, port: host.port, name: host.deviceName)
            },
            leading: {
                // Material Outlined Computer (Android nearby row). primitives
                // have no IconComputer — do not substitute a desktop monitor cube.
                OfficialGlyph(kind: .computer, size: 18, color: T.accent)
            }
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
                    .font(.system(size: CGFloat(connectionsSheetTitleFontSizePoints), weight: .semibold))
                    .foregroundStyle(T.ink)
                    .padding(.horizontal, CGFloat(connectionsSheetContentPaddingPoints))
                    .padding(.vertical, 6)
                TextField(L.rename(), text: $renameDraft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(size: CGFloat(connectionsFieldFontSizePoints)))
                    .padding(.horizontal, CGFloat(connectionsFieldHorizontalPaddingPoints))
                    .padding(.vertical, CGFloat(connectionsFieldVerticalPaddingPoints))
                    .background(
                        T.input,
                        in: RoundedRectangle(cornerRadius: CGFloat(connectionsFieldRadiusPoints))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: CGFloat(connectionsFieldRadiusPoints))
                            .stroke(T.border, lineWidth: CGFloat(dswButtonOutlineWidthPoints))
                    )
                    .padding(.horizontal, CGFloat(connectionsSheetContentPaddingPoints))
                    .padding(.top, 12)
                HStack(spacing: 10) {
                    Button(L.cancel()) { renaming = false }
                        .buttonStyle(.plain)
                        .font(.system(size: CGFloat(dswButtonFontSizePoints)))
                        .frame(maxWidth: .infinity)
                        .frame(height: CGFloat(connectionsPairLinkButtonHeightPoints))
                        .foregroundStyle(T.ink)
                        .overlay(
                            RoundedRectangle(cornerRadius: CGFloat(dswButtonRadiusMdPoints))
                                .stroke(T.border, lineWidth: CGFloat(dswButtonOutlineWidthPoints))
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
                            .font(.system(size: CGFloat(dswButtonFontSizePoints)))
                            .frame(maxWidth: .infinity)
                            .frame(height: CGFloat(connectionsPairLinkButtonHeightPoints))
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
                        .font(.system(size: CGFloat(connectionsSheetTitleFontSizePoints), weight: .semibold))
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
                .font(.system(size: 12))
                .foregroundStyle(T.text3)
                .padding(.horizontal, CGFloat(connectionsSheetContentPaddingPoints))
                .padding(.vertical, 4)
                if !profile.needsRepair {
                    Text(profile.subtitle)
                        .font(.system(size: 12, design: .monospaced))
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
                        .font(.system(size: 16))
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
        self.name = name
        presented = .pair
    }

    private var pairSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                field(
                    L.addressField(),
                    text: $address,
                    hint: L.pairingUriHint(),
                    mono: true,
                    identifier: connectionsAddressFieldIdentifier()
                )
                field(L.nameField(), text: $name, hint: L.nameHint(), mono: false)
                if !address.contains("dshpocket://") {
                    field(
                        L.pairingCode(),
                        text: $code,
                        hint: "123456",
                        mono: true,
                        identifier: connectionsCodeFieldIdentifier()
                    )
                }
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
                .disabled(pairing)
            }
            .padding(18)
            .background(T.bg)
            .navigationTitle(L.pairSheetTitle())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.cancel()) { presented = nil }
                }
            }
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
            Text(label).font(.caption).foregroundStyle(T.text3)
            TextField(hint, text: text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(mono ? .system(.body, design: .monospaced) : .body)
                .padding(12)
                .background(T.input, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(T.border, lineWidth: 0.5))
                .accessibilityLabel(label)
                .accessibilityIdentifierIfPresent(identifier)
        }
    }

    private func startPair() async {
        pairing = true
        defer { pairing = false }
        do {
            if let link = PairingUriPolicy.parse(address) {
                try await model.pair(link: link, name: name)
            } else if let parsed = parseHostPort(address), !code.isEmpty {
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
                            .font(.system(size: 16))
                            .foregroundStyle(warn ? T.warnText : T.ink)
                            .lineLimit(1)
                        Text(statusLine)
                            .font(.system(size: 12))
                            .foregroundStyle(T.text3)
                            .lineLimit(1)
                        if let detail {
                            Text(detail)
                                .font(.system(size: 12, design: .monospaced))
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
                        .font(.subheadline)
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
                    .font(.system(size: 16))
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
            // `.combine` would swallow `official.linkOutline` / keyboard / QR
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

/// Android `PairLinkSheet` (9aa43c4): paste `dshpocket://pair`, then Continue
/// prefills the existing pair confirmation. Does not connect.
private struct PairLinkSheet: View {
    var onDismiss: () -> Void
    var onResult: (PairingLink) -> Void
    @State private var text = ""
    @State private var pasted = false
    /// Skip the next `onChange(of: text)` pasted reset so 粘贴链接 can set
    /// `pasted = true` after assigning `text` (Compose onValueChange does not
    /// fire for programmatic paste).
    @State private var suppressPasteReset = false

    private var parsed: PairingLink? { PairingUriPolicy.parse(text) }
    private var showInvalid: Bool {
        connectionsShowsInvalidPairingLink(text: text, pasted: pasted, parsed: parsed != nil)
    }

    var body: some View {
        // Not NavigationStack: that is system bar chrome (and can leak the
        // accent tint). Android `PairLinkSheet` is ConnSheet + SheetTitle;
        // phone still needs a dismiss control, styled as desktop Button.ghost.
        VStack(alignment: .leading, spacing: 0) {
            connSheetCancel(identifier: connectionsPairLinkCancelIdentifier(), action: onDismiss)
            Text(L.pairingLink())
                .font(.system(size: CGFloat(connectionsSheetTitleFontSizePoints), weight: .semibold))
                .foregroundStyle(T.ink)
                .padding(.horizontal, CGFloat(connectionsSheetContentPaddingPoints))
                .padding(.vertical, 6)
            Text(L.pairingLinkHint())
                .font(.system(size: CGFloat(connectionsSheetHintFontSizePoints)))
                .foregroundStyle(T.text3)
                .padding(.horizontal, CGFloat(connectionsSheetContentPaddingPoints))
                .padding(.vertical, 8)
            ZStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L.pairingLink())
                        .font(.system(size: CGFloat(connectionsFieldLabelFontSizePoints)))
                        .foregroundStyle(T.text3)
                        .padding(.leading, 4)
                    // `$text` (not a custom Binding that also writes `pasted`):
                    // XCUI typeText talks to the UITextField; an extra @State
                    // write in the setter can leave SwiftUI `text` on the old
                    // URL while the field shows a concatenation, so parse
                    // stays nil and invalid copy plus disabled 下一步 remain.
                    TextField(L.pairingLinkFieldHint(), text: $text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(size: CGFloat(connectionsFieldFontSizePoints), design: .monospaced))
                        .padding(.horizontal, CGFloat(connectionsFieldHorizontalPaddingPoints))
                        .padding(.vertical, CGFloat(connectionsFieldVerticalPaddingPoints))
                        .background(
                            T.input,
                            in: RoundedRectangle(cornerRadius: CGFloat(connectionsFieldRadiusPoints))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: CGFloat(connectionsFieldRadiusPoints))
                                .stroke(T.border, lineWidth: CGFloat(dswButtonOutlineWidthPoints))
                        )
                        .accessibilityLabel(L.pairingLink())
                        .accessibilityIdentifier(connectionsPairingLinkFieldIdentifier())
                        .onChange(of: text) { _ in
                            if suppressPasteReset {
                                suppressPasteReset = false
                                return
                            }
                            pasted = false
                        }
                }
                // Sibling, not TextField overlay: TextField a11y combines overlays
                // and drops the host. Same UIKit leaf as ComposerAddA11yHost.
                PairingFieldBoundsHost()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
            }
            .padding(.horizontal, CGFloat(connectionsFieldOuterPaddingPoints))
            .padding(.vertical, 4)
            if showInvalid {
                Text(L.invalidPairingLink())
                    .font(.system(size: 12))
                    .foregroundStyle(T.err)
                    .padding(.horizontal, CGFloat(connectionsSheetContentPaddingPoints))
                    .padding(.vertical, 8)
                    .accessibilityIdentifier(connectionsInvalidPairingLinkIdentifier())
            }
            HStack(spacing: 10) {
                Button(action: pasteLink) {
                    Text(L.pastePairingLink())
                        .font(.system(size: CGFloat(dswButtonFontSizePoints)))
                        .frame(maxWidth: .infinity)
                        .frame(height: CGFloat(connectionsPairLinkButtonHeightPoints))
                        .foregroundStyle(T.ink)
                        .overlay(
                            RoundedRectangle(cornerRadius: CGFloat(dswButtonRadiusMdPoints))
                                .stroke(T.border, lineWidth: CGFloat(dswButtonOutlineWidthPoints))
                        )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(connectionsPastePairingLinkIdentifier())
                Button(action: continuePairing) {
                    Text(L.reviewPairingLink())
                        .font(.system(size: CGFloat(dswButtonFontSizePoints)))
                        .frame(maxWidth: .infinity)
                        .frame(height: CGFloat(connectionsPairLinkButtonHeightPoints))
                        .foregroundStyle(T.onPrimary)
                        .background(
                            T.primaryButton,
                            in: RoundedRectangle(cornerRadius: CGFloat(dswButtonRadiusMdPoints))
                        )
                }
                .buttonStyle(.plain)
                .disabled(parsed == nil)
                .opacity(parsed == nil ? dswButtonDisabledOpacity : 1)
                .accessibilityIdentifier(connectionsReviewPairingLinkIdentifier())
            }
            .padding(.horizontal, CGFloat(connectionsSheetContentPaddingPoints))
            .padding(.vertical, 14)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, CGFloat(connectionsSheetDragHandleAreaPoints))
        .background(T.surface)
        .tint(T.ink)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(connectionsPairLinkSheetIdentifier())
    }

    private func pasteLink() {
        let value = UIPasteboard.general.string ?? ""
        if value == text {
            pasted = true
            return
        }
        suppressPasteReset = true
        pasted = true
        text = value
    }

    private func continuePairing() {
        guard let link = parsed else { return }
        onResult(link)
    }
}

/// Ghost「取消」on ConnSheet. Android `PocketSheet` has no cancel row —
/// it dismisses by swipe. Phone still needs a control; 44pt hit is
/// `connectionsSheetCancelMinHeightPoints`.
private func connSheetCancel(identifier: String, action: @escaping () -> Void) -> some View {
    Button(L.cancel(), action: action)
        .buttonStyle(.plain)
        .font(.system(size: CGFloat(dswButtonFontSizePoints)))
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

/// XCUI geometry leaf the same size as the field column. Must be a ZStack
/// sibling of the TextField, not an overlay: TextField a11y combines overlays.
private struct PairingFieldBoundsHost: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = true
        view.accessibilityIdentifier = connectionsPairingLinkFieldBoundsIdentifier()
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        view.accessibilityIdentifier = connectionsPairingLinkFieldBoundsIdentifier()
    }
}

private struct StatusDot: View {
    var color: Color

    var body: some View {
        Circle().fill(color).frame(width: 8, height: 8)
    }
}

