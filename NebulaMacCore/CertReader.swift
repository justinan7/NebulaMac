import Foundation

public enum CertReadError: Error, Equatable {
    case nebulaCertMissing(String)
    case certMissing(String)
    case parseFailed(String)

    /// Short text for the mesh row.
    public var message: String {
        switch self {
        case .nebulaCertMissing: return "Install nebula-cert for cert info"
        case .certMissing(let path): return "Cert not found: \(path)"
        case .parseFailed(let detail): return "Can't read cert: \(detail)"
        }
    }
}

/// Reads host certs with `nebula-cert print -json` (handles v1 and v2 certs).
public enum CertReader {
    private struct RawCert: Decodable {
        struct Details: Decodable {
            let name: String
            let networks: [String]?
            let groups: [String]?
            let notAfter: String
        }
        let details: Details
    }

    /// Parse `nebula-cert print -json` output: a JSON array; the first cert is used.
    public static func parse(json: Data) throws -> CertInfo {
        let certs: [RawCert]
        do {
            certs = try JSONDecoder().decode([RawCert].self, from: json)
        } catch {
            throw CertReadError.parseFailed("unexpected nebula-cert output")
        }
        guard let details = certs.first?.details else {
            throw CertReadError.parseFailed("no certificate in output")
        }
        let ips = (details.networks ?? []).compactMap { $0.split(separator: "/").first.map(String.init) }
        guard !ips.isEmpty else {
            throw CertReadError.parseFailed("certificate has no mesh IP")
        }
        guard let notAfter = ISO8601DateFormatter().date(from: details.notAfter) else {
            throw CertReadError.parseFailed("bad notAfter \(details.notAfter)")
        }
        return CertInfo(name: details.name, ips: ips, groups: details.groups ?? [], notAfter: notAfter)
    }

    /// Run `nebula-cert print -json -path <cert>`; inline PEM is written to a 0600 temp file first.
    public static func read(source: CertSource, nebulaCertPath: String) async -> Result<CertInfo, CertReadError> {
        let fm = FileManager.default
        guard fm.isExecutableFile(atPath: nebulaCertPath) else {
            return .failure(.nebulaCertMissing(nebulaCertPath))
        }

        let certPath: String
        var tempPath: String?
        switch source {
        case .path(let path):
            certPath = (path as NSString).expandingTildeInPath
            guard fm.fileExists(atPath: certPath) else { return .failure(.certMissing(certPath)) }
        case .inline(let pem):
            let path = fm.temporaryDirectory.appendingPathComponent("nebulamac-\(UUID().uuidString).crt").path
            guard fm.createFile(atPath: path, contents: Data(pem.utf8), attributes: [.posixPermissions: 0o600]) else {
                return .failure(.parseFailed("couldn't write temp cert file"))
            }
            tempPath = path
            certPath = path
        }
        defer { if let tempPath { try? fm.removeItem(atPath: tempPath) } }

        do {
            let result = try await ShellCommand.run(nebulaCertPath, args: ["print", "-json", "-path", certPath])
            guard result.exitCode == 0 else {
                return .failure(.parseFailed(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)))
            }
            return .success(try parse(json: Data(result.stdout.utf8)))
        } catch let error as CertReadError {
            return .failure(error)
        } catch {
            return .failure(.parseFailed(error.localizedDescription))
        }
    }
}
