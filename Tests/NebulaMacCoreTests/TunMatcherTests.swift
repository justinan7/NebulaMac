import Testing
@testable import NebulaMacCore

struct TunMatcherTests {
    // Shape of real macOS ifconfig output, with two meshes up.
    let ifconfig = """
    lo0: flags=8049<UP,LOOPBACK,RUNNING,MULTICAST> mtu 16384
    \tinet 127.0.0.1 netmask 0xff000000
    en0: flags=8863<UP,BROADCAST,SMART,RUNNING,SIMPLEX,MULTICAST> mtu 1500
    \tinet 100.100.10.1 netmask 0xffffff00 broadcast 100.100.10.255
    utun20: flags=8051<UP,POINTOPOINT,RUNNING,MULTICAST> mtu 1300
    \tinet 100.100.10.15 --> 100.100.10.15 netmask 0xffffff00
    utun21: flags=8051<UP,POINTOPOINT,RUNNING,MULTICAST> mtu 1300
    \tinet 100.100.40.7 --> 100.100.40.7 netmask 0xffffff00
    utun100: flags=8051<UP,POINTOPOINT,RUNNING,MULTICAST> mtu 1280
    \tinet 100.69.127.47 --> 100.69.127.47 netmask 0xff000000

    """

    @Test func eachMeshFindsItsOwnDevice() {
        #expect(TunMatcher.device(for: "100.100.10.15", in: ifconfig) == "utun20")
        #expect(TunMatcher.device(for: "100.100.40.7", in: ifconfig) == "utun21")
    }

    @Test func prefixOfAnotherIPDoesNotMatch() {
        #expect(TunMatcher.device(for: "100.100.10.1", in: ifconfig) == nil)   // en0 is not a utun
        #expect(TunMatcher.device(for: "100.100.40.70", in: ifconfig) == nil)
    }

    @Test func unknownIPIsNil() {
        #expect(TunMatcher.device(for: "100.100.99.9", in: ifconfig) == nil)
        #expect(TunMatcher.device(for: "100.100.10.15", in: "") == nil)
    }
}
