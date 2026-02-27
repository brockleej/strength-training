//
//  ExerciseListSection.swift
//  strength-training
//

import SwiftUI
import SwiftData

struct ExerciseListSection: View {
    let groupedExercises: [(DayType, [Exercise])]
    let modelContext: ModelContext

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Exercises")
                .font(.title2.bold())

            ForEach(groupedExercises, id: \.0) { dayType, exercises in
                VStack(alignment: .leading, spacing: 8) {
                    Label(dayType.rawValue, systemImage: dayType.systemImage)
                        .font(.headline)
                        .foregroundStyle(dayType.color)

                    ForEach(exercises) { exercise in
                        NavigationLink {
                            ExerciseDrillDownView(
                                exercise: exercise,
                                modelContext: modelContext
                            )
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(exercise.name)
                                        .font(.subheadline.weight(.medium))
                                    Text(exercise.muscleGroup)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
