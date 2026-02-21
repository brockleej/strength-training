//
//  ChartsViewModel.swift
//  strength-training
//
//  Created by Daniel Kuhlwein on 2026-02-21.
//

import SwiftUI
import SwiftData

@Observable
final class ChartsViewModel {
    var modelContext: ModelContext
    var selectedExercise: Exercise?
    var selectedMode: TrainingMode = .highWeightLowReps
    var selectedDayType: DayType = .arms

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    struct DataPoint: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
    }

    func allExercises(for dayType: DayType) -> [Exercise] {
        let descriptor = FetchDescriptor<Exercise>(sortBy: [SortDescriptor(\Exercise.sortOrder)])
        let all = (try? modelContext.fetch(descriptor)) ?? []
        if dayType == .fullBody { return all }
        return all.filter { $0.dayType == dayType }
    }

    /// Weight progression: max weight per session for the selected exercise + mode.
    func weightProgression() -> [DataPoint] {
        fetchRecords().compactMap { record in
            guard let date = record.session?.date,
                  let maxWeight = record.sets.map(\.weightLbs).max()
            else { return nil }
            return DataPoint(date: date, value: maxWeight)
        }
        .sorted { $0.date < $1.date }
    }

    /// Reps progression: total reps per session for the selected exercise + mode.
    func repsProgression() -> [DataPoint] {
        fetchRecords().compactMap { record in
            guard let date = record.session?.date else { return nil }
            let totalReps = record.sets.reduce(0) { $0 + $1.reps }
            guard totalReps > 0 else { return nil }
            return DataPoint(date: date, value: Double(totalReps))
        }
        .sorted { $0.date < $1.date }
    }

    /// Volume progression: sum(weight * reps) per session.
    func volumeProgression() -> [DataPoint] {
        fetchRecords().compactMap { record in
            guard let date = record.session?.date else { return nil }
            let volume = record.sets.reduce(0.0) { $0 + $1.weightLbs * Double($1.reps) }
            guard volume > 0 else { return nil }
            return DataPoint(date: date, value: volume)
        }
        .sorted { $0.date < $1.date }
    }

    private func fetchRecords() -> [ExerciseRecord] {
        guard let exercise = selectedExercise else { return [] }
        // Traverse the relationship directly — avoids #Predicate limitations
        // with optional chaining and enum rawValue comparisons.
        return exercise.records
            .filter { $0.trainingMode == selectedMode && $0.session?.isCompleted == true }
            .sorted { ($0.session?.date ?? .distantPast) < ($1.session?.date ?? .distantPast) }
    }
}
