//
//  ConfigArtifactWriter.swift
//  ProgressionLab
//

import Foundation

struct ConfigArtifactWriter {

    /// Build the artifact in memory. Pure function — no file I/O.
    static func build(
        name: String,
        description: String,
        parameters: ProgressionParameters,
        baseline: ProgressionParameters,
        baselineName: String,
        dataset: LoadedDataset,
        replays: [ExerciseModeReplay]
    ) -> ConfigArtifact {
        let diff = makeDiff(experiment: parameters, baseline: baseline)
        let stats = makeStats(experiment: parameters, baseline: baseline, dataset: dataset)

        let datasetRef = ConfigArtifact.DatasetReference(
            filename: dataset.sourceURL.lastPathComponent,
            exerciseCount: dataset.summary.exerciseCount,
            sessionCount: dataset.summary.sessionCount,
            dateRange: {
                guard let from = dataset.summary.dateRangeStart,
                      let to = dataset.summary.dateRangeEnd else { return nil }
                return ConfigArtifact.DatasetReference.DateRange(from: from, to: to)
            }()
        )

        return ConfigArtifact(
            schemaVersion: ConfigArtifact.currentSchemaVersion,
            name: name,
            description: description,
            createdAt: Date(),
            basedOnDataset: datasetRef,
            baseline: baselineName,
            parameters: parameters,
            diffFromProduction: diff,
            comparisonStats: stats
        )
    }

    /// Encode and write to a URL.
    static func write(_ artifact: ConfigArtifact, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(artifact)
        try data.write(to: url)
    }

    /// Filename suggestion: "<YYYY-MM-DD>-<slug>.json".
    static func suggestedFilename(name: String, createdAt: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let datePart = formatter.string(from: createdAt)
        let slug = name
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
        return "\(datePart)-\(slug.isEmpty ? "experiment" : slug).json"
    }

    // MARK: - Diff

    private static func makeDiff(
        experiment: ProgressionParameters,
        baseline: ProgressionParameters
    ) -> [String: ConfigArtifact.ParameterDiff] {
        var out: [String: ConfigArtifact.ParameterDiff] = [:]
        if experiment.averageWindow != baseline.averageWindow {
            out["averageWindow"] = .init(production: .int(baseline.averageWindow), experiment: .int(experiment.averageWindow))
        }
        if experiment.consistencyThreshold != baseline.consistencyThreshold {
            out["consistencyThreshold"] = .init(production: .int(baseline.consistencyThreshold), experiment: .int(experiment.consistencyThreshold))
        }
        if experiment.strengthRepCap != baseline.strengthRepCap {
            out["strengthRepCap"] = .init(production: .int(baseline.strengthRepCap), experiment: .int(experiment.strengthRepCap))
        }
        if experiment.enduranceCeilingOffset != baseline.enduranceCeilingOffset {
            out["enduranceCeilingOffset"] = .init(production: .int(baseline.enduranceCeilingOffset), experiment: .int(experiment.enduranceCeilingOffset))
        }
        if experiment.weightIncrement != baseline.weightIncrement {
            out["weightIncrement"] = .init(production: .double(baseline.weightIncrement), experiment: .double(experiment.weightIncrement))
        }
        if experiment.repIncrement != baseline.repIncrement {
            out["repIncrement"] = .init(production: .int(baseline.repIncrement), experiment: .int(experiment.repIncrement))
        }
        return out
    }

    // MARK: - Stats

    private static func makeStats(
        experiment: ProgressionParameters,
        baseline: ProgressionParameters,
        dataset: LoadedDataset
    ) -> ConfigArtifact.ComparisonStats {
        // Re-run the replay with experiment vs baseline (NOT whatever is in the
        // dashboard's slots) so stats are always relative to a fixed reference.
        var totalDecisions = 0
        var agreements = 0
        var bumpsExperiment = 0
        var bumpsProduction = 0

        for exerciseRecords in dataset.exercises {
            let modes = Set(exerciseRecords.snapshots.map(\.trainingMode))
            for mode in modes {
                let r = ReplayEngine.replay(
                    exercise: exerciseRecords.exercise,
                    mode: mode,
                    allSnapshots: exerciseRecords.snapshots,
                    configA: baseline,
                    configB: experiment
                )
                for session in r.sessions where session.isEligibleForComparison {
                    totalDecisions += 1
                    if !session.isDisagreement { agreements += 1 }
                    if session.suggestionA?.basis == .consistent { bumpsProduction += 1 }
                    if session.suggestionB?.basis == .consistent { bumpsExperiment += 1 }
                }
            }
        }

        let agreementRate = totalDecisions == 0 ? 0 : Double(agreements) / Double(totalDecisions)

        return ConfigArtifact.ComparisonStats(vsProduction: .init(
            agreementRate: agreementRate,
            weightBumpsExperiment: bumpsExperiment,
            weightBumpsProduction: bumpsProduction,
            totalDecisions: totalDecisions
        ))
    }
}
