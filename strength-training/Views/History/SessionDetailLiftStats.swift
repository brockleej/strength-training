import Foundation

/// Pure-function shaper for `SessionDetailView`'s lifts list. Each row carries the
/// exercise's display name, sets count, top set, PR status, and weight delta vs
/// the most recent prior session for that exercise.
enum SessionDetailLiftStats {

    /// One row in the Session Detail "Lifts" section.
    struct LiftRow: Equatable, Identifiable {
        /// Stable identity = the source `ExerciseRecord.id`.
        let id: UUID
        let exerciseID: UUID
        let exerciseName: String
        let dayType: DayType
        let setsCount: Int
        let topWeightLb: Double
        let topReps: Int
        let isPR: Bool
        /// Weight delta vs previous session's top set for this exercise.
        /// Nil if this is the first session of the exercise.
        let deltaVsLastLb: Double?
    }

    /// Build rows for the given session. Records without an attached `Exercise`
    /// are dropped (orphans). Order: by `record.sortOrder` ascending, matching
    /// how the user logged them.
    static func rows(for session: WorkoutSession) -> [LiftRow] {
        let records = session.exerciseRecordsArray
            .filter { $0.exercise != nil && !$0.setsArray.filter({ !$0.isWarmup }).isEmpty }
            .sorted { $0.sortOrder < $1.sortOrder }

        return records.compactMap { record in
            guard let exercise = record.exercise else { return nil }

            let workingSets = record.setsArray.filter { !$0.isWarmup }
            guard !workingSets.isEmpty else { return nil }

            // Top set = highest e1RM, ties broken by weight then reps.
            guard let top = workingSets.max(by: { lhs, rhs in
                let l = ProgressionService.e1RM(weight: lhs.weightLbs, reps: lhs.reps)
                let r = ProgressionService.e1RM(weight: rhs.weightLbs, reps: rhs.reps)
                if l != r { return l < r }
                if lhs.weightLbs != rhs.weightLbs { return lhs.weightLbs < rhs.weightLbs }
                return lhs.reps < rhs.reps
            }) else { return nil }

            let currentMaxE1RM = ProgressionService.e1RM(weight: top.weightLbs, reps: top.reps)

            // Prior records: same exercise, completed session, dated strictly before this session.
            // Sort newest-first; tie-break on session.id for deterministic "previous session"
            // selection when two sessions share the exact same timestamp.
            let priorRecords = exercise.recordsArray
                .filter { rec in
                    rec.session?.isCompleted == true &&
                    (rec.session?.date ?? .distantFuture) < session.date
                }
                .sorted { lhs, rhs in
                    let lDate = lhs.session?.date ?? .distantPast
                    let rDate = rhs.session?.date ?? .distantPast
                    if lDate != rDate { return lDate > rDate }
                    let lID = lhs.session?.id.uuidString ?? ""
                    let rID = rhs.session?.id.uuidString ?? ""
                    return lID > rID
                }

            // PR: currentMax > all-time prior max
            let priorMaxE1RM = priorRecords
                .flatMap { $0.setsArray.filter { !$0.isWarmup } }
                .map { ProgressionService.e1RM(weight: $0.weightLbs, reps: $0.reps) }
                .max() ?? 0
            let isPR = currentMaxE1RM > priorMaxE1RM

            // Delta vs last session's top *weight* (not e1RM).
            let deltaLb: Double? = priorRecords.first.flatMap { prev in
                let prevTop = prev.setsArray
                    .filter { !$0.isWarmup }
                    .max(by: { ProgressionService.e1RM(weight: $0.weightLbs, reps: $0.reps)
                             < ProgressionService.e1RM(weight: $1.weightLbs, reps: $1.reps) })
                guard let prevTop else { return nil }
                return top.weightLbs - prevTop.weightLbs
            }

            return LiftRow(
                id: record.id,
                exerciseID: exercise.id,
                exerciseName: exercise.name,
                dayType: exercise.dayType,
                setsCount: workingSets.count,
                topWeightLb: top.weightLbs,
                topReps: top.reps,
                isPR: isPR,
                deltaVsLastLb: deltaLb
            )
        }
    }

    /// Aggregate PR count for a session (= number of LiftRows with isPR=true).
    /// Used by `HistoryListView`'s session row + Session Detail's PR callout.
    static func prCount(for session: WorkoutSession) -> Int {
        rows(for: session).filter(\.isPR).count
    }

    /// Names of PR-earning exercises for the PR-callout subtitle.
    static func prExerciseNames(for session: WorkoutSession) -> [String] {
        rows(for: session).filter(\.isPR).map(\.exerciseName)
    }
}
