import SwiftUI

struct PeerRow: View {
    let peer: PeerInfo

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: peer.isLighthouse ? "antenna.radiowaves.left.and.right" : "desktopcomputer")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(peer.displayName)
                    .font(.system(.caption, design: .monospaced))

                Text(peer.nebulaIP)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let latencyText = peer.latencyText {
                Text(latencyText)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
