import Testing
@testable import NebulaMacCore

struct MeshValidatorTests {
    @Test func distinctMeshesHaveNoWarnings() {
        let w = MeshValidator.warnings(for: [
            MeshIdentity(name: "work", ip: "100.100.10.15", tunDev: "utun20"),
            MeshIdentity(name: "home", ip: "100.100.40.7", tunDev: nil),
            MeshIdentity(name: "other", ip: nil, tunDev: nil),
        ])
        #expect(w.isEmpty)
    }

    @Test func sameTunDevWarnsBoth() {
        let w = MeshValidator.warnings(for: [
            MeshIdentity(name: "a", ip: "100.100.10.15", tunDev: "utun20"),
            MeshIdentity(name: "b", ip: "100.100.40.7", tunDev: "utun20"),
        ])
        #expect(w["a"] == ["tun.dev utun20 is also pinned by b"])
        #expect(w["b"] == ["tun.dev utun20 is also pinned by a"])
    }

    @Test func sameCertIPWarnsBoth() {
        let w = MeshValidator.warnings(for: [
            MeshIdentity(name: "a", ip: "100.100.10.15", tunDev: nil),
            MeshIdentity(name: "b", ip: "100.100.10.15", tunDev: nil),
        ])
        #expect(w["a"] == ["Cert IP 100.100.10.15 is also used by b"])
        #expect(w["b"] == ["Cert IP 100.100.10.15 is also used by a"])
    }
}
