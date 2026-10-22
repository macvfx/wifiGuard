import Network

/// Tracks whether a non-Wi-Fi connection (Ethernet, Thunderbolt/USB adapter, cellular tether)
/// is up, so Wi-Fi is never turned off when it is the only way online.
final class OtherPathMonitor {
    private let queue = DispatchQueue(label: "wifiguard.paths")
    private var monitors: [NWPathMonitor] = []
    private var satisfied: [NWInterface.InterfaceType: Bool] = [:]

    init() {
        for type in [NWInterface.InterfaceType.wiredEthernet, .cellular] {
            let monitor = NWPathMonitor(requiredInterfaceType: type)
            monitor.pathUpdateHandler = { [weak self] path in
                self?.satisfied[type] = path.status == .satisfied
            }
            monitor.start(queue: queue)
            monitors.append(monitor)
        }
    }

    var hasOtherPath: Bool {
        queue.sync { satisfied.values.contains(true) }
    }
}
