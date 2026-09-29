import Foundation
import SwiftUI
import NebulaMacCore

/// Discovers Nebula mesh configurations and reads their host certs.
@MainActor
class ConfigManager: ObservableObject {
    @Published var meshes: [NebulaMesh] = []

    @AppStorage("configDirectory") var configDirectory = "~/.nebula"
    @AppStorage("nebulaCertPath") var nebulaCertPath = "/usr/local/bin/nebula-cert"

    private let fileManager = FileManager.default

    init() {
        loadMeshes()
    }

    /// Scan the config directory for mesh configurations (fast, synchronous).
    /// Cert details (IP, expiry) arrive afterwards via `refreshCerts()`.
    func loadMeshes() {
        let expandedPath = (configDirectory as NSString).expandingTildeInPath
        var discovered: [NebulaMesh] = []

        // Check for meshes subdirectory (multi-mesh mode)
        let meshesDir = (expandedPath as NSString).appendingPathComponent("meshes")
        if fileManager.fileExists(atPath: meshesDir) {
            discovered.append(contentsOf: scanDirectory(meshesDir))
        }

        // Check for single config.yml at root (single-mesh mode)
        let singleConfig = (expandedPath as NSString).appendingPathComponent("config.yml")
        if fileManager.fileExists(atPath: singleConfig) {
            let mesh = parseMeshConfig(name: "default", path: singleConfig)
            if !discovered.contains(where: { $0.configPath == mesh.configPath }) {
                discovered.append(mesh)
            }
        }

        meshes = discovered
        applyValidation()
    }

    /// Rediscover meshes and read every host cert. Await this before anything that
    /// matches meshes by IP (adopting running meshes at launch).
    func reload() async {
        loadMeshes()
        await refreshCerts()
    }

    /// Read each mesh's host cert with nebula-cert and record its IP/expiry or the error.
    func refreshCerts() async {
        let certToolPath = nebulaCertPath
        var results: [String: Result<CertInfo, CertReadError>] = [:]
        for mesh in meshes {
            guard let source = mesh.certSource else {
                results[mesh.name] = .failure(.parseFailed("no pki.cert in \(mesh.configPath)"))
                continue
            }
            results[mesh.name] = await CertReader.read(source: source, nebulaCertPath: certToolPath)
        }
        // Apply by name: `meshes` may have been reloaded while certs were being read.
        meshes = meshes.map { mesh in
            var updated = mesh
            switch results[mesh.name] {
            case .success(let info):
                updated.cert = info
                updated.certError = nil
            case .failure(let error):
                updated.cert = nil
                updated.certError = error.message
            case nil:
                break
            }
            return updated
        }
        applyValidation()
    }

    // MARK: - Private

    private func applyValidation() {
        let warnings = MeshValidator.warnings(for: meshes.map {
            MeshIdentity(name: $0.name, ip: $0.localIP, tunDev: $0.tunDev)
        })
        meshes = meshes.map { mesh in
            var updated = mesh
            updated.warnings = warnings[mesh.name] ?? []
            return updated
        }
    }

    private func scanDirectory(_ path: String) -> [NebulaMesh] {
        guard let files = try? fileManager.contentsOfDirectory(atPath: path) else { return [] }

        return files
            .filter { $0.hasSuffix(".yml") || $0.hasSuffix(".yaml") }
            .sorted()
            .map { file in
                let name = (file as NSString).deletingPathExtension
                let fullPath = (path as NSString).appendingPathComponent(file)
                return parseMeshConfig(name: name, path: fullPath)
            }
    }

    private func parseMeshConfig(name: String, path: String) -> NebulaMesh {
        let contents = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
        let fields = MeshConfigParser.parse(yaml: contents)
        return NebulaMesh(
            name: name,
            configPath: path,
            lighthouseIP: fields.lighthouseIP ?? "",
            certSource: fields.certSource,
            tunDev: fields.tunDev
        )
    }
}
