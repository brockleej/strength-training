//
//  ReplayEngine.swift
//  ProgressionLab
//

import Foundation

struct ReplayEngine {

    /// Replay the algorithm against one exercise's snapshots under both configs.
    /// `snapshots` may include any training mode; this function filters internally.
    /// Returned `SessionReplay`s are chronological (oldest first) and contain
    /// only the requested mode.
    static func replay(
        exercise: LoadedExercise,
        mode: TrainingMode,
        allSnapshots: [ExerciseRecordSnapshot],
        configA: ProgressionParameters,
        configB: ProgressionParameters
    ) -> ExerciseModeReplay {
        let modeSnapshots = allSnapshots
            .filter { $0.trainingMode == mode }
            .sorted { $0.sessionDate < $1.sessionDate }

        var sessionReplays: [SessionReplay] = []
        sessionReplays.reserveCapacity(modeSnapshots.count)

        for (index, snapshot) in modeSnapshots.enumerated() {
            // History available BEFORE this session: the previous `index` snapshots,
            // reversed so newest is first (the algorithm's expected order).
            let priorOldestFirst = modeSnapshots.prefix(index)
            let historyNewestFirst = Array(priorOldestFirst.reversed())

            let suggestionA = ProgressionService.suggestion(
                records: historyNewestFirst, mode: mode, params: configA
            )
            let suggestionB = ProgressionService.suggestion(
                records: historyNewestFirst, mode: mode, params: configB
            )

            guard let bestSet = snapshot.sets.max(by: { $0.weightLbs < $1.weightLbs }) else {
                continue
            }

            sessionReplays.append(SessionReplay(
                sessionDate: snapshot.sessionDate,
                actualBestSet: bestSet,
                suggestionA: suggestionA,
                suggestionB: suggestionB
            ))
        }

        // Next suggestion uses ALL history.
        let allHistoryNewestFirst = Array(modeSnapshots.reversed())
        let nextA = ProgressionService.suggestion(
            records: allHistoryNewestFirst, mode: mode, params: configA
        )
        let nextB = ProgressionService.suggestion(
            records: allHistoryNewestFirst, mode: mode, params: configB
        )

        return ExerciseModeReplay(
            exercise: exercise,
            mode: mode,
            sessions: sessionReplays,
            nextSuggestionA: nextA,
            nextSuggestionB: nextB
        )
    }
}
