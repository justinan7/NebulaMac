import Foundation

/// Finds which utun interface carries a mesh's IP — exact match only, so two meshes
/// (e.g. 100.100.10.x and 100.100.40.x) can never be mistaken for each other.
public enum TunMatcher {
    public static func device(for ip: String, in ifconfigOutput: String) -> String? {
        var current: String?
        for line in ifconfigOutput.components(separatedBy: "\n") {
            if let first = line.first, !first.isWhitespace {
                current = line.components(separatedBy: ":").first
                continue
            }
            guard let device = current, device.hasPrefix("utun") else { continue }
            let parts = line.trimmingCharacters(in: .whitespaces).split(separator: " ")
            if parts.count >= 2, parts[0] == "inet", parts[1] == ip { return device }
        }
        return nil
    }
}
