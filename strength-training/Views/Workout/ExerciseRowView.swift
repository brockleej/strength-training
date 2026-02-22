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

    // Measured natural height of SetInputView.
    // Using an explicit CGFloat (instead of nil) lets SwiftUI interpolate
    // the frame height smoothly: 0 ↔ inputHeight, both animatable values.
    @State private var inputHeight: CGFloat = 0

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

                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .contentShape(Rectangle())
            .onTapGesture {
                isExpanded.toggle()
            }

            // Content is always in the view hierarchy — never inserted/removed.
            // This prevents the "fade in on top of siblings" z-order issue that
            // occurs when SwiftUI places a newly-inserted view at its final
            // layout position before surrounding rows have animated there.
            //
            // fixedSize forces the view to always render at its natural height
            // regardless of the frame constraint, so the GeometryReader background
            // always measures the true content height even when collapsed.
            // The frame clips from 0 → inputHeight using two real CGFloats that
            // SwiftUI can actually interpolate — unlike nil → 0.
            SetInputView(exercise: exercise, viewModel: viewModel)
                .padding(.leading, 36)
                .fixedSize(horizontal: false, vertical: true)
                .background {
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { inputHeight = geo.size.height }
                            .onChange(of: geo.size.height) { _, new in
                                guard new > 0 else { return }
                                inputHeight = new
                            }
                    }
                }
                .frame(height: isExpanded ? inputHeight : 0, alignment: .top)
                .clipped()
                .allowsHitTesting(isExpanded)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 16)
    }
}
