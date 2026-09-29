import Testing
@testable import NebulaMacCore

struct BinaryLocatorTests {
    let dirs = ["/opt/homebrew/bin", "/usr/local/bin", "~/.nix-profile/bin", "/run/current-system/sw/bin"]

    @Test func prefersEarlierDirectory() {
        let present: Set = ["/opt/homebrew/bin/nebula", "/usr/local/bin/nebula"]
        #expect(BinaryLocator.locate("nebula", in: dirs, home: "/Users/a", isExecutable: present.contains) == "/opt/homebrew/bin/nebula")
    }

    @Test func expandsTildeWithGivenHome() {
        let present: Set = ["/Users/a/.nix-profile/bin/nebula-cert"]
        #expect(BinaryLocator.locate("nebula-cert", in: dirs, home: "/Users/a", isExecutable: present.contains) == "/Users/a/.nix-profile/bin/nebula-cert")
    }

    @Test func nilWhenMissingEverywhere() {
        #expect(BinaryLocator.locate("nebula", in: dirs, home: "/Users/a", isExecutable: { _ in false }) == nil)
    }

    @Test func keepsValidStoredPath() {
        let present: Set = ["/Users/a/bin/nebula", "/opt/homebrew/bin/nebula"]
        #expect(BinaryLocator.resolve(stored: "/Users/a/bin/nebula", name: "nebula", in: dirs, home: "/Users/a", isExecutable: present.contains) == "/Users/a/bin/nebula")
    }

    @Test func replacesMissingStoredPath() {
        let present: Set = ["/opt/homebrew/bin/nebula"]
        #expect(BinaryLocator.resolve(stored: "/usr/local/bin/nebula", name: "nebula", in: dirs, home: "/Users/a", isExecutable: present.contains) == "/opt/homebrew/bin/nebula")
    }

    @Test func keepsStoredPathWhenNothingFound() {
        #expect(BinaryLocator.resolve(stored: "/usr/local/bin/nebula", name: "nebula", in: dirs, home: "/Users/a", isExecutable: { _ in false }) == "/usr/local/bin/nebula")
    }
}
