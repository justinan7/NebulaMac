import Testing
@testable import NebulaMacCore

// Reviewer finding: `sudo -n -l <cmd>` exits 0 for any admin once any NOPASSWD rule exists,
// so the Settings check must read the full listing for the exact passwordless entry.
struct SudoListingTests {
    let start = "/usr/local/bin/nebula -config /Users/alice/.nebula/meshes/work.yml"

    let listing = """
    Matching Defaults entries for alice on alices-mac:
        env_reset, env_keep+=BLOCKSIZE, env_keep+="COLORFGBG COLORTERM"

    User alice may run the following commands on alices-mac:
        (ALL) ALL
        (root) NOPASSWD: /usr/local/bin/nebula -config /Users/alice/.nebula/meshes/work.yml
        (root) NOPASSWD: /usr/bin/pkill -f nebula -config /Users/alice/.nebula/meshes/work.yml
    """

    @Test func exactPasswordlessEntryIsAllowed() {
        #expect(SudoListing.allowsPasswordless(start, in: listing))
    }

    @Test func otherMeshIsNotAllowed() {
        #expect(!SudoListing.allowsPasswordless(
            "/usr/local/bin/nebula -config /Users/alice/.nebula/meshes/home.yml", in: listing))
    }

    @Test func adminWithPasswordIsNotPasswordless() {
        let adminOnly = "User alice may run the following commands on mac:\n    (ALL) ALL\n"
        #expect(!SudoListing.allowsPasswordless(start, in: adminOnly))
    }

    @Test func commaJoinedEntriesAndNopasswdAll() {
        let joined = "    (root) NOPASSWD: /usr/bin/pkill -f x, \(start)\n"
        #expect(SudoListing.allowsPasswordless(start, in: joined))
        #expect(SudoListing.allowsPasswordless(start, in: "    (ALL) NOPASSWD: ALL\n"))
    }

    @Test func oldArgumentlessRuleCountsAsPasswordless() {
        // The pre-branch rule `NOPASSWD: /usr/local/bin/nebula, /usr/bin/pkill` allows any args.
        #expect(SudoListing.allowsPasswordless(start, in: "    (root) NOPASSWD: /usr/local/bin/nebula, /usr/bin/pkill\n"))
    }
}
