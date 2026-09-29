import Foundation

/// Where a mesh's host certificate lives: a file path, or a PEM block inline in the config
/// (Nebula Commander-issued configs inline their PKI).
public enum CertSource: Equatable, Hashable, Codable {
    case path(String)
    case inline(String)
}

/// The few Nebula config fields NebulaMac needs.
public struct MeshConfigFields: Equatable {
    public var certSource: CertSource?
    public var lighthouseIP: String?
    public var tunDev: String?

    public init(certSource: CertSource? = nil, lighthouseIP: String? = nil, tunDev: String? = nil) {
        self.certSource = certSource
        self.lighthouseIP = lighthouseIP
        self.tunDev = tunDev
    }
}

/// Section-aware reader for `pki.cert`, `lighthouse.hosts[0]` and `tun.dev`.
/// Not a general YAML parser: handles block/flow lists, quoted scalars, `|` blocks,
/// comments and CRLF — enough for Nebula configs, with no library dependency.
public enum MeshConfigParser {
    public static func parse(yaml: String) -> MeshConfigFields {
        var fields = MeshConfigFields()
        let lines = yaml.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        var section: String?
        var childIndent: Int?
        var i = 0

        while i < lines.count {
            let raw = lines[i]
            let trimmed = stripComment(raw).trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { i += 1; continue }
            let indent = indentOf(raw)

            if indent == 0 {
                section = trimmed.hasSuffix(":") ? String(trimmed.dropLast()) : nil
                childIndent = nil
                i += 1
                continue
            }
            if childIndent == nil { childIndent = indent }
            // Only direct children of a top-level section (skips nested keys and block bodies).
            guard indent == childIndent, let (key, value) = splitKey(trimmed) else { i += 1; continue }

            switch (section, key) {
            case ("pki", "cert"):
                if value.hasPrefix("|") || value.hasPrefix(">") {
                    let (block, next) = readBlock(lines, from: i + 1, parentIndent: indent)
                    fields.certSource = .inline(block)
                    i = next
                    continue
                }
                fields.certSource = .path(unquote(value))
            case ("lighthouse", "hosts"):
                fields.lighthouseIP = value.isEmpty
                    ? firstBlockListItem(lines, from: i + 1, parentIndent: indent)
                    : firstFlowListItem(value)
            case ("tun", "dev"):
                let dev = unquote(value)
                fields.tunDev = dev.isEmpty ? nil : dev
            default:
                break
            }
            i += 1
        }
        return fields
    }

    // MARK: - Private

    private static func indentOf(_ line: String) -> Int {
        line.prefix(while: { $0 == " " }).count
    }

    /// Drop a trailing `# comment` (a `#` at line start or after whitespace).
    private static func stripComment(_ line: String) -> String {
        var previous: Character = " "
        for (offset, ch) in line.enumerated() {
            if ch == "#" && previous.isWhitespace { return String(line.prefix(offset)) }
            previous = ch
        }
        return line
    }

    /// `key: value` → (key, value). Nil for list items and lines without a colon.
    private static func splitKey(_ trimmed: String) -> (String, String)? {
        guard !trimmed.hasPrefix("-"), let colon = trimmed.firstIndex(of: ":") else { return nil }
        let key = unquote(String(trimmed[..<colon]))
        let value = trimmed[trimmed.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        return (key, value)
    }

    private static func unquote(_ s: String) -> String {
        let t = s.trimmingCharacters(in: .whitespaces)
        if t.count >= 2, let first = t.first, let last = t.last, first == last, first == "\"" || first == "'" {
            return String(t.dropFirst().dropLast())
        }
        return t
    }

    /// Body of a `|` block scalar: every following line indented deeper than the key.
    private static func readBlock(_ lines: [String], from start: Int, parentIndent: Int) -> (String, Int) {
        var body: [String] = []
        var j = start
        while j < lines.count {
            let line = lines[j]
            let blank = line.trimmingCharacters(in: .whitespaces).isEmpty
            if !blank && indentOf(line) <= parentIndent { break }
            if !blank { body.append(line.trimmingCharacters(in: .whitespaces)) }
            j += 1
        }
        return (body.joined(separator: "\n") + "\n", j)
    }

    /// First `- item` under a key (YAML allows items at the key's own indent).
    private static func firstBlockListItem(_ lines: [String], from start: Int, parentIndent: Int) -> String? {
        var j = start
        while j < lines.count {
            let trimmed = stripComment(lines[j]).trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { j += 1; continue }
            guard trimmed.hasPrefix("-"), indentOf(lines[j]) >= parentIndent else { return nil }
            let item = unquote(String(trimmed.dropFirst()))
            return item.isEmpty ? nil : item
        }
        return nil
    }

    /// First element of `[a, b]`, or a bare scalar.
    private static func firstFlowListItem(_ value: String) -> String? {
        guard value.hasPrefix("["), let close = value.firstIndex(of: "]") else {
            let scalar = unquote(value)
            return scalar.isEmpty ? nil : scalar
        }
        let inner = value[value.index(after: value.startIndex)..<close]
        guard let first = inner.split(separator: ",").first else { return nil }
        let item = unquote(String(first))
        return item.isEmpty ? nil : item
    }
}
