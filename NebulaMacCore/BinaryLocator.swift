import Foundation

/// Finds `nebula` / `nebula-cert` in the usual install locations (Homebrew, manual, Nix).
public enum BinaryLocator {
    public static let searchDirectories = [
        "/opt/homebrew/bin",
        "/usr/local/bin",
        "~/.nix-profile/bin",
        "/run/current-system/sw/bin",
    ]

    /// First executable `name` in `dirs`, in order; `~` expands to `home`.
    public static func locate(
        _ name: String,
        in dirs: [String] = searchDirectories,
        home: String = NSHomeDirectory(),
        isExecutable: (String) -> Bool = FileManager.default.isExecutableFile(atPath:)
    ) -> String? {
        for dir in dirs {
            let expanded = dir.hasPrefix("~") ? home + dir.dropFirst() : dir
            let path = (expanded as NSString).appendingPathComponent(name)
            if isExecutable(path) { return path }
        }
        return nil
    }

    /// The stored path if it's executable; otherwise the first one found; otherwise unchanged.
    public static func resolve(
        stored: String,
        name: String,
        in dirs: [String] = searchDirectories,
        home: String = NSHomeDirectory(),
        isExecutable: (String) -> Bool = FileManager.default.isExecutableFile(atPath:)
    ) -> String {
        if isExecutable(stored) { return stored }
        return locate(name, in: dirs, home: home, isExecutable: isExecutable) ?? stored
    }
}
