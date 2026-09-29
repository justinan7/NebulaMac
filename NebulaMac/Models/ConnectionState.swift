import Foundation

/// Represents the current state of the Nebula VPN connection.
enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case disconnecting
    case connected(ip: String, latency: Double?)
    case error(String)

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    var statusText: String {
        switch self {
        case .disconnected:
            return "Not connected"
        case .connecting:
            return "Connecting..."
        case .disconnecting:
            return "Disconnecting..."
        case .connected(let ip, let latency):
            if let latency {
                return "\(ip) • \(String(format: "%.1f", latency))ms"
            }
            return ip
        case .error(let message):
            return "Error: \(message)"
        }
    }

    var sfSymbolName: String {
        switch self {
        case .disconnected: return "network.slash"
        case .connecting, .disconnecting: return "network.badge.shield.half.filled"
        case .connected: return "network"
        case .error: return "exclamationmark.triangle"
        }
    }
}
