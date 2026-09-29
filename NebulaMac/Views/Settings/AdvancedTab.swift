import SwiftUI
import NebulaMacCore

struct AdvancedTab: View {
    @EnvironmentObject var configManager: ConfigManager
    @AppStorage("nebulaPath") private var nebulaPath = "/usr/local/bin/nebula"
    @AppStorage("nebulaCertPath") private var nebulaCertPath = "/usr/local/bin/nebula-cert"
    @AppStorage("configDirectory") private var configDirectory = "~/.nebula"
    @AppStorage("pollInterval") private var pollInterval: Double = 5.0

    @State private var sudoConfigured = false
    @State private var copied = false

    /// The script ships inside the app; fall back to the repo path when run with `swift run`.
    private var sudoersCommand: String {
        let script = Bundle.main.path(forResource: "install-sudoers", ofType: "sh") ?? "scripts/install-sudoers.sh"
        return "'\(script)' --nebula '\(nebulaPath)'"
    }

    var body: some View {
        Form {
            Section("Nebula") {
                PathField(title: "nebula", path: $nebulaPath,
                          missing: "Not found — install Nebula or fix the path.")
                PathField(title: "nebula-cert", path: $nebulaCertPath,
                          missing: "Not found — network IPs and cert expiry won't be shown.")
                    .onChange(of: nebulaCertPath) { _, _ in Task { await configManager.refreshCerts() } }
                LabeledContent("Config folder") {
                    TextField("", text: $configDirectory).multilineTextAlignment(.trailing)
                }
                LabeledContent("Check status every") {
                    Stepper("\(Int(pollInterval)) s", value: $pollInterval, in: 1...30)
                }
            }

            Section {
                LabeledContent("Passwordless connect") {
                    Text(sudoConfigured ? "On" : "Off").foregroundStyle(.secondary)
                }
                if !sudoConfigured {
                    Text("Optional. Run this once in Terminal so connecting doesn't ask for your password:")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    HStack {
                        Text(sudoersCommand)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .lineLimit(3)
                        Spacer()
                        Button(copied ? "Copied" : "Copy") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(sudoersCommand, forType: .string)
                            copied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                        }
                    }
                }
                HStack {
                    Spacer()
                    Button("Check Again") { checkSudoers() }
                }
            } header: {
                Text("Privileges")
            }
        }
        .formStyle(.grouped)
        .onAppear { checkSudoers() }
    }

    private func checkSudoers() {
        // Read the full `sudo -n -l` listing and look for each mesh's exact start command.
        // (`sudo -n -l <cmd>` exits 0 for any admin once any NOPASSWD rule exists, and
        // `sudo -n true` is deliberately not allowed by the scoped rule.)
        let meshes = configManager.meshes
        guard !meshes.isEmpty else {
            sudoConfigured = false
            return
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        process.arguments = ["-n", "-l"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()
        do {
            try process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            let listing = String(data: data, encoding: .utf8) ?? ""
            sudoConfigured = process.terminationStatus == 0 && meshes.allSatisfy { mesh in
                SudoListing.allowsPasswordless("\(nebulaPath) -config \(mesh.resolvedConfigPath.path)", in: listing)
            }
        } catch {
            sudoConfigured = false
        }
    }
}

/// Monospaced path field with an inline warning when the file isn't executable.
private struct PathField: View {
    let title: String
    @Binding var path: String
    let missing: String

    var body: some View {
        LabeledContent(title) {
            VStack(alignment: .trailing, spacing: 2) {
                TextField("", text: $path)
                    .font(.system(.body, design: .monospaced))
                    .multilineTextAlignment(.trailing)
                if !FileManager.default.isExecutableFile(atPath: path) {
                    Text(missing).font(.caption).foregroundStyle(.orange)
                }
            }
        }
    }
}
