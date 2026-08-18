//
//  CoachSessionDetailView.swift
//  RockCoach
//

import SwiftUI

struct CoachSessionDetailView: View {
    let session: CoachStoredSession
    let client: CoachClient

    @State private var document: CoachSessionDocument?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if let notes = document?.session.notes, !notes.isEmpty {
                    noteCard(notes)
                }
                if let exercises = document?.session.exercises {
                    ForEach(exercises) { exercise in
                        exerciseCard(exercise)
                    }
                } else {
                    Text("Couldn’t read this session file.")
                        .foregroundStyle(Color.coach.muted)
                }
            }
            .padding(20)
        }
        .background(Color.coach.bg.ignoresSafeArea())
        .navigationTitle(session.dayType)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if document == nil { document = session.document }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(client.displayName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.coach.accent)
            Text(session.startedAt.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
                .font(.title2.weight(.bold))
                .foregroundStyle(Color.coach.fg)
            HStack(spacing: 8) {
                if !session.rotationTrack.isEmpty {
                    Text("Track \(session.rotationTrack)")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.coach.accent.opacity(0.16)))
                        .foregroundStyle(Color.coach.accent)
                }
                if let effort = session.effortRating {
                    Text("Effort \(effort)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.coach.muted)
                }
                Text("\(workingSetCount) working sets")
                    .font(.caption)
                    .foregroundStyle(Color.coach.dim)
            }
        }
    }

    private var workingSetCount: Int {
        document?.session.exercises
            .flatMap(\.sets)
            .filter { !$0.resolvedWarmup }
            .count ?? 0
    }

    private func noteCard(_ notes: String) -> some View {
        Text(notes)
            .font(.subheadline)
            .foregroundStyle(Color.coach.muted)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.coach.surface)
            )
    }

    private func exerciseCard(_ exercise: CoachExercisePayload) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(exercise.name)
                    .font(.headline)
                    .foregroundStyle(Color.coach.fg)
                Spacer()
                if let mode = exercise.trainingMode, !mode.isEmpty {
                    Text(mode)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.coach.muted)
                }
            }
            if let muscle = exercise.muscleGroup, !muscle.isEmpty {
                Text(muscle)
                    .font(.caption)
                    .foregroundStyle(Color.coach.dim)
            }
            if let notes = exercise.notes, !notes.isEmpty {
                Text(notes)
                    .font(.subheadline)
                    .foregroundStyle(Color.coach.muted)
            }
            VStack(spacing: 6) {
                ForEach(Array(exercise.sets.enumerated()), id: \.offset) { _, set in
                    setRow(set)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.coach.surface)
        )
    }

    private func setRow(_ set: CoachSetPayload) -> some View {
        HStack {
            Text("\(set.setNumber)")
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(Color.coach.dim)
                .frame(width: 20, alignment: .leading)
            Text(CoachProgression.setLabel(set))
                .font(.body.monospacedDigit().weight(.semibold))
                .foregroundStyle(Color.coach.fg)
            Spacer()
            if set.resolvedWarmup {
                Text("WU")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.coach.dim)
            }
            if set.resolvedAssisted {
                Text("ASSIST")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.coach.muted)
            }
        }
    }
}
