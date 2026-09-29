import Foundation
import Combine
import SwiftUI

/// Orchestrates multiple simultaneous Nebula mesh connections.
@MainActor
class NebulaService: ObservableObject {
    /// Active connections keyed by mesh name.
    @Published var connections: [String: MeshConnection] = [:]

    @AppStorage("nebulaPath") var nebulaPath = "/usr/local/bin/nebula"
    @AppStorage("pollInterval") var pollInterval: Double = 5.0
    @AppStorage("activeConnectionNames") var activeConnectionNamesJSON = "[]"

    private var connectionCancellables: [String: AnyCancellable] = [:]

    // MARK: - Computed

    /// Number of connections in `.connected` state.
    var connectedCount: Int {
        connections.values.filter { $0.state.isConnected }.count
    }

    /// Whether any connection has an error.
    var hasErrors: Bool {
        connections.values.contains { if case .error = $0.state { return true }; return false }
    }

    /// Aggregate state for menu bar icon.
    /// Priority: error > connecting > connected > disconnected.
    /// Returns .disconnected when no connections exist.
    var aggregateState: ConnectionState {
        let states = connections.values.map(\.state)
        if states.isEmpty { return .disconnected }

        // Check for errors first
        if let error = states.first(where: { if case .error = $0 { return true }; return false }) {
            return error
        }
        // Then connecting
        if states.contains(where: { if case .connecting = $0 { return true }; return false }) {
            return .connecting
        }
        // Then connected
        if let connected = states.first(where: { $0.isConnected }) {
            return connected
        }
        return .disconnected
    }

    // MARK: - Actions

    /// Connect to a mesh. Creates a MeshConnection and starts it.
    func connect(mesh: NebulaMesh) {
        guard connections[mesh.name] == nil else { return }

        let connection = MeshConnection(
            mesh: mesh,
            nebulaPath: nebulaPath,
            pollInterval: pollInterval
        )
        connections[mesh.name] = connection

        // Observe this connection's state changes for re-publishing
        connectionCancellables[mesh.name] = connection.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }

        connection.connect()
    }

    /// Disconnect a specific mesh.
    func disconnect(mesh: NebulaMesh) {
        guard let connection = connections[mesh.name] else { return }
        connection.disconnect()
        connections.removeValue(forKey: mesh.name)
        connectionCancellables.removeValue(forKey: mesh.name)
    }

    /// Disconnect all meshes.
    func disconnectAll() {
        for connection in connections.values {
            connection.disconnect()
        }
        connections.removeAll()
        connectionCancellables.removeAll()
    }

    /// Check if a specific mesh is connected.
    func isConnected(mesh: NebulaMesh) -> Bool {
        connections[mesh.name]?.state.isConnected ?? false
    }

    /// Get connection state for a specific mesh.
    func connectionState(for mesh: NebulaMesh) -> ConnectionState {
        connections[mesh.name]?.state ?? .disconnected
    }

    /// Get the MeshConnection object for a mesh (if active).
    func connection(for mesh: NebulaMesh) -> MeshConnection? {
        connections[mesh.name]
    }

    // MARK: - Adopt already-running meshes

    /// Probe each discovered mesh for an active tun interface and adopt it.
    /// Uses ifconfig (ground truth) rather than pgrep, so it works regardless
    /// of how Nebula was started.
    func adoptRunningMeshes(from meshes: [NebulaMesh]) async {
        for mesh in meshes {
            guard connections[mesh.name] == nil else { continue }

            let connection = MeshConnection(
                mesh: mesh,
                nebulaPath: nebulaPath,
                pollInterval: pollInterval
            )

            // Check ifconfig for this mesh's tun device — the ground truth
            await connection.checkStatus()
            guard connection.state.isConnected else { continue }

            connections[mesh.name] = connection

            connectionCancellables[mesh.name] = connection.$state
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.objectWillChange.send()
                }

            connection.startMonitoring()
        }
    }

    // MARK: - Auto-connect persistence

    /// Save currently-connected mesh names for restore on next launch.
    func saveActiveConnections() {
        let names = connections.values
            .filter { $0.state.isConnected || $0.state == .connecting }
            .map(\.mesh.name)
        if let data = try? JSONEncoder().encode(names),
           let json = String(data: data, encoding: .utf8) {
            activeConnectionNamesJSON = json
        }
    }

    /// Restore previously-active connections on launch.
    func autoConnectSavedMeshes(from meshes: [NebulaMesh]) {
        guard let data = activeConnectionNamesJSON.data(using: .utf8),
              let names = try? JSONDecoder().decode([String].self, from: data) else { return }

        for name in names {
            if let mesh = meshes.first(where: { $0.name == name }) {
                connect(mesh: mesh)
            }
        }
    }
}
