import Foundation

/// Starts nebula as root with `sudo -n`, detached so it outlives the app, and reports whether
/// sudo refused (no matching NOPASSWD rule) so the caller can fall back to a password prompt.
public enum DaemonLauncher {
    public enum Outcome: Equatable {
        case launched
        case needsPassword
    }

    public static func launchWithoutPassword(
        nebulaPath: String,
        configPath: String,
        logPath: String,
        sudoPath: String = "/usr/bin/sudo",
        settle: Duration = .milliseconds(800)
    ) async throws -> Outcome {
        // The shell backgrounds the job, so its exit code is always 0 and sudo's own stderr lands
        // in the log: the log is the only place a refusal shows up.
        let cmd = "\(sudoPath) -n \(nebulaPath) -config \(configPath) > \(logPath) 2>&1 &"
        let shell = try await ShellCommand.run("/bin/sh", args: ["-c", cmd])

        // The redirect itself failed (e.g. a root-owned log left by an earlier prompted start):
        // sudo never ran, and whatever is in the log is stale.
        if !shell.stderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .needsPassword
        }

        try await Task.sleep(for: settle)
        let log = (try? String(contentsOfFile: logPath, encoding: .utf8)) ?? ""
        return refusedBySudo(log) ? .needsPassword : .launched
    }

    static func refusedBySudo(_ log: String) -> Bool {
        log.contains("a password is required") || log.contains("is not allowed to execute")
    }
}
