//
//  SessionDetailView.swift
//  strength-training
//
//  Created by Daniel Kuhlwein on 2026-02-21.
//

import SwiftUI

struct SessionDetailView: View {
    let session: WorkoutSession

    var body: some View {
        List {
            Section {
                LabeledContent("Date", value: session.date.formatted(.dateTime.weekday(.wide).month().day().year()))
                LabeledContent("Day Type", value: session.dayType.rawValue)
                LabeledContent("Exercises Completed", value: "\(completedRecords.count)")
                LabeledContent("Total Sets", value: "\(totalSets)")
                LabeledContent("Total Volume", value: "\(formattedVolume) lbs")
            }

            ForEach(sortedRecords) { record in
                Section {
                    HStack {
                        Text(record.exercise?.name ?? "Unknown")
                            .font(.headline)
                        Spacer()
                        Text(record.trainingMode.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.quaternary)
                            .clipShape(Capsule())
                    }

                    ForEach(record.sets.sorted(by: { $0.setNumber < $1.setNumber })) { set in
                        HStack {
                            Text("Set \(set.setNumber)")
                                .foregroundStyle(.secondary)
                            if set.isWarmup {
                                Text("Warmup")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                            Spacer()
                            Text("\(formattedWeight(set.weightLbs)) lbs x \(set.reps)")
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
        .navigationTitle("\(session.dayType.rawValue) Day")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var completedRecords: [ExerciseRecord] {
        session.exerciseRecords.filter { !$0.sets.isEmpty }
    }

    private var sortedRecords: [ExerciseRecord] {
        completedRecords.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var totalSets: Int {
        completedRecords.reduce(0) { $0 + $1.sets.count }
    }

    private var formattedVolume: String {
        let volume = completedRecords.reduce(0.0) { total, record in
            total + record.sets.reduce(0.0) { $0 + $1.weightLbs * Double($1.reps) }
        }
        return volume.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", volume)
            : String(format: "%.1f", volume)
    }

    private func formattedWeight(_ weight: Double) -> String {
        weight.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", weight)
            : String(format: "%.1f", weight)
    }
}
