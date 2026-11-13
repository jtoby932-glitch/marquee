import Foundation
import Network
import Observation

/// Watches the connection so screens can show a calm offline state.
@MainActor @Observable
final class NetworkMonitor {
    private(set) var isOnline = true
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "marquee.network-monitor")

    /// `forcedOffline` lets screenshots and UI tests show the offline state.
    init(forcedOffline: Bool = false) {
        if forcedOffline {
            isOnline = false
            return
        }
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in
                guard let self, self.isOnline != online else { return }
                self.isOnline = online
                AppLog.info(.network, online ? "Back online" : "Went offline")
            }
        }
        monitor.start(queue: queue)
    }
}
