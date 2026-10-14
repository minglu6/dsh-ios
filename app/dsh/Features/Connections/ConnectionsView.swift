import SwiftUI
import DSHProtocol

struct ConnectionsView: View {
    @ObservedObject var model: AppModel
    @State private var showPair = false
    @State private var showScan = false
    @State private var address = ""
    @State private var code = ""
    @State private var name = ""
    @State private var pairing = false

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    actions
                    if !model.nearby.isEmpty {
                        section(L.nearbyDevices()) {
                            ForEach(model.nearby) { host in
                                Button {
                                    address = "\(host.host):\(host.port)"
                                    showPair = true
                                } label: {
                                    ConnRow(title: host.deviceName, subtitle: "\(host.host):\(host.port)")
                                }
                            }
                        }
                    }
                    section(L.pairedDevices()) {
                        if model.profiles.isEmpty {
                            Text(L.notConnected())
                                .font(.subheadline)
                                .foregroundStyle(T.text3)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 12)
                        }
                        ForEach(model.profiles) { profile in
                            profileRow(profile)
                        }
                    }
                }
                .padding(.vertical, 12)
            }
            .background(T.bg)
        }
        .background(T.bg.ignoresSafeArea())
        .sheet(isPresented: $showPair) { pairSheet }
        .fullScreenCover(isPresented: $showScan) {
            QRScannerView(
                onCode: { value in
                    showScan = false
                    if let link = PairingUriPolicy.parse(value) {
                        address = "\(link.host):\(link.port)"
                        code = link.code
                        showPair = true
                    } else {
                        model.errorMessage = L.pairFailed()
                    }
                },
                onCancel: { showScan = false }
            )
            .ignoresSafeArea()
        }
        .onAppear {
            if let pending = model.pendingPair {
                address = "\(pending.host):\(pending.port)"
                code = pending.code
                model.pendingPair = nil
                showPair = true
            }
        }
    }

    private var header: some View {
        HStack {
            Button(action: model.pop) { Image(systemName: "chevron.left").foregroundStyle(T.ink) }
            Text(L.phoneConnection()).font(.headline).foregroundStyle(T.ink)
            Spacer()
            Menu {
                Button(L.diagnosticsCopy()) { Task { _ = await model.copyDiagnostics() } }
            } label: {
                Image(systemName: "ellipsis").foregroundStyle(T.ink).padding(8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(T.surface)
    }

    private var actions: some View {
        HStack(spacing: 10) {
            actionChip(L.scanQr(), system: "qrcode.viewfinder") { showScan = true }
            actionChip(L.enterAddress(), system: "keyboard") { showPair = true }
        }
        .padding(.horizontal, 16)
    }

    private func actionChip(_ title: String, system: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: system)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(T.onPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(T.primaryButton, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(.caption).foregroundStyle(T.text3).padding(.horizontal, 22).padding(.bottom, 6)
            VStack(spacing: 0) { content() }
                .background(T.settingsCard, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(T.settingsCardStroke, lineWidth: 0.5))
                .padding(.horizontal, 16)
        }
    }

    private func profileRow(_ profile: Profile) -> some View {
        let dot = model.status[profile.id]
        return Button {
            model.connect(profileId: profile.id)
            model.pop()
        } label: {
            ConnRow(
                title: profile.name,
                subtitle: profile.needsRepair ? L.repairNeeded() : "\(profile.host):\(profile.port) · \(profile.kind)",
                trailing: statusLabel(dot, current: profile.id == model.activeId)
            )
        }
        .contextMenu {
            Button(L.switchDevice()) { model.connect(profileId: profile.id) }
            Button(L.delete(), role: .destructive) { model.removeProfile(profile.id) }
        }
    }

    private func statusLabel(_ dot: Dot?, current: Bool) -> some View {
        HStack(spacing: 6) {
            Circle().fill(dotColor(dot)).frame(width: 8, height: 8)
            Text(current ? L.currentDevice() : dotText(dot)).font(.caption).foregroundStyle(T.text3)
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

    private var pairSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                field(L.addressField(), text: $address, hint: L.pairingUriHint(), mono: true)
                field(L.nameField(), text: $name, hint: L.nameHint(), mono: false)
                if !address.contains("dshpocket://") {
                    field("Code", text: $code, hint: "123456", mono: true)
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
                    Button(L.cancel()) { showPair = false }
                }
            }
        }
    }

    private func field(_ label: String, text: Binding<String>, hint: String, mono: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(T.text3)
            TextField(hint, text: text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(mono ? .system(.body, design: .monospaced) : .body)
                .padding(12)
                .background(T.input, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(T.border, lineWidth: 0.5))
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
            showPair = false
            model.pop()
        } catch let error as PocketError where error.code == "timeout" {
            model.errorMessage = L.pairTimeout()
        } catch {
            model.errorMessage = error.localizedDescription
        }
    }
}

private struct ConnRow<Trailing: View>: View {
    var title: String
    var subtitle: String
    var trailing: Trailing

    init(title: String, subtitle: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    init(title: String, subtitle: String) where Trailing == EmptyView {
        self.title = title
        self.subtitle = subtitle
        self.trailing = EmptyView()
    }

    init(title: String, subtitle: String, trailing: Trailing) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).foregroundStyle(T.ink)
                Text(subtitle).font(.caption).foregroundStyle(T.text3)
            }
            Spacer()
            trailing
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
