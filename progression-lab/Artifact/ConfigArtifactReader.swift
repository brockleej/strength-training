//
//  ConfigArtifactReader.swift
//  ProgressionLab
//

import Foundation

enum ConfigArtifactReaderError: LocalizedError {
    case readFailed(URL, underlying: Error)
    case decodeFailed(URL, underlying: Error)
    case unsupportedSchemaVersion(found: Int, supported: Int)

    var errorDescription: String? {
        switch self {
        case .readFailed(let url, let err):
            return "Couldn't read \(url.lastPathComponent): \(err.localizedDescription)"
        case .decodeFailed(let url, let err):
            return "Couldn't decode \(url.lastPathComponent): \(err.localizedDescription)"
        case .unsupportedSchemaVersion(let found, let supported):
            return "Artifact uses schema version \(found); this build understands up to \(supported)."
        }
    }
}

struct ConfigArtifactReader {
    /// Parse a saved config artifact and return the loaded parameters along with
    /// the artifact's name (so the receiving panel can rename itself).
    static func load(from url: URL) throws -> (parameters: ProgressionParameters, name: String) {
        let data: Data
        do { data = try Data(contentsOf: url) }
        catch { throw ConfigArtifactReaderError.readFailed(url, underlying: error) }

        let artifact: ConfigArtifact
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            artifact = try decoder.decode(ConfigArtifact.self, from: data)
        } catch {
            throw ConfigArtifactReaderError.decodeFailed(url, underlying: error)
        }

        guard artifact.schemaVersion <= ConfigArtifact.currentSchemaVersion else {
            throw ConfigArtifactReaderError.unsupportedSchemaVersion(
                found: artifact.schemaVersion,
                supported: ConfigArtifact.currentSchemaVersion
            )
        }

        return (artifact.parameters, artifact.name)
    }
}
