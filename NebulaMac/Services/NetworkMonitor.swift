import Foundation
import NebulaMacCore
import Combine

/// Polls a specific tun interface and lighthouse to monitor connection health.
/// Must be created and used from the main actor (uses Timer.scheduledTimer on main run loop).
@MainActor
class NetworkMonitor: ObservableObject {
    @Published var connectionState: ConnectionState?

    private let tunDevice: String
    private let expectedIP: String
    private let pollInterval: TimeInterval
    private let lighthouseIP: String?
    private var timer: Timer?
    private var isRunning = false

    init(tunDevice: String, expectedIP: String, pollInterval: TimeInterval = 5.0, lighthouseIP: String? = nil) {
        self.tunDevice = tunDevice
        self.expectedIP = expectedIP
        self.pollInterval = pollInterval
        self.lighthouseIP = lighthouseIP
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true

        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task {
                await self.poll()
            }
        }
    }

    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    private func poll() async {
        do {
            // Check only our specific tun device
            let result = try await ShellCommand.run("/sbin/ifconfig", args: [tunDevice])

            if let ip = findIP(in: result.stdout) {
                let latency: Double? = if let lighthouse = lighthouseIP {
                    await measureLatency(to: lighthouse)
                } else {
                    nil
                }
                await MainActor.run {
                    self.connectionState = .connected(ip: ip, latency: latency)
                }
            } else {
                // Interface gone or IP missing — disconnected
                await MainActor.run {
                    self.connectionState = .disconnected
                }
                stop()
            }
        } catch {
            // ifconfig failed (device doesn't exist) — disconnected
            await MainActor.run {
                self.connectionState = .disconnected
            }
            stop()
        }
    }

    /// Find the expected IP in ifconfig output for a single device.
    private func findIP(in output: String) -> String? {
        let lines = output.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("inet ") {
                let parts = trimmed.split(separator: " ")
                if parts.count >= 2 {
                    let ip = String(parts[1])
                    if ip == expectedIP {
                        return ip
                    }
                }
            }
        }
        return nil
    }

    private func measureLatency(to host: String) async -> Double? {
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
