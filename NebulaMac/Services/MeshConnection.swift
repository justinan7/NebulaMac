import Foundation
import NebulaMacCore
import Combine
import SwiftUI

/// Manages a single Nebula mesh connection lifecycle.
/// Each instance owns its state, peers, monitoring, and connect/disconnect logic.
@MainActor
class MeshConnection: ObservableObject, Identifiable {
    var id: String { mesh.name }

    let mesh: NebulaMesh

    @Published var state: ConnectionState = .disconnected
    @Published var peers: [PeerInfo] = []

    private var monitor: NetworkMonitor?
    private var monitorCancellables = Set<AnyCancellable>()
    private var connectTask: Task<Void, Never>?

    /// Read from NebulaService's shared AppStorage values.
    private let nebulaPath: String
    private let pollInterval: TimeInterval

    /// The discovered tun device for this connection (e.g., "utun3").
    private(set) var tunDevice: String?

    init(mesh: NebulaMesh, nebulaPath: String, pollInterval: TimeInterval) {
        self.mesh = mesh
        self.nebulaPath = nebulaPath
        self.pollInterval = pollInterval
    }

    /// Connect to this mesh. Adopts an already-running process if detected.
    func connect() {
        guard !state.isConnected else { return }

        guard mesh.configExists else {
            state = .error("Config not found: \(mesh.configPath)")
            return
        }

        guard FileManager.default.fileExists(atPath: nebulaPath) else {
            state = .error("Nebula not found at \(nebulaPath)")
            return
        }

        state = .connecting

        let path = nebulaPath
        let configPath = mesh.resolvedConfigPath.path
        let meshName = mesh.name
        let meshIP = mesh.localIP
        let certError = mesh.certError ?? "cert not loaded yet"

        connectTask?.cancel()
        connectTask = Task.detached { [weak self] in
            do {
                // Check if already running (e.g., orphaned from previous session)
                let alreadyRunning = await PrivilegeHelper.isNebulaRunning(configPath: configPath)
                if !alreadyRunning {
                    try await PrivilegeHelper.startNebulaDaemon(
                        nebulaPath: path,
                        configPath: configPath,
                        meshName: meshName
                    )
                }

                // Without the cert IP we can't tell this mesh's utun from another mesh's.
                // Nebula is started (disconnect still works by config path), but don't guess.
                guard meshIP != nil else {
                    await MainActor.run {
                        self?.state = .error("Can't identify mesh IP — \(certError)")
                    }
                    return
                }

                // Poll for the tun interface to come up (up to 15 seconds)
                for attempt in 1...15 {
                    try await Task.sleep(for: .seconds(1))

                    await self?.checkStatus()

                    let isConnected = await self?.state.isConnected ?? false
                    if isConnected {
                        await self?.startMonitoring()
                        return
                    }

                    // Check if process died
                    if attempt > 3 {
                        let stillRunning = await PrivilegeHelper.isNebulaRunning(configPath: configPath)
                        if !stillRunning {
                            await MainActor.run {
                                self?.state = .error("Nebula exited — check /tmp/nebula-mac-\(meshName).log")
                            }
                            return
                        }
                    }
                }

                // Timed out
                await MainActor.run {
                    if self?.state.isConnected != true {
                        self?.state = .error("Timed out waiting for tun interface")
                    }
                }
            } catch is CancellationError {
                // Task was cancelled
            } catch {
                await MainActor.run {
                    self?.state = .error("Failed to start: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Disconnect from this mesh.
    func disconnect() {
        connectTask?.cancel()
        connectTask = nil
        stopMonitoring()

        state = .disconnecting
        let configPath = mesh.resolvedConfigPath.path

        Task { [weak self] in
            do {
                try await PrivilegeHelper.stopNebulaDaemon(configPath: configPath)
            } catch {
                print("[MeshConnection] Failed to stop daemon for \(configPath): \(error)")
            }

            // Verify the process is actually gone
            let stillRunning = await PrivilegeHelper.isNebulaRunning(configPath: configPath)
            await MainActor.run {
                if stillRunning {
                    self?.state = .error("Failed to stop Nebula — process still running")
                } else {
                    self?.state = .disconnected
                    self?.peers = []
                    self?.tunDevice = nil
                }
            }
        }
    }

    /// Check status by inspecting ifconfig for this mesh's expected IP.
    func checkStatus() async {
        do {
            let result = try await ShellCommand.run("/sbin/ifconfig")

            if let ip = mesh.localIP, let device = TunMatcher.device(for: ip, in: result.stdout) {
                tunDevice = device

                var latency: Double?
                if !mesh.lighthouseIP.isEmpty {
                    latency = await pingLatency(host: mesh.lighthouseIP)
                }

                state = .connected(ip: ip, latency: latency)
            } else {
                let configPath = mesh.resolvedConfigPath.path
                if await PrivilegeHelper.isNebulaRunning(configPath: configPath) {
                    if case .connecting = state {
                        // Still connecting, keep that state
                    } else {
                        state = .connecting
                    }
                } else if state.isConnected || (state == .connecting) {
                    state = .disconnected
                    peers = []
                    tunDevice = nil
                }
            }
        } catch {
            state = .error("Status check failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Private

    func startMonitoring() {
        stopMonitoring()

        guard let tunDevice, let localIP = mesh.localIP else { return }

        let monitor = NetworkMonitor(
            tunDevice: tunDevice,
            expectedIP: localIP,
            pollInterval: pollInterval,
            lighthouseIP: mesh.lighthouseIP.isEmpty ? nil : mesh.lighthouseIP
        )
        self.monitor = monitor

        monitor.$connectionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newState in
                guard let self else { return }
                if let newState {
                    self.state = newState
                    if case .disconnected = newState {
                        self.peers = []
                        self.tunDevice = nil
                    }
                }
            }
            .store(in: &monitorCancellables)

        monitor.start()
    }

    private func stopMonitoring() {
        monitor?.stop()
        monitor = nil
        monitorCancellables.removeAll()
    }

    private func pingLatency(host: String) async -> Double? {
        do {
            let result = try await ShellCommand.run(
                "/sbin/ping",
                args: ["-c", "1", "-W", "1000", host]
            )
            if let range = result.stdout.range(of: #"= [\d.]+/([\d.]+)/"#, options: .regularExpression) {
                let match = result.stdout[range]
                let parts = match.split(separator: "/")
                if parts.count >= 2, let avg = Double(parts[1]) {
                    return avg
                }
            }
            return nil
        } catch {
            return nil
        }
    }
}
