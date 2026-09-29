import Testing
@testable import NebulaMacCore

struct MeshConfigParserTests {
    // A typical path-based config: lighthouse + relay + static host map, pinned utun.
    let liveStyle = """
    pki:
      ca: /Users/alice/.nebula/work/ca.crt
      cert: /Users/alice/.nebula/work/host.crt
      key: /Users/alice/.nebula/work/host.key

    static_host_map:
      "100.100.10.5": ["198.51.100.20:4243"]
      "100.100.10.6": ["203.0.113.10:4242", "192.0.2.30:4242"]

    lighthouse:
      am_lighthouse: false
      hosts:
        - "100.100.10.6"

    relay:
      relays:
        - 100.100.10.5

    tun:
      dev: utun20
      mtu: 1300
    """

    @Test func pathBasedConfig() {
        let f = MeshConfigParser.parse(yaml: liveStyle)
        #expect(f.certSource == .path("/Users/alice/.nebula/work/host.crt"))
        #expect(f.lighthouseIP == "100.100.10.6")   // not the static_host_map / relay entry
        #expect(f.tunDev == "utun20")
    }

    @Test func crlfLineEndings() {
        let f = MeshConfigParser.parse(yaml: liveStyle.replacingOccurrences(of: "\n", with: "\r\n"))
        #expect(f.certSource == .path("/Users/alice/.nebula/work/host.crt"))
        #expect(f.lighthouseIP == "100.100.10.6")
        #expect(f.tunDev == "utun20")
    }

    @Test func inlinePemCert() {
        let yaml = """
        pki:
          ca: |
            -----BEGIN NEBULA CERTIFICATE-----
            CACA
            -----END NEBULA CERTIFICATE-----
          cert: |
            -----BEGIN NEBULA CERTIFICATE-----
            AAAA
            BBBB
            -----END NEBULA CERTIFICATE-----
          key: |
            -----BEGIN NEBULA X25519 PRIVATE KEY-----
            KKKK
            -----END NEBULA X25519 PRIVATE KEY-----
        lighthouse:
          hosts: ["100.100.10.6", "100.100.10.5"]
        """
        let f = MeshConfigParser.parse(yaml: yaml)
        #expect(f.certSource == .inline("-----BEGIN NEBULA CERTIFICATE-----\nAAAA\nBBBB\n-----END NEBULA CERTIFICATE-----\n"))
        #expect(f.lighthouseIP == "100.100.10.6")
        #expect(f.tunDev == nil)
    }

    @Test func commentsQuotesAndSameIndentList() {
        let yaml = """
        # a comment
        pki:
          cert: "/tmp/host.crt"   # quoted, with a comment
        lighthouse:
          hosts:
          - 100.100.40.1  # list item at the key's indent
        tun:
          dev: 'utun7'
        """
        let f = MeshConfigParser.parse(yaml: yaml)
        #expect(f.certSource == .path("/tmp/host.crt"))
        #expect(f.lighthouseIP == "100.100.40.1")
        #expect(f.tunDev == "utun7")
    }

    @Test func missingSectionsGiveNil() {
        let f = MeshConfigParser.parse(yaml: "listen:\n  port: 0\nlighthouse:\n  hosts: []\n")
        #expect(f == MeshConfigFields())
    }
}
