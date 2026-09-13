//
//  PlannedWorkoutPreviewView.swift
//  RockLog
//
//  Read-only look at a queued planned session. Start is at the bottom;
//  Today still has its own Start button for the next unused workout.
//

import SwiftUI
import SwiftData

struct PlannedWorkoutPreviewView: View {
    let session: WorkoutSession
    var onStart: () -> Void
    var onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    private var lifts: [(id: UUID, name: String, recipe: String)] {
        session.exerciseRecordsArray
            .sorted { $0.sortOrder < $1.sortOrder }
            .compactMap { record in
                guard let exercise = record.exercise else { return nil }
                return (
                    id: record.id,
                    name: exercise.name,
                    recipe: WorkoutFormat.setRecipe(record.plannedSetsArray)
                )
            }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                if lifts.isEmpty {
                    Text("No lifts in this workout")
                        .font(.uplift.text(14, weight: .medium))
                        .foregroundStyle(Color.uplift.fgMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 24)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(lifts.enumerated()), id: \.element.id) { index, lift in
                            liftRow(index: index + 1, name: lift.name, recipe: lift.recipe)
                            if index < lifts.count - 1 {
                                Rectangle()
                                    .fill(Color.uplift.hairline)
                                    .frame(height: 0.5)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .background {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.uplift.surface1)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(Color.uplift.bgElev)
        .scrollIndicators(.hidden)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if onDelete != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Delete", role: .destructive) {
                        onDelete?()
                    }
                    .accessibilityLabel("Delete this planned workout")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button(action: onStart) {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Start workout")
                        .font(.uplift.text(16, weight: .semibold))
                        .kerning(-0.2)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.uplift.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .foregroundStyle(Color.uplift.onAccent)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 8)
            .background(Color.uplift.bgElev.opacity(0.92))
            .accessibilityLabel("Start \(session.day.rawValue) workout")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                DayChip(dayType: session.day, size: .md)
                Text(session.day.rawValue)
                    .font(.uplift.display(28, weight: .bold))
                    .kerning(-0.6)
                    .foregroundStyle(Color.uplift.fg)
            }
            if let block = session.trainingBlock?.name, !block.isEmpty {
                Text(block)
                    .font(.uplift.text(13, weight: .medium))
                    .foregroundStyle(Color.uplift.fgMuted)
            }
            Text("\(lifts.count) lift\(lifts.count == 1 ? "" : "s")")
                .font(.uplift.text(13, weight: .medium))
                .foregroundStyle(Color.uplift.fgDim)
        }
    }

    private func liftRow(index: Int, name: String, recipe: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(index)")
                .font(.uplift.mono(14, weight: .bold))
                .foregroundStyle(Color.uplift.fgDim)
                .frame(width: 22, alignment: .center)
            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.uplift.text(15, weight: .semibold))
                    .foregroundStyle(Color.uplift.fg)
                if !recipe.isEmpty {
                    Text(recipe)
                        .font(.uplift.mono(13, weight: .medium))
                        .foregroundStyle(Color.uplift.fgMuted)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(recipe.isEmpty ? name : "\(name), \(recipe)")
    }
}
