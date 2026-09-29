import Foundation

public enum ExpiryLevel: Equatable {
    case ok, warning, expired
}

/// What NebulaMac needs from a host certificate (from `nebula-cert print -json`).
public struct CertInfo: Equatable, Hashable, Codable {
    public let name: String
    /// Mesh IPs without prefix length, e.g. "100.100.10.15".
    public let ips: [String]
    public let groups: [String]
    public let notAfter: Date

    /// Warn when fewer than this many whole days remain.
    public static let warningDays = 30
    /// The menu only mentions expiry when fewer than this many whole days remain.
    public static let menuNoticeDays = 90

    public init(name: String, ips: [String], groups: [String], notAfter: Date) {
        self.name = name
        self.ips = ips
        self.groups = groups
        self.notAfter = notAfter
    }

    /// Whole days until expiry, rounded down; negative once expired.
    public func daysUntilExpiry(now: Date = Date()) -> Int {
        Int((notAfter.timeIntervalSince(now) / 86_400).rounded(.down))
    }

    public func expiryLevel(now: Date = Date()) -> ExpiryLevel {
        if notAfter <= now { return .expired }
        return daysUntilExpiry(now: now) < Self.warningDays ? .warning : .ok
    }

    /// Whether the menu row should show the expiry line (Settings always shows it).
    public func showsInMenu(now: Date = Date()) -> Bool {
        daysUntilExpiry(now: now) < Self.menuNoticeDays
    }
}
