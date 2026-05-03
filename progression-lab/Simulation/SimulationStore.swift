//
//  SimulationStore.swift
//  ProgressionLab
//

import Foundation
import Observation

/// One side of the A/B comparison.
@Observable
final class ConfigSlot: Identifiable {
    var name: String
    var parameters: ProgressionParameters

    var id: ObjectIdentifier { ObjectIdentifier(self) }

    init(name: String, parameters: ProgressionParameters) {
        self.name = name
        self.parameters = parameters
    }
}

@Observable
final class SimulationStore {
    let dataset: LoadedDataset
    let configA: ConfigSlot
    let configB: ConfigSlot

    /// Derived: one replay per (exercise, mode) pair where snapshots exist.
    /// Read by views; recomputed eagerly when either config changes.
    private(set) var replays: [ExerciseModeReplay] = []

    init(dataset: LoadedDataset) {
        self.dataset = dataset
        self.configA = ConfigSlot(name: "Config A", parameters: .productionModerate)
        self.configB = ConfigSlot(name: "Config B", parameters: .productionModerate)
        recompute()
    }

    /// Recompute all replays from the current configs.
    func recompute() {
        var results: [ExerciseModeReplay] = []
        for exerciseRecords in dataset.exercises {
            let modes = Set(exerciseRecords.snapshots.map(\.trainingMode))
            for mode in modes.sorted(by: { $0.rawValue < $1.rawValue }) {
                let replay = ReplayEngine.replay(
                    exercise: exerciseRecords.exercise,
                    mode: mode,
                    allSnapshots: exerciseRecords.snapshots,
                    configA: configA.parameters,
                    configB: configB.parameters
                )
                if !replay.sessions.isEmpty {
                    results.append(replay)
                }
            }
        }
        replays = results
    }
}
