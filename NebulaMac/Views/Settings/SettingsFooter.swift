import SwiftUI
import NebulaMacCore

/// Swirl, app version and detected Nebula version, shown under every tab.
struct SettingsFooter: View {
    @AppStorage("nebulaPath") private var nebulaPath = "/usr/local/bin/nebula"
    @State private var nebulaVersion = "…"

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(nsImage: SwirlIconRenderer.image(
                for: SwirlModel.make(states: [.on], mode: .threeArms), size: NSSize(width: 14, height: 14)))
                .foregroundStyle(.secondary)
            Text("NebulaMac \(appVersion)")
            Spacer()
            Text("Nebula \(nebulaVersion)")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .task(id: nebulaPath) { nebulaVersion = await Self.version(of: nebulaPath) }
    }

    /// `nebula -version` prints "Version: 1.10.0".
    private static func version(of path: String) async -> String {
        await Task.detached {
            guard FileManager.default.isExecutableFile(atPath: path) else { return "not found" }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = ["-version"]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            guard (try? process.run()) != nil else { return "unknown" }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            let text = String(data: data, encoding: .utf8) ?? ""
            return text.replacingOccurrences(of: "Version: ", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }.value
    }
}
