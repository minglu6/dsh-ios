import Foundation
import Network
import DSHProtocol

/// Bonjour browser for `_dshpocket._tcp`.
final class LanDiscovery {
    var onHosts: (([DiscoveredHost]) -> Void)?
    private var browser: NWBrowser?
    private let lock = NSLock()
    private var found: [String: DiscoveredHost] = [:]

    func start() {
        let params = NWParameters()
        params.includePeerToPeer = true
        let browser = NWBrowser(for: .bonjourWithTXTRecord(type: "_dshpocket._tcp", domain: "local."), using: params)
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            self?.handle(results)
        }
        browser.stateUpdateHandler = { state in
            if case .failed(let error) = state {
                NSLog("mdns failed: \(error)")
            }
        }
        self.browser = browser
        browser.start(queue: .global(qos: .utility))
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
            var port = 0
            var instanceId = ""
            var deviceName = result.endpoint.debugDescription
            if case .bonjour(let record) = result.metadata {
                host = record["host"] ?? ""
                port = Int(record["port"] ?? "") ?? 0
                instanceId = record["instanceId"] ?? ""
                if let name = record["deviceName"], !name.isEmpty { deviceName = name }
            }
            if host.isEmpty || !(1...65535).contains(port) { continue }
            let discovered = DiscoveredHost(instanceId: instanceId, host: host, port: port, deviceName: deviceName)
            next[discovered.id] = discovered
        }
        lock.lock()
        found = next
        let hosts = Array(next.values)
        lock.unlock()
        onHosts?(hosts)
    }
}
