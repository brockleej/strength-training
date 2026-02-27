//
//  SessionDetailView.swift
//  strength-training
//
//  Created by Daniel Kuhlwein on 2026-02-21.
//

import SwiftUI

struct SessionDetailView: View {
    @Environment(\.modelContext) private var modelContext
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
                    if let exercise = record.exercise {
                        NavigationLink {
                            ExerciseDrillDownView(
                                exercise: exercise,
                                modelContext: modelContext
                            )
                        } label: {
                            ExerciseHeaderRow(
                                exercise: exercise,
                                record: record,
                                sessionDate: session.date
                            )
                        }
                    } else {
                        HStack {
                            Text("Unknown")
                                .font(.headline)
                            Spacer()
                            Text(record.trainingMode.rawValue)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(.quaternary)
                                .clipShape(Capsule())
                        }
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

// MARK: - Exercise Header with Trend & PR Indicators

private struct ExerciseHeaderRow: View {
    let exercise: Exercise
    let record: ExerciseRecord
    let sessionDate: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(exercise.name)
                    .font(.headline)

                if isPR {
                    Text("PR")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.pink)
                        .clipShape(Capsule())
                }

                Spacer()

                Text(record.trainingMode.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.quaternary)
                    .clipShape(Capsule())
            }

            if let comparison = comparisonText {
                HStack(spacing: 4) {
                    Image(systemName: trendIcon)
                        .font(.caption2)
                        .foregroundStyle(trendColor)
                    Text(comparison)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Computations

    private var currentE1RM: Double {
        record.sets
            .filter { !$0.isWarmup }
            .map { $0.weightLbs * (1.0 + Double($0.reps) / 30.0) }
            .max() ?? 0
    }

    private var previousRecord: ExerciseRecord? {
        exercise.records
            .filter { rec in
                rec.id != record.id &&
                rec.session?.isCompleted == true &&
                (rec.session?.date ?? .distantFuture) < sessionDate
            }
            .sorted { ($0.session?.date ?? .distantPast) > ($1.session?.date ?? .distantPast) }
            .first
    }

    private var previousE1RM: Double? {
        guard let prev = previousRecord else { return nil }
        let best = prev.sets
            .filter { !$0.isWarmup }
            .map { $0.weightLbs * (1.0 + Double($0.reps) / 30.0) }
            .max()
        return best
    }

    private var allTimeE1RM: Double {
        let completedRecords = exercise.records.filter { $0.session?.isCompleted == true }
        let workingSets = completedRecords.flatMap { $0.sets.filter { !$0.isWarmup } }
        let e1rms: [Double] = workingSets.map { set in
            set.weightLbs * (1.0 + Double(set.reps) / 30.0)
        }
        return e1rms.max() ?? 0
    }

    private var isPR: Bool {
        currentE1RM > 0 && currentE1RM >= allTimeE1RM
    }

    private var delta: Double? {
        guard let prev = previousE1RM, prev > 0 else { return nil }
        return currentE1RM - prev
    }

    private var comparisonText: String? {
        guard let d = delta else { return nil }
        let sign = d >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.0f", d)) lbs e1RM vs last"
    }

    private var trendIcon: String {
        guard let d = delta else { return "minus" }
        if d > 0 { return "arrow.up.right" }
        if d < 0 { return "arrow.down.right" }
        return "arrow.right"
    }

    private var trendColor: Color {
        guard let d = delta else { return .secondary }
        if d > 0 { return .green }
        if d < 0 { return .red }
        return .secondary
    }
}
