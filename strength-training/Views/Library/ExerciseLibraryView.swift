//
//  ExerciseLibraryView.swift
//  strength-training
//
//  Created by Daniel Kuhlwein on 2026-02-21.
//

import SwiftUI
import SwiftData

struct ExerciseLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Exercise.sortOrder) private var allExercises: [Exercise]
    @State private var showAddSheet = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(DayType.allCases.filter { $0 != .fullBody }) { dayType in
                    Section(dayType.rawValue) {
                        let exercises = allExercises.filter { $0.dayType == dayType }
                        ForEach(exercises) { exercise in
                            ExerciseLibraryRow(exercise: exercise)
                        }
                        .onDelete { indexSet in
                            let exercises = allExercises.filter { $0.dayType == dayType }
                            for index in indexSet {
                                let exercise = exercises[index]
                                if exercise.isCustom {
                                    modelContext.delete(exercise)
                                }
                            }
                            try? modelContext.save()
                        }
                    }
                }
            }
            .navigationTitle("Exercises")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddExerciseView()
            }
        }
    }
}

private struct ExerciseLibraryRow: View {
    let exercise: Exercise

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(exercise.name)
                        .font(.body)
                    if exercise.isCustom {
                        Text("Custom")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.orange.opacity(0.15))
                            .foregroundStyle(.orange)
                            .clipShape(Capsule())
                    }
                }
                Text(exercise.muscleGroup)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .deleteDisabled(!exercise.isCustom)
    }
}
