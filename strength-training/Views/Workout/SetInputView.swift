//
//  SetInputView.swift
//  strength-training
//
//  Created by Daniel Kuhlwein on 2026-02-21.
//

import SwiftUI

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
                // Weight
                VStack(spacing: 4) {
                    Text("Weight")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        Button {
                            weight = max(0, weight - 5)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title3)
                        }
                        .buttonStyle(.borderless)

                        Text("\(formattedWeight(weight))")
                            .font(.title3.monospacedDigit().bold())
                            .frame(minWidth: 44)

                        Button {
                            weight += 5
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                        }
                        .buttonStyle(.borderless)
                    }
                    Text("lbs")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Divider()
                    .frame(height: 50)

                // Reps
                VStack(spacing: 4) {
                    Text("Reps")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        Button {
                            reps = max(1, reps - 1)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title3)
                        }
                        .buttonStyle(.borderless)

                        Text("\(reps)")
                            .font(.title3.monospacedDigit().bold())
                            .frame(minWidth: 30)

                        Button {
                            reps += 1
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                        }
                        .buttonStyle(.borderless)
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
