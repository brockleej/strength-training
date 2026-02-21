//
//  ExerciseRowView.swift
//  strength-training
//
//  Created by Daniel Kuhlwein on 2026-02-21.
//

import SwiftUI

struct ExerciseRowView: View {
    let exercise: Exercise
    @Bindable var viewModel: WorkoutViewModel
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row
            HStack {
                Button {
                    let completed = viewModel.isExerciseCompleted(exercise)
                    if completed {
                        viewModel.markExerciseIncomplete(exercise)
                    } else {
                        viewModel.markExerciseComplete(exercise)
                    }
                } label: {
                    Image(systemName: viewModel.isExerciseCompleted(exercise)
                          ? "checkmark.circle.fill"
                          : "circle")
                        .font(.title3)
                        .foregroundStyle(
                            viewModel.isExerciseCompleted(exercise)
                                ? .green
                                : .secondary
                        )
                }
                .buttonStyle(.borderless)

                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name)
                        .font(.headline)
                    Text(exercise.muscleGroup)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let last = viewModel.lastRecord(for: exercise, mode: viewModel.selectedMode) {
                    LastSessionBanner(record: last)
                }

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }

            // Expanded: set input
            if isExpanded {
                SetInputView(exercise: exercise, viewModel: viewModel)
                    .padding(.leading, 36)
            }
        }
        .padding(.vertical, 4)
    }
}
