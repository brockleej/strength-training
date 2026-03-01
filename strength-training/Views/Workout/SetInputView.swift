//
//  SetInputView.swift
//  strength-training
//
//  Created by Daniel Kuhlwein on 2026-02-21.
//

import SwiftUI

// MARK: - StepperButton

/// A square rounded-rect +/- button that fires once on tap and continuously
/// while held. There is a 500ms pause before auto-repeat begins, after which
/// the action fires every `holdInterval` seconds until the finger lifts.
private struct StepperButton: View {
    let systemName: String
    /// Seconds between repeating steps once auto-repeat kicks in.
    let holdInterval: TimeInterval
    let action: () -> Void

    @State private var isPressed = false
    @State private var holdTask: Task<Void, Never>?

    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(isPressed ? Color(.tertiarySystemFill) : Color(.secondarySystemFill))
            .frame(width: 44, height: 44)
            .overlay {
                Image(systemName: systemName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .scaleEffect(isPressed ? 0.92 : 1.0)
            .animation(.easeInOut(duration: 0.08), value: isPressed)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isPressed else { return }
                        isPressed = true
                        action()
                        HapticService.stepperTick()
                        holdTask = Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(250))
                            while !Task.isCancelled {
                                action()
                                HapticService.stepperTick()
                                try? await Task.sleep(for: .seconds(holdInterval))
                            }
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                        holdTask?.cancel()
                        holdTask = nil
                    }
            )
    }
}

// MARK: - SetInputView

struct SetInputView: View {
    let exercise: Exercise
    @Bindable var viewModel: WorkoutViewModel

    @State private var weight: Double = 0
    @State private var reps: Int = 10
    @State private var hasLoadedDefaults = false

    var body: some View {
        VStack(spacing: 12) {
            // Logged sets for this session
            let currentSets = currentSessionSets
            if !currentSets.isEmpty {
                VStack(spacing: 4) {
                    ForEach(currentSets, id: \.id) { set in
                        HStack {
                            Text("Set \(set.setNumber)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(formattedWeight(set.weightLbs)) lbs x \(set.reps)")
                                .font(.subheadline.monospacedDigit())
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                viewModel.deleteSet(set, from: exercise)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                Divider()
            }

            // Input row
            HStack(spacing: 16) {
                // Weight — "lbs" moved into the label so both columns align
                VStack(spacing: 8) {
                    Text("Weight (lbs)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        StepperButton(systemName: "minus", holdInterval: 0.2) {
                            weight = max(0, weight - 5)
                        }
                        Text(formattedWeight(weight))
                            .font(.title3.monospacedDigit().bold())
                            .frame(minWidth: 44)
                        StepperButton(systemName: "plus", holdInterval: 0.2) {
                            weight += 5
                        }
                    }
                }

                Divider()
                    .frame(height: 60)

                // Reps
                VStack(spacing: 8) {
                    Text("Reps")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        StepperButton(systemName: "minus", holdInterval: 0.1) {
                            reps = max(1, reps - 1)
                        }
                        Text("\(reps)")
                            .font(.title3.monospacedDigit().bold())
                            .frame(minWidth: 30)
                        StepperButton(systemName: "plus", holdInterval: 0.1) {
                            reps += 1
                        }
                    }
                }
            }

            // Action buttons
            HStack(spacing: 12) {
                Button {
                    viewModel.addSet(exercise: exercise, weight: weight, reps: reps)
                } label: {
                    Label("Add Set", systemImage: "plus.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                if viewModel.lastRecord(for: exercise, mode: viewModel.selectedMode) != nil {
                    Button {
                        prefillFromLastSession()
                    } label: {
                        Label("Last", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .onAppear {
            if !hasLoadedDefaults {
                prefillFromLastSession()
                hasLoadedDefaults = true
            }
        }
        .onChange(of: viewModel.selectedMode) {
            prefillFromLastSession()
        }
    }

    private var currentSessionSets: [SetRecord] {
        guard let record = viewModel.currentRecord(for: exercise) else { return [] }
        return record.sets.sorted { $0.setNumber < $1.setNumber }
    }

    private func prefillFromLastSession() {
        if let lastRecord = viewModel.lastRecord(for: exercise, mode: viewModel.selectedMode),
           let lastSet = lastRecord.sets.sorted(by: { $0.setNumber < $1.setNumber }).last
        {
            weight = lastSet.weightLbs
            reps = lastSet.reps
        }
    }

    private func formattedWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", w)
            : String(format: "%.1f", w)
    }
}
