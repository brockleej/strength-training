//
//  ProgressionService+SwiftData.swift
//  RockLog
//
//  iOS-only adapter that exposes the pure ProgressionService API on top of
//  SwiftData @Model types. Lives outside Shared/Algorithm/ so the macOS
//  ProgressionLab target doesn't try to compile SwiftData-coupled code.
//

import Foundation
import SwiftData

extension ProgressionService {
    /// Compute the rolling average best set across the last `averageWindow` sessions.
    /// Returns nil if the exercise has never been done in this mode.
    static func recentAverage(
        for exercise: Exercise,
        mode: TrainingMode,
        excludingSessionID: UUID? = nil
    ) -> RecentAverage? {
        let snapshots = snapshotsFromCompletedRecords(of: exercise, excludingSessionID: excludingSessionID)
        return recentAverage(records: snapshots, mode: mode, window: averageWindow)
    }

    /// Compute the progression suggestion for the next session.
    /// Returns nil only when the exercise has never been attempted.
    static func suggestion(
        for exercise: Exercise,
        mode: TrainingMode,
        aggressiveness: ProgressionAggressiveness,
        excludingSessionID: UUID? = nil
    ) -> ProgressionSuggestion? {
        let snapshots = snapshotsFromCompletedRecords(of: exercise, excludingSessionID: excludingSessionID)
        let unit = MassUnitPreferences.unit
        return suggestion(records: snapshots, mode: mode, params: aggressiveness.parameters) {
            MassMath.snapProgression(pounds: $0, unit: unit)
        }
    }

    /// Newest session date first. Equal timestamps break ties by session id,
    /// then record id, so two workouts saved with the same date always feed
    /// the algorithm in the same order.
    static func isNewerForProgression(_ lhs: ExerciseRecord, than rhs: ExerciseRecord) -> Bool {
        let lhsDate = lhs.session?.date ?? .distantPast
        let rhsDate = rhs.session?.date ?? .distantPast
        if lhsDate != rhsDate { return lhsDate > rhsDate }
        let lhsSession = lhs.session?.id.uuidString ?? ""
        let rhsSession = rhs.session?.id.uuidString ?? ""
        if lhsSession != rhsSession { return lhsSession > rhsSession }
        return lhs.id.uuidString > rhs.id.uuidString
    }

    /// Adapts an `Exercise`'s SwiftData records into `ExerciseRecordSnapshot`s
    /// for the pure algorithm. Preserves the existing filters: completed-only
    /// sessions, sorted newest-first by session date, then session id.
    private static func snapshotsFromCompletedRecords(
        of exercise: Exercise,
        excludingSessionID: UUID? = nil
    ) -> [ExerciseRecordSnapshot] {
        let completed = exercise.recordsArray
            .filter {
                $0.session?.isCompleted == true
                    && $0.session?.id != excludingSessionID
            }
        let kept = recordsForActiveGym(completed, exercise: exercise)
        return kept
            .sorted { isNewerForProgression($0, than: $1) }
            .compactMap { record in
                guard let sessionDate = record.session?.date else { return nil }
                let weighIns = (try? exercise.modelContext?.fetch(FetchDescriptor<BodyMetricEntry>()))?
                    .filter { $0.kind == .weight }
                    .map { LoadMath.WeighIn(date: $0.date, pounds: $0.value) } ?? []
                let sets = record.setsArray.map { swiftDataSet in
                    let asOf = swiftDataSet.completedAt
                    let body = swiftDataSet.bodyWeightUsedLbs > 0
                        ? swiftDataSet.bodyWeightUsedLbs
                        : LoadMath.bodyWeight(
                            asOf: asOf,
                            weighIns: weighIns,
                            settingsPounds: BodyWeightPreferences.pounds
                        )
                    return SetSnapshot(
                        weightLbs: swiftDataSet.effectiveLoadLbs(bodyWeight: body),
                        reps: swiftDataSet.reps,
                        isWarmup: swiftDataSet.isWarmup,
                        completedAt: swiftDataSet.completedAt
                    )
                }
                return ExerciseRecordSnapshot(
                    trainingMode: record.trainingMode,
                    sessionDate: sessionDate,
                    sets: sets
                )
            }
    }

    /// Travel gyms with fewer than two completed sessions still compare against Home.
    private static func recordsForActiveGym(_ records: [ExerciseRecord], exercise: Exercise) -> [ExerciseRecord] {
        guard let context = exercise.modelContext, GymLibrary.storeHasGyms(context) else { return records }
        let home = GymLibrary.ensureHome(in: context)
        let active = GymLibrary.activeID(in: context)
        let selection = GymHistory.select(
            rows: records.map { GymHistory.Row(id: $0.id, gymID: $0.session?.gymID) },
            activeGymID: active,
            homeGymID: home.id
        )
        return records.filter { selection.ids.contains($0.id) }
    }
}
