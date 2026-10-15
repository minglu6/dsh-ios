import Foundation
import Network
import DSHProtocol

/// Bonjour browser for `_dshpocket._tcp`. TXT must be protocol 1 + 64-hex instanceId.
final class LanDiscovery {
    var onHosts: (([DiscoveredHost]) -> Void)?
    private var browser: NWBrowser?
    private let queue = DispatchQueue(label: "dev.dsh.pocket.ios.mdns")
    private var found: [String: DiscoveredHost] = [:]

    func start() {
        let params = NWParameters()
        params.includePeerToPeer = true
        let browser = NWBrowser(for: .bonjourWithTXTRecord(type: LanDiscoveryPolicy.serviceType, domain: "local."), using: params)
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            self?.handle(results)
        }
        browser.stateUpdateHandler = { state in
            if case .failed(let error) = state {
                NSLog("mdns failed: \(error)")
            }
        }
        self.browser = browser
        browser.start(queue: queue)
    }

    func stop() {
        browser?.cancel()
        browser = nil
    }

    private func handle(_ results: Set<NWBrowser.Result>) {
        var next: [String: DiscoveredHost] = [:]
        for result in results {
            guard case .service(_, _, _, _) = result.endpoint else { continue }
            var host = ""
            var port: Int?
            var instanceId = ""
            var deviceName: String?
            var protocolValue: Int?
            if case .bonjour(let record) = result.metadata {
                host = record["host"] ?? ""
                port = Int(record["port"] ?? "")
                instanceId = record["instanceId"] ?? ""
                deviceName = record["deviceName"]
                protocolValue = Int(record["protocol"] ?? "")
            }
            if let discovered = LanDiscoveryPolicy.parseTxt(
                deviceName: deviceName,
                host: host,
                port: port,
                protocolValue: protocolValue,
                instanceId: instanceId
            ) {
                next[discovered.id] = discovered
            }
        }
        found = next
        onHosts?(LanDiscoveryPolicy.mergeByInstance(Array(next.values)))
    }
}
