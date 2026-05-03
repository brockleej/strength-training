//
//  ExerciseDetailView.swift
//  ProgressionLab
//

import SwiftUI

struct ExerciseDetailView: View {
    let replay: ExerciseModeReplay
    let configAName: String
    let configBName: String
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            header
            ReplayChart(
                replay: replay,
                configAName: configAName,
                configBName: configBName
            )
            .padding(.horizontal, 16)

            Divider()

            ReplayTable(
                sessions: replay.sessions,
                configAName: configAName,
                configBName: configBName
            )
        }
        .frame(minWidth: 1000, minHeight: 700)
    }

    private var header: some View {
        HStack(spacing: 16) {
            Button(action: onBack) {
                Label("Back", systemImage: "chevron.left")
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(replay.exercise.name).font(.title2).fontWeight(.semibold)
                Text("\(replay.exercise.dayType) · \(replay.mode.description) · \(replay.sessions.count) sessions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
    }
}
