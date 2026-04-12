//
//  ExerciseRowView.swift
//  strength-training
//
//  Created by Daniel Kuhlwein on 2026-02-21.
//

import SwiftUI

private struct SpinningGradientCircle: View {
    let color: Color
    @State private var rotation: Double = 0

    var body: some View {
        Circle()
            .fill(
                AngularGradient(
                    gradient: Gradient(colors: [color.opacity(0.15), color]),
                    center: .center
                )
            )
            .frame(width: 22, height: 22)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}

struct ExerciseRowView: View {
    let exercise: Exercise
    @Bindable var viewModel: WorkoutViewModel
    @Binding var isExpanded: Bool

    // Measured natural height of SetInputView.
    // Using an explicit CGFloat (instead of nil) lets SwiftUI interpolate
    // the frame height smoothly: 0 ↔ inputHeight, both animatable values.
    @State private var inputHeight: CGFloat = 0

    private var hasSets: Bool {
        viewModel.currentRecord(for: exercise).map { !$0.setsArray.isEmpty } ?? false
    }

    private enum Status { case none, inProgress, completed }

    private var status: Status {
        if isExpanded { return .inProgress }
        return hasSets ? .completed : .none
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch status {
        case .none:
            Image(systemName: "circle")
                .font(.title3)
                .foregroundStyle(.tertiary)
        case .inProgress:
            SpinningGradientCircle(color: hasSets ? .green : .accentColor)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.green)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row
            HStack {
                statusIcon

                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name)
                        .font(.headline)
                    Text(exercise.muscleGroup)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                ProgressionBanner(
                    suggestion: viewModel.suggestion(for: exercise, mode: viewModel.selectedMode),
                    average: viewModel.recentAverage(for: exercise, mode: viewModel.selectedMode)
                )

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
