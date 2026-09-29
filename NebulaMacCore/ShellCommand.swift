import Foundation

/// Runs shell commands and captures output.
public enum ShellCommand {
    public struct Result {
        public let stdout: String
        public let stderr: String
        public let exitCode: Int32
    }

    /// Run a command as the current user.
    public static func run(_ command: String, args: [String] = []) async throws -> Result {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = args

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { proc in
                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

                let result = Result(
                    stdout: String(data: stdoutData, encoding: .utf8) ?? "",
                    stderr: String(data: stderrData, encoding: .utf8) ?? "",
                    exitCode: proc.terminationStatus
                )
                continuation.resume(returning: result)
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Run a command with administrator privileges via AppleScript.
    public static func runPrivileged(_ command: String, args: [String] = []) async throws -> Result {
        let fullCommand = ([command] + args)
            .map { "'\($0)'" }
            .joined(separator: " ")

        let script = """
            do shell script "\(fullCommand)" with administrator privileges
            """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { proc in
                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

                let result = Result(
                    stdout: String(data: stdoutData, encoding: .utf8) ?? "",
                    stderr: String(data: stderrData, encoding: .utf8) ?? "",
                    exitCode: proc.terminationStatus
                )
                continuation.resume(returning: result)
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Run a long-lived process (like the Nebula daemon), returning the Process handle.
    public static func startLongRunning(
        _ command: String,
        args: [String] = [],
        onOutput: @escaping (String) -> Void,
        onTermination: @escaping (Int32) -> Void
    ) throws -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = args

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if let str = String(data: data, encoding: .utf8), !str.isEmpty {
                onOutput(str)
            }
        }

        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if let str = String(data: data, encoding: .utf8), !str.isEmpty {
                onOutput(str)
            }
        }

        process.terminationHandler = { proc in
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            onTermination(proc.terminationStatus)
        }

        try process.run()
        return process
    }
}
