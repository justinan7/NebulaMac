import Foundation
import NebulaMacCore

/// Handles privilege escalation for operations requiring root access.
///
/// Prefers passwordless sudo (via sudoers rule) for seamless UX.
/// Falls back to AppleScript password prompt if sudoers not configured.
///
/// To enable passwordless mode, run `scripts/install-sudoers.sh` from the repo: it installs a
/// rule scoped to exactly the commands below for each mesh config.
enum PrivilegeHelper {
    /// Start the Nebula daemon with root privileges.
    /// Backgrounds the process and returns immediately.
    /// Each mesh gets its own log file at /tmp/nebula-mac-<meshname>.log.
    static func startNebulaDaemon(
        nebulaPath: String,
        configPath: String,
        meshName: String
    ) async throws {
        let logPath = "/tmp/nebula-mac-\(meshName).log"

        // Passwordless sudo first; DaemonLauncher reads the log to see whether sudo refused
        // (the backgrounded shell always exits 0, so its exit code can't tell us).
        let outcome = try await DaemonLauncher.launchWithoutPassword(
            nebulaPath: nebulaPath,
            configPath: configPath,
            logPath: logPath
        )
        if outcome == .needsPassword {
            let appleCmd = "\(nebulaPath) -config \(configPath) > \(logPath) 2>&1 & echo $!"
            try await runAppleScript(appleCmd)
        }
    }

    /// Stop a specific Nebula daemon by its config path.
    static func stopNebulaDaemon(configPath: String) async throws {
        // Try passwordless sudo first — no 2>&1 so stderr stays on the stderr pipe
        let result = try await ShellCommand.run(
            "/bin/sh",
            args: ["-c", "sudo -n /usr/bin/pkill -f 'nebula -config \(configPath)'"]
        )

        let needsPassword = result.exitCode != 0
            && (result.stderr.contains("password is required")
                || result.stdout.contains("password is required"))

        if needsPassword {
            _ = try await ShellCommand.runPrivileged(
                "/usr/bin/pkill",
                args: ["-f", "nebula -config \(configPath)"]
            )
        }

        // Verify kill, escalate to SIGKILL if still alive
        try? await Task.sleep(for: .milliseconds(500))
        if await isNebulaRunning(configPath: configPath) {
            _ = try await ShellCommand.run(
                "/bin/sh",
                args: ["-c", "sudo -n /usr/bin/pkill -9 -f 'nebula -config \(configPath)'"]
            )
        }
    }

    /// Check if a specific Nebula mesh is currently running (no root needed).
    static func isNebulaRunning(configPath: String) async -> Bool {
        do {
            let result = try await ShellCommand.run(
                "/usr/bin/pgrep",
                args: ["-f", "nebula -config \(configPath)"]
            )
            return result.exitCode == 0
        } catch {
            return false
        }
    }

    /// Check if any Nebula process is running (no root needed).
    static func isAnyNebulaRunning() async -> Bool {
        do {
            let result = try await ShellCommand.run(
                "/usr/bin/pgrep",
                args: ["-f", "nebula -config"]
            )
            return result.exitCode == 0
        } catch {
            return false
        }
    }

    // MARK: - Private

    /// Run a command with administrator privileges via AppleScript (shows password dialog).
    private static func runAppleScript(_ command: String) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = [
            "-e",
            "do shell script \"\(command)\" with administrator privileges"
        ]

        let stderrPipe = Pipe()
        process.standardOutput = Pipe()
        process.standardError = stderrPipe

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            process.terminationHandler = { proc in
                if proc.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    let stderr = String(
                        data: stderrPipe.fileHandleForReading.readDataToEndOfFile(),
                        encoding: .utf8
                    ) ?? "Unknown error"
                    continuation.resume(throwing: NSError(
                        domain: "PrivilegeHelper",
                        code: Int(proc.terminationStatus),
                        userInfo: [NSLocalizedDescriptionKey: stderr]
                    ))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
