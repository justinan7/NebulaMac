import SwiftUI
import NebulaMacCore

/// A row displaying a single mesh with connection toggle and expandable peers.
struct MeshRow: View {
    @EnvironmentObject var nebulaService: NebulaService
    let mesh: NebulaMesh

    @State private var isExpanded = false

    private var connection: MeshConnection? {
        nebulaService.connection(for: mesh)
    }

    private var state: ConnectionState {
        nebulaService.connectionState(for: mesh)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row
            HStack(spacing: 8) {
                MeshStatusDot(mesh: mesh)

                // Mesh name + status
                VStack(alignment: .leading, spacing: 1) {
                    Text(mesh.name)
                        .font(.system(.body, design: .monospaced))

                    if state.isConnected {
                        Text(state.statusText)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                    } else if case .connecting = state {
                        Text("Connecting...")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else if case .disconnecting = state {
                        Text("Disconnecting...")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else if case .error(let msg) = state {
                        Text(msg)
                            .font(.caption2)
                            .foregroundStyle(.red)
                            .lineLimit(1)
                    }

                    CertExpiryText(mesh: mesh, menuOnly: true)

                    ForEach(mesh.warnings, id: \.self) { warning in
                        Text(warning)
                            .font(.caption2)
                            .foregroundStyle(.orange)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Connecting spinner
                if case .connecting = state {
                    ProgressView()
                        .controlSize(.small)
                } else if case .disconnecting = state {
                    ProgressView()
                        .controlSize(.small)
                }

                // Expand peers button (when connected and has peers)
                if let conn = connection, state.isConnected, !conn.peers.isEmpty {
                    Button(action: { isExpanded.toggle() }) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                MeshToggle(mesh: mesh, onDisconnect: { isExpanded = false })
            }
            .padding(.vertical, 4)

            // Expanded peers
            if isExpanded, let conn = connection, !conn.peers.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(conn.peers) { peer in
                        PeerRow(peer: peer)
                            .padding(.leading, 16)
                    }
                }
                .padding(.bottom, 4)
            }
        }
    }
}
