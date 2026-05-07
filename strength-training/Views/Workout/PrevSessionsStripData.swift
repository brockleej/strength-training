// strength-training/Views/Workout/PrevSessionsStripData.swift
import Foundation

/// Pure-function shaper for `PrevSessionsStrip.Entry` data. Takes the SwiftData
/// objects + filters/sorts/caps and emits display-ready entries.
enum PrevSessionsStripData {

    /// Returns up to 10 entries for the given exercise + mode. Order: oldest first,
    /// most recent last (matches the strip's right-most = newest layout).
    static func shape(
        for exercise: Exercise,
        mode: TrainingMode,
        now: Date = .now
    ) -> [PrevSessionsStrip.Entry] {
        // Exercise.recordsArray is the inverse-relationship array of ExerciseRecords
        // referencing this exercise. Filter to: completed sessions, matching mode.
        let allRecords = exercise.recordsArray
        let priorRecords = allRecords.filter { record in
            record.trainingMode == mode &&
            record.session?.isCompleted == true
        }
        let sorted = priorRecords.sorted { ($0.session?.date ?? .distantPast) < ($1.session?.date ?? .distantPast) }
        let lastTen = sorted.suffix(10)

        return lastTen.map { record in
            let setsArray = record.setsArray.sorted(by: { $0.setNumber < $1.setNumber })
            let topWeight = setsArray.map(\.weightLbs).max() ?? 0
            let setsLabel: String = {
                let weight = formatWeight(topWeight)
                if setsArray.count <= 1 {
                    let firstReps = setsArray.first.map { String($0.reps) } ?? "0"
                    return "\(weight) × \(firstReps)"
                }
                // First reps after the ×, then bullet-separated remaining
                let firstRep = setsArray.first.map { String($0.reps) } ?? "0"
                let rest = setsArray.dropFirst().map { String($0.reps) }.joined(separator: " · ")
                return "\(weight) × \(firstRep) · \(rest)"
            }()
            let date = record.session?.date ?? .distantPast
            let dateLabel = TodayViewModel.relativeDayLabel(for: date, now: now)
            return PrevSessionsStrip.Entry(
                id: record.id,
                dateLabel: dateLabel,
                setsLabel: setsLabel
            )
        }
    }

    private static func formatWeight(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(v)) : String(format: "%.1f", v)
    }
}
