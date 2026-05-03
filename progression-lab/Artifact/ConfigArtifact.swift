//
//  ConfigArtifact.swift
//  ProgressionLab
//

import Foundation

/// Top-level artifact written to disk when the user clicks "Save…" on a
/// parameter panel. The format is documented in
/// docs/superpowers/specs/2026-05-03-progression-lab-design.md.
struct ConfigArtifact: Codable {
    let schemaVersion: Int
    let name: String
    let description: String
    let createdAt: Date
    let basedOnDataset: DatasetReference
    let baseline: String   // raw value: "productionModerate" or "productionConservative"
    let parameters: ProgressionParameters
    let diffFromProduction: [String: ParameterDiff]
    let comparisonStats: ComparisonStats

    static let currentSchemaVersion = 1

    struct DatasetReference: Codable {
        let filename: String
        let exerciseCount: Int
        let sessionCount: Int
        let dateRange: DateRange?

        struct DateRange: Codable {
            let from: Date
            let to: Date
        }
    }

    struct ParameterDiff: Codable {
        let production: AnyParam
        let experiment: AnyParam
    }

    /// Type-erased numeric value so Codable serialization handles Int/Double uniformly.
    enum AnyParam: Codable {
        case int(Int)
        case double(Double)

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let i = try? container.decode(Int.self) {
                self = .int(i)
            } else {
                self = .double(try container.decode(Double.self))
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .int(let i): try container.encode(i)
            case .double(let d): try container.encode(d)
            }
        }
    }

    struct ComparisonStats: Codable {
        let vsProduction: VsProduction

        struct VsProduction: Codable {
            let agreementRate: Double
            let weightBumpsExperiment: Int
            let weightBumpsProduction: Int
            let totalDecisions: Int
        }
    }
}
