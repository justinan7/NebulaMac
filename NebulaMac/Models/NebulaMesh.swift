import Foundation
import NebulaMacCore

/// Represents a single Nebula mesh configuration.
struct NebulaMesh: Identifiable, Codable, Equatable, Hashable {
    var id: String { name }
    let name: String
    let configPath: String
    var lighthouseIP: String
    var certSource: CertSource?
    var tunDev: String?
    var cert: CertInfo?
    var certError: String?
    var warnings: [String] = []

    /// Mesh IP from the host cert — the only reliable way to tell meshes apart.
    var localIP: String? { cert?.ips.first }

    /// Resolves the config path, expanding ~ to the home directory.
    var resolvedConfigPath: URL {
        URL(fileURLWithPath: (configPath as NSString).expandingTildeInPath)
    }

    /// Checks whether the config file exists on disk.
    var configExists: Bool {
        FileManager.default.fileExists(atPath: resolvedConfigPath.path)
    }
}
