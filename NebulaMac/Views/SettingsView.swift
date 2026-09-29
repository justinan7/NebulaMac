import SwiftUI
import NebulaMacCore
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject var nebulaService: NebulaService
    @EnvironmentObject var configManager: ConfigManager
    @AppStorage("nebulaPath") private var nebulaPath = "/usr/local/bin/nebula"
    @AppStorage("nebulaCertPath") private var nebulaCertPath = "/usr/local/bin/nebula-cert"
    @AppStorage("configDirectory") private var configDirectory = "~/.nebula"
    @AppStorage("autoConnect") private var autoConnect = false
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("pollInterval") private var pollInterval: Double = 5.0
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("iconArmMode") private var iconArmMode = IconArmMode.perNetwork.rawValue

    @State private var sudoConfigured = false
    @State private var copiedSudoers = false

    /// Run from the NebulaMac repo; generates a rule scoped to each mesh config.
    private let sudoersCommand = "scripts/install-sudoers.sh"

    private var nebulaExists: Bool {
        FileManager.default.fileExists(atPath: nebulaPath)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: "network")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text("NebulaMac")
                        .font(.title2.bold())
                    Text("Mesh VPN Manager")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Live status badge
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text(statusLabel)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(statusColor.opacity(0.1))
                .clipShape(Capsule())
            }
            .padding(20)
            .background(.ultraThinMaterial)

            Divider()

            // Settings form
            Form {
                Section {
                    HStack {
                        Label("Binary path", systemImage: "terminal")
                            .foregroundStyle(.primary)
                        Spacer()
                        TextField("", text: $nebulaPath)
                            .font(.system(.body, design: .monospaced))
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 220)
                    }
                    .overlay(alignment: .trailing) {
                        if !nebulaExists {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.yellow)
                                .font(.caption)
                                .offset(x: 20)
                        }
                    }

                    HStack {
                        Label("Config directory", systemImage: "folder")
                            .foregroundStyle(.primary)
                        Spacer()
                        TextField("", text: $configDirectory)
                            .font(.system(.body, design: .monospaced))
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 220)
                    }

                    if !nebulaExists {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.yellow)
                            Text("Nebula binary not found at path")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    HStack {
                        Label("nebula-cert path", systemImage: "checkmark.seal")
                            .foregroundStyle(.primary)
                        Spacer()
                        TextField("", text: $nebulaCertPath)
                            .font(.system(.body, design: .monospaced))
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 220)
                            .onChange(of: nebulaCertPath) { _, _ in
                                Task { await configManager.refreshCerts() }
                            }
                    }

                    if !FileManager.default.isExecutableFile(atPath: nebulaCertPath) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.yellow)
                            Text("nebula-cert not found — cert expiry won't be shown")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Label("Nebula", systemImage: "shield.lefthalf.filled")
                        .foregroundStyle(.blue)
                        .font(.headline)
                }

                Section {
                    Toggle(isOn: $autoConnect) {
                        Label("Auto-connect on launch", systemImage: "bolt.fill")
                            .foregroundStyle(autoConnect ? .blue : .primary)
                    }
                    .tint(.blue)

                    Toggle(isOn: $launchAtLogin) {
                        Label("Launch at login", systemImage: "power")
                            .foregroundStyle(launchAtLogin ? .green : .primary)
                    }
                    .tint(.green)
                    .onChange(of: launchAtLogin) { _, newValue in
                        setLaunchAtLogin(newValue)
                    }

                    Toggle(isOn: $notificationsEnabled) {
                        Label("Notifications", systemImage: "bell.fill")
                            .foregroundStyle(notificationsEnabled ? .purple : .primary)
                    }
                    .tint(.purple)

                    Picker(selection: $iconArmMode) {
                        Text("One arm per network").tag(IconArmMode.perNetwork.rawValue)
                        Text("Classic three arms").tag(IconArmMode.threeArms.rawValue)
                    } label: {
                        Label("Menu bar icon", systemImage: "hurricane")
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Label("Status poll interval", systemImage: "clock.arrow.2.circlepath")
                            Spacer()
                            Text("\(Int(pollInterval))s")
                                .font(.system(.body, design: .monospaced, weight: .medium))
                                .foregroundStyle(.blue)
                                .frame(width: 36, alignment: .trailing)
                        }
                        Slider(value: $pollInterval, in: 1...30, step: 1)
                            .tint(.blue)
                    }
                } header: {
                    Label("Behavior", systemImage: "gearshape.2")
                        .foregroundStyle(.indigo)
                        .font(.headline)
                }

                Section {
                    HStack {
                        Label("Meshes discovered", systemImage: "point.3.connected.trianglepath.dotted")
                        Spacer()
                        Text("\(configManager.meshes.count)")
                            .font(.system(.body, design: .monospaced, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    ForEach(configManager.meshes) { mesh in
                        HStack(spacing: 8) {
                            if mesh.configExists {
                                MeshStatusDot(mesh: mesh)
                            } else {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.red)
                                    .font(.caption)
                            }

                            VStack(alignment: .leading, spacing: 1) {
                                Text(mesh.name)
                                    .font(.system(.body, design: .monospaced))
                                CertExpiryText(mesh: mesh)
                                ForEach(mesh.warnings, id: \.self) { warning in
                                    Text(warning)
                                        .font(.caption2)
                                        .foregroundStyle(.orange)
                                        .lineLimit(1)
                                }
                            }

                            Spacer()

                            if !mesh.lighthouseIP.isEmpty {
                                Text(mesh.lighthouseIP)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }

                            MeshToggle(mesh: mesh)
                        }
                    }

                    Button(action: { Task { await configManager.reload() } }) {
                        Label("Rescan configs", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                } header: {
                    Label("Meshes", systemImage: "network")
                        .foregroundStyle(.teal)
                        .font(.headline)
                }

                Section {
                    HStack(spacing: 8) {
                        Image(systemName: sudoConfigured ? "checkmark.shield.fill" : "xmark.shield.fill")
                            .foregroundStyle(sudoConfigured ? .green : .orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(sudoConfigured ? "Passwordless sudo configured" : "Password required for connect/disconnect")
                                .font(.callout)
                            if !sudoConfigured {
                                Text("Run the command below in Terminal to enable passwordless mode.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if !sudoConfigured {
                        HStack {
                            Text(sudoersCommand)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .textSelection(.enabled)

                            Spacer()

                            Button(action: {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(sudoersCommand, forType: .string)
                                copiedSudoers = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    copiedSudoers = false
                                }
                            }) {
                                Image(systemName: copiedSudoers ? "checkmark" : "doc.on.doc")
                                    .foregroundStyle(copiedSudoers ? .green : .blue)
                            }
                            .buttonStyle(.plain)
                            .help("Copy to clipboard")
                        }
                        .padding(8)
                        .background(Color.black.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }

                    Button(action: { checkSudoers() }) {
                        Label("Recheck sudo status", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                } header: {
                    Label("Privileges", systemImage: "lock.shield")
                        .foregroundStyle(.orange)
                        .font(.headline)
                }
            }
            .formStyle(.grouped)

            // Footer
            HStack {
                Text("v1.0.0")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.quaternary)
                Spacer()
                Text("Nebula \(nebulaVersion)")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.quaternary)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .frame(width: 480, height: 580)
        .onAppear { checkSudoers() }
    }

    // MARK: - Computed

    private var statusColor: Color {
        switch nebulaService.aggregateState {
        case .disconnected: return .red
        case .connecting, .disconnecting: return .yellow
        case .connected: return .green
        case .error: return .red
        }
    }

    private var statusLabel: String {
        let count = nebulaService.connectedCount
        switch nebulaService.aggregateState {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting"
        case .disconnecting: return "Disconnecting"
        case .connected: return "\(count) connected"
        case .error: return "Error"
        }
    }

    private var nebulaVersion: String {
        guard let result = try? runSync("/usr/local/bin/nebula", args: ["-version"]) else {
            return "unknown"
        }
        // Output: "Version: 1.10.0"
        return result.replacingOccurrences(of: "Version: ", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Actions

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

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to \(enabled ? "register" : "unregister") login item: \(error)")
        }
    }

    private func runSync(_ command: String, args: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }
}
