import Foundation

public struct MeshIdentity: Equatable {
    public let name: String
    public let ip: String?
    public let tunDev: String?

    public init(name: String, ip: String?, tunDev: String?) {
        self.name = name
        self.ip = ip
        self.tunDev = tunDev
    }
}

/// Flags mesh configs that would collide when run together. Warnings only — never blocks connecting.
public enum MeshValidator {
    public static func warnings(for meshes: [MeshIdentity]) -> [String: [String]] {
        var result: [String: [String]] = [:]
        for mesh in meshes {
            var list: [String] = []
            for other in meshes where other.name != mesh.name {
                if let dev = mesh.tunDev, dev == other.tunDev {
                    list.append("tun.dev \(dev) is also pinned by \(other.name)")
                }
                if let ip = mesh.ip, ip == other.ip {
                    list.append("Cert IP \(ip) is also used by \(other.name)")
                }
            }
            if !list.isEmpty { result[mesh.name] = list }
        }
        return result
    }
}
