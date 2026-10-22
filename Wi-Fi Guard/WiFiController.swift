import CoreWLAN
import Foundation

/// Thin wrapper over CoreWLAN: reads and sets Wi-Fi power and reports power changes.
final class WiFiController: NSObject, CWEventDelegate {
    private let client = CWWiFiClient.shared()
    var onPowerChange: (() -> Void)?

    override init() {
        super.init()
        client.delegate = self
        try? client.startMonitoringEvent(with: .powerDidChange)
    }

    var hasInterface: Bool { client.interface() != nil }

    var isOn: Bool { client.interface()?.powerOn() ?? false }

    var isAssociated: Bool { client.interface()?.ssid() != nil }

    func setPower(_ on: Bool) throws {
        guard let interface = client.interface() else {
            throw NSError(domain: "WiFiGuard", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "No Wi-Fi interface found"])
        }
        try interface.setPower(on)
    }

    // MARK: CWEventDelegate

    func powerStateDidChangeForWiFiInterface(withName interfaceName: String) {
        onPowerChange?()
    }
}
