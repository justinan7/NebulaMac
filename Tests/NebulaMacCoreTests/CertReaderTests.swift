import Foundation
import Testing
@testable import NebulaMacCore

// Captured from real nebula-cert 1.10.0 on throwaway CAs, 2026-09-29.
enum Fixtures {
    static let v1 = #"[{"details":{"curve":"CURVE25519","groups":["admin","laptop"],"isCa":false,"issuer":"b7b2d64090c80fd66f209d9eb3ecad8d0b896217fdd06aa37df46c21f3e23790","name":"mac","networks":["100.100.10.15/24"],"notAfter":"2027-09-29T12:50:40-07:00","notBefore":"2026-09-29T12:50:41-07:00","publicKey":"a6de68dc42cf8ebf0cc31f84e72e762e8189ce7197ed77960a6a0535df511b09","unsafeNetworks":[]},"fingerprint":"036510028277617c08589caad0b1639e8e48a0272e88499f292655bd086a69c6","signature":"ffc0","version":1}]"#
    static let v2 = #"[{"curve":"CURVE25519","details":{"groups":["admin"],"isCa":false,"issuer":"e3120de9dc0b04a15e897a54cb4afc9503cef10e6f148d8fa7d60ff17d75f429","name":"mac","networks":["100.100.40.7/24"],"notAfter":"2027-09-29T12:50:40-07:00","notBefore":"2026-09-29T12:50:41-07:00","unsafeNetworks":null},"fingerprint":"a59e","publicKey":"0c55","signature":"71d7","version":2}]"#
    static let caCert = #"[{"details":{"groups":[],"isCa":true,"issuer":"","name":"Test CA","networks":[],"notAfter":"2027-09-29T12:50:40-07:00","notBefore":"2026-09-29T12:50:41-07:00","unsafeNetworks":[]},"fingerprint":"aa","signature":"bb","version":1}]"#
    static let notAfter = ISO8601DateFormatter().date(from: "2027-09-29T12:50:40-07:00")!
}

struct CertReaderParseTests {
    @Test func parsesV1() throws {
        let c = try CertReader.parse(json: Data(Fixtures.v1.utf8))
        #expect(c == CertInfo(name: "mac", ips: ["100.100.10.15"], groups: ["admin", "laptop"], notAfter: Fixtures.notAfter))
    }

    @Test func parsesV2() throws {
        let c = try CertReader.parse(json: Data(Fixtures.v2.utf8))
        #expect(c.ips == ["100.100.40.7"])
        #expect(c.groups == ["admin"])
    }

    @Test func usesFirstOfSeveral() throws {
        let v2Body = String(Fixtures.v2.dropFirst().dropLast())   // strip the outer [ ]
        let v1Body = String(Fixtures.v1.dropFirst().dropLast())
        let both = "[" + v2Body + "," + v1Body + "]"
        #expect(try CertReader.parse(json: Data(both.utf8)).ips == ["100.100.40.7"])
    }

    @Test func certWithoutMeshIPFails() {
        #expect(throws: CertReadError.parseFailed("certificate has no mesh IP")) {
            try CertReader.parse(json: Data(Fixtures.caCert.utf8))
        }
    }

    @Test func emptyAndGarbageFail() {
        #expect(throws: CertReadError.parseFailed("no certificate in output")) {
            try CertReader.parse(json: Data("[]".utf8))
        }
        #expect(throws: CertReadError.parseFailed("unexpected nebula-cert output")) {
            try CertReader.parse(json: Data("Error: nope".utf8))
        }
    }
}

struct CertReaderReadTests {
    /// A fake `nebula-cert` in a temp dir; `body` is the shell script after the shebang.
    func stub(_ body: String) throws -> (tool: String, dir: URL) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("nebulamac-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let tool = dir.appendingPathComponent("nebula-cert")
        try ("#!/bin/sh\n" + body + "\n").write(to: tool, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tool.path)
        return (tool.path, dir)
    }

    func writeFixture(_ json: String, in dir: URL) throws -> String {
        let url = dir.appendingPathComponent("fixture.json")
        try json.write(to: url, atomically: true, encoding: .utf8)
        return url.path
    }

    @Test func missingToolIsReported() async {
        let r = await CertReader.read(source: .path("/tmp/x.crt"), nebulaCertPath: "/nonexistent/nebula-cert")
        #expect(r == .failure(.nebulaCertMissing("/nonexistent/nebula-cert")))
        #expect(CertReadError.nebulaCertMissing("x").message == "Install nebula-cert for cert info")
    }

    @Test func missingCertFileIsReported() async throws {
        let (tool, _) = try stub("exit 0")
        let r = await CertReader.read(source: .path("/nonexistent/host.crt"), nebulaCertPath: tool)
        #expect(r == .failure(.certMissing("/nonexistent/host.crt")))
    }

    @Test func pathSourceParsesToolOutput() async throws {
        let (tool, dir) = try stub("")
        let fixture = try writeFixture(Fixtures.v1, in: dir)
        try ("#!/bin/sh\n[ \"$1 $2 $3\" = \"print -json -path\" ] || exit 9\ncat '\(fixture)'\n")
            .write(toFile: tool, atomically: true, encoding: .utf8)
        let cert = dir.appendingPathComponent("host.crt")
        try "pem".write(to: cert, atomically: true, encoding: .utf8)
        let r = await CertReader.read(source: .path(cert.path), nebulaCertPath: tool)
        #expect(try r.get().ips == ["100.100.10.15"])
    }

    @Test func inlineSourceIsWrittenToATempFile() async throws {
        let (tool, dir) = try stub("")
        let fixture = try writeFixture(Fixtures.v2, in: dir)
        let capture = dir.appendingPathComponent("captured.crt").path
        try ("#!/bin/sh\ncp \"$4\" '\(capture)'\ncat '\(fixture)'\n")
            .write(toFile: tool, atomically: true, encoding: .utf8)
        let pem = "-----BEGIN NEBULA CERTIFICATE-----\nAAAA\n-----END NEBULA CERTIFICATE-----\n"
        let r = await CertReader.read(source: .inline(pem), nebulaCertPath: tool)
        #expect(try r.get().ips == ["100.100.40.7"])
        #expect(try String(contentsOfFile: capture, encoding: .utf8) == pem)
    }

    @Test func toolFailureCarriesStderr() async throws {
        let (tool, dir) = try stub("echo 'Error: unable to read cert' >&2; exit 1")
        let cert = dir.appendingPathComponent("host.crt")
        try "bad".write(to: cert, atomically: true, encoding: .utf8)
        let r = await CertReader.read(source: .path(cert.path), nebulaCertPath: tool)
        #expect(r == .failure(.parseFailed("Error: unable to read cert")))
    }
}
