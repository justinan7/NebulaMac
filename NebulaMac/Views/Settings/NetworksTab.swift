import SwiftUI

struct NetworksTab: View {
    @EnvironmentObject var configManager: ConfigManager

    var body: some View {
        Form {
            Section {
                if configManager.meshes.isEmpty {
                    Text("No networks found. Add a config to ~/.nebula/meshes/ — see the README.")
                        .foregroundStyle(.secondary)
                }
                ForEach(configManager.meshes) { mesh in
                    NetworkRow(mesh: mesh)
                }
            } footer: {
                HStack {
                    Spacer()
                    Button("Rescan Configs") { Task { await configManager.reload() } }
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct NetworkRow: View {
    let mesh: NebulaMesh

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            if mesh.configExists {
                MeshStatusDot(mesh: mesh)
            } else {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(mesh.name).fontWeight(.medium)
                    if let ip = mesh.localIP {
                        Text(ip).monospacedDigit().foregroundStyle(.secondary)
                    }
                }
                CertExpiryText(mesh: mesh)
                ForEach(mesh.warnings, id: \.self) { warning in
                    Label(warning, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            Spacer()
            MeshToggle(mesh: mesh)
        }
    }
}
