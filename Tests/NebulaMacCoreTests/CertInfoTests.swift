import Foundation
import Testing
@testable import NebulaMacCore

struct CertInfoTests {
    let notAfter = Date(timeIntervalSince1970: 2_000_000_000)
    var cert: CertInfo { CertInfo(name: "mac", ips: ["100.100.10.15"], groups: [], notAfter: notAfter) }
    func daysBefore(_ days: Double) -> Date { notAfter.addingTimeInterval(-days * 86_400) }

    @Test func thirtyOneDaysIsOk() {
        #expect(cert.daysUntilExpiry(now: daysBefore(31)) == 31)
        #expect(cert.expiryLevel(now: daysBefore(31)) == .ok)
    }

    @Test func exactlyThirtyDaysIsStillOk() {
        #expect(cert.expiryLevel(now: daysBefore(30)) == .ok)
    }

    @Test func underThirtyDaysWarns() {
        #expect(cert.daysUntilExpiry(now: daysBefore(29.5)) == 29)
        #expect(cert.expiryLevel(now: daysBefore(29.5)) == .warning)
        #expect(cert.expiryLevel(now: daysBefore(0.04)) == .warning)   // ~1 hour left
    }

    @Test func pastNotAfterIsExpired() {
        #expect(cert.expiryLevel(now: notAfter) == .expired)
        #expect(cert.daysUntilExpiry(now: daysBefore(-1)) == -1)
        #expect(cert.expiryLevel(now: daysBefore(-1)) == .expired)
    }

    // The menu shows the expiry line only when fewer than 90 days remain.
    @Test func menuHidesExpiryAtNinetyDaysOrMore() {
        #expect(!cert.showsInMenu(now: daysBefore(3453)))
        #expect(!cert.showsInMenu(now: daysBefore(90)))
    }

    @Test func menuShowsExpiryUnderNinetyDaysAndWhenExpired() {
        #expect(cert.showsInMenu(now: daysBefore(89.5)))
        #expect(cert.showsInMenu(now: daysBefore(10)))
        #expect(cert.showsInMenu(now: daysBefore(-1)))
    }
}
