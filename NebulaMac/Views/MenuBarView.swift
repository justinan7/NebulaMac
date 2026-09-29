import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var nebulaService: NebulaService
    @EnvironmentObject var configManager: ConfigManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Summary line
            HStack(spacing: 8) {
                Circle()
                    .fill(summaryColor)
                    .frame(width: 8, height: 8)

                Text(summaryText)
                    .font(.system(.body, design: .monospaced))

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            // Mesh list with toggles
            if configManager.meshes.isEmpty {
                Text("No meshes found")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(configManager.meshes) { mesh in
                        MeshRow(mesh: mesh)
                            .padding(.horizontal, 16)

                        if mesh.id != configManager.meshes.last?.id {
                            Divider()
                                .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Divider()

            // Settings & Quit
            SettingsLink {
                Label("Settings...", systemImage: "gear")
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)

            Button(action: {
                nebulaService.saveActiveConnections()
                nebulaService.disconnectAll()
                NSApplication.shared.terminate(nil)
            }) {
                Label("Quit NebulaMac", systemImage: "power")
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .padding(.bottom, 8)
        }
        .frame(width: 300)
    }

    private var summaryText: String {
        let total = configManager.meshes.count
        let connected = nebulaService.connectedCount
        if connected == 0 {
            return "Disconnected"
        }
        return "\(connected) of \(total) connected"
    }

    private var summaryColor: Color {
        switch nebulaService.aggregateState {
        case .disconnected: return .gray
        case .connecting, .disconnecting: return .yellow
        case .connected: return .green
        case .error: return .red
        }
    }
}
