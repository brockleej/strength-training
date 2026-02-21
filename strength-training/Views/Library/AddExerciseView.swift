//
//  AddExerciseView.swift
//  strength-training
//
//  Created by Daniel Kuhlwein on 2026-02-21.
//

import SwiftUI
import SwiftData

struct AddExerciseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    // Fetch all exercises to compute sort order — avoids #Predicate enum issues
    @Query(sort: \Exercise.sortOrder, order: .reverse) private var allExercises: [Exercise]

    var preselectedDayType: DayType = .arms

    @State private var name = ""
    @State private var dayType: DayType = .arms
    @State private var muscleGroup = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise Details") {
                    TextField("Exercise Name", text: $name)

                    Picker("Day Type", selection: $dayType) {
                        ForEach(DayType.allCases.filter { $0 != .fullBody }) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }

                    TextField("Muscle Group (optional)", text: $muscleGroup)
                }
            }
            .navigationTitle("New Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addExercise()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                dayType = preselectedDayType == .fullBody ? .arms : preselectedDayType
            }
        }
    }

    private func addExercise() {
        // Compute max sortOrder for this dayType in Swift (avoids #Predicate enum issue)
        let maxOrder = allExercises
            .filter { $0.dayType == dayType }
            .first?.sortOrder ?? -1

        let exercise = Exercise(
            name: name.trimmingCharacters(in: .whitespaces),
            dayType: dayType,
            muscleGroup: muscleGroup.trimmingCharacters(in: .whitespaces),
            sortOrder: maxOrder + 1,
            isCustom: true
        )
        modelContext.insert(exercise)
        try? modelContext.save()
        dismiss()
    }
}
