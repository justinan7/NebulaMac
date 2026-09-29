import SwiftUI
import NebulaMacCore

// Pieces shared by the menu row and the Settings mesh list, so both behave identically.

/// Connection-state dot for a mesh.
struct MeshStatusDot: View {
    @EnvironmentObject var nebulaService: NebulaService
    let mesh: NebulaMesh

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
    }

    private var color: Color {
        switch nebulaService.connectionState(for: mesh) {
        case .disconnected: return .gray
        case .connecting, .disconnecting: return .yellow
        case .connected: return .green
        case .error: return .red
        }
    }
}

/// On/off switch for a mesh.
struct MeshToggle: View {
    @EnvironmentObject var nebulaService: NebulaService
    let mesh: NebulaMesh
    /// Called after a disconnect (e.g. to collapse the menu row's peer list).
    var onDisconnect: () -> Void = {}

    var body: some View {
        Toggle("", isOn: Binding(
            get: { nebulaService.connection(for: mesh) != nil },
            set: { newValue in
                if newValue {
                    nebulaService.connect(mesh: mesh)
                } else {
                    nebulaService.disconnect(mesh: mesh)
                    onDisconnect()
                }
            }
        ))
        .toggleStyle(.switch)
        .controlSize(.small)
        .labelsHidden()
        .disabled(!mesh.configExists || nebulaService.connectionState(for: mesh) == .disconnecting)
    }
}

/// Cert expiry (or cert error) line. The menu passes `menuOnly: true` so it only appears
/// when fewer than 90 days remain; Settings always shows it, with the date.
struct CertExpiryText: View {
    let mesh: NebulaMesh
    var menuOnly = false

    var body: some View {
        if let cert = mesh.cert {
            if !menuOnly || cert.showsInMenu() {
                Text(text(for: cert))
                    .font(.caption2)
                    .foregroundStyle(color(cert.expiryLevel()))
            }
        } else if let error = mesh.certError {
            Text(error)
                .font(.caption2)
                .foregroundStyle(.orange)
                .lineLimit(1)
        }
    }

    private func text(for cert: CertInfo) -> String {
        let days = cert.daysUntilExpiry()
        let relative = days >= 0 ? "expires in \(days) days" : "expired \(-days) days ago"
        if menuOnly { return "Cert \(relative)" }
        return "Cert \(relative) (\(cert.notAfter.formatted(date: .abbreviated, time: .omitted)))"
    }

    private func color(_ level: ExpiryLevel) -> Color {
        switch level {
        case .ok: return .secondary
        case .warning: return .orange
        case .expired: return .red
        }
    }
}
