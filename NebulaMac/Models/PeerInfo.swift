import Foundation

/// Represents a connected peer in the Nebula mesh.
struct PeerInfo: Identifiable, Equatable {
    var id: String { nebulaIP }
    let name: String
    let nebulaIP: String
    let remoteAddress: String?
    let isLighthouse: Bool
    let latency: Double?

    var displayName: String {
        name.isEmpty ? nebulaIP : name
    }

    var latencyText: String? {
        guard let latency else { return nil }
        return "\(String(format: "%.1f", latency))ms"
    }
}
