import Foundation

/// Reads `sudo -n -l` output. `sudo -n -l <command>` is no use as a check: for an admin it exits 0
/// once any NOPASSWD rule exists (listpw=any), even when that command still needs a password.
public enum SudoListing {
    /// Whether the listing grants `command` (full command line) without a password.
    public static func allowsPasswordless(_ command: String, in listing: String) -> Bool {
        for line in listing.components(separatedBy: "\n") {
            guard let tag = line.range(of: "NOPASSWD:") else { continue }
            for rawEntry in line[tag.upperBound...].components(separatedBy: ",") {
                let entry = stripRunAs(rawEntry.trimmingCharacters(in: .whitespaces))
                if entry == "ALL" || entry == command { return true }
                // A sudoers command with no arguments allows any arguments.
                if !entry.isEmpty, !entry.contains(" "), command.hasPrefix(entry + " ") { return true }
            }
        }
        return false
    }

    /// Drop a leading "(root) " and a repeated "NOPASSWD: " from a comma-joined entry.
    private static func stripRunAs(_ entry: String) -> String {
        var e = entry
        if e.hasPrefix("("), let close = e.firstIndex(of: ")") {
            e = e[e.index(after: close)...].trimmingCharacters(in: .whitespaces)
        }
        if e.hasPrefix("NOPASSWD:") {
            e = e.dropFirst("NOPASSWD:".count).trimmingCharacters(in: .whitespaces)
        }
        return e
    }
}
