import Foundation
import Testing
@testable import NebulaMacCore

/// Uses a fake `sudo` so no real privilege is involved.
struct DaemonLauncherTests {
    func fakeSudo(_ body: String) throws -> (sudo: String, dir: URL) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("nebulamac-launch-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let sudo = dir.appendingPathComponent("sudo")
        try ("#!/bin/sh\n" + body + "\n").write(to: sudo, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: sudo.path)
        return (sudo.path, dir)
    }

    // Reviewer finding: sh -c "... &" always exits 0, so sudo's refusal only shows in the log.
    @Test func sudoPasswordRefusalFallsBack() async throws {
        let (sudo, dir) = try fakeSudo("echo 'sudo: a password is required' >&2; exit 1")
        let outcome = try await DaemonLauncher.launchWithoutPassword(
            nebulaPath: "/usr/local/bin/nebula", configPath: "/tmp/mesh.yml",
            logPath: dir.appendingPathComponent("n.log").path, sudoPath: sudo, settle: .milliseconds(300))
        #expect(outcome == .needsPassword)
    }

    @Test func runningNebulaIsLaunchedWithExactArgv() async throws {
        let (sudo, dir) = try fakeSudo("echo \"argv: $*\"; sleep 1")
        let log = dir.appendingPathComponent("n.log").path
        let outcome = try await DaemonLauncher.launchWithoutPassword(
            nebulaPath: "/usr/local/bin/nebula", configPath: "/tmp/mesh.yml",
            logPath: log, sudoPath: sudo, settle: .milliseconds(300))
        #expect(outcome == .launched)
        #expect(try String(contentsOfFile: log, encoding: .utf8).contains("argv: -n /usr/local/bin/nebula -config /tmp/mesh.yml"))
    }

    // A log the user can't write (e.g. left root-owned by an earlier password-prompt start)
    // means sudo never ran; the stale log must not be read as success.
    @Test func unwritableLogFallsBack() async throws {
        let (sudo, _) = try fakeSudo("echo started; sleep 1")
        let outcome = try await DaemonLauncher.launchWithoutPassword(
            nebulaPath: "/usr/local/bin/nebula", configPath: "/tmp/mesh.yml",
            logPath: "/nonexistent-nebulamac-dir/n.log", sudoPath: sudo, settle: .milliseconds(300))
        #expect(outcome == .needsPassword)
    }
}
