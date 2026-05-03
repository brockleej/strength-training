//
//  ExerciseDashboardRow.swift
//  ProgressionLab
//

import SwiftUI

struct ExerciseDashboardRow: View {
    let replay: ExerciseModeReplay
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(replay.exercise.name).font(.body)
                    Text("\(replay.exercise.dayType) · \(replay.mode.shortLabel)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 220, alignment: .leading)

                Text("\(replay.sessions.count)")
                    .frame(width: 50, alignment: .trailing)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)

                Sparkline(points: replay.sessions.map { ($0.sessionDate, $0.actualBestSet.weightLbs) })
                    .frame(width: 80)

                suggestionBadge(replay.nextSuggestionA, color: .blue)
                    .frame(width: 110, alignment: .leading)

                suggestionBadge(replay.nextSuggestionB, color: .orange)
                    .frame(width: 110, alignment: .leading)

                disagreementBadge(replay.disagreementRate)
                    .frame(width: 80, alignment: .trailing)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.04)))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func suggestionBadge(_ suggestion: ProgressionSuggestion?, color: Color) -> some View {
        if let s = suggestion {
            HStack(spacing: 4) {
                switch s.basis {
                case .consistent: Text("↑")
                case .improving:  Text("→")
                case .notEnoughData: EmptyView()
                }
                Text("\(Int(s.targetWeight)) × \(s.targetReps)")
                    .monospacedDigit()
            }
            .font(.callout)
            .foregroundStyle(color)
        } else {
            Text("—").foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func disagreementBadge(_ rate: Double?) -> some View {
        if let r = rate {
            Text("\(Int(r * 100))%")
                .monospacedDigit()
                .foregroundStyle(r > 0.2 ? Color.red : .secondary)
        } else {
            Text("—").foregroundStyle(.secondary)
        }
    }
}
