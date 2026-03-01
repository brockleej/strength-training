//
//  VolumeScoreCard.swift
//  strength-training
//

import SwiftUI

struct VolumeScoreCard: View {
    let score: Double
    let trend: TrendDirection
    let delta: Double
    @Binding var filterMode: TrainingMode?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Volume", systemImage: "chart.bar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Menu {
                    Button("All") { filterMode = nil }
                    Button("Strength") { filterMode = .highWeightLowReps }
                    Button("Endurance") { filterMode = .lowWeightHighReps }
                } label: {
                    Text(filterLabel)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary)
                        .clipShape(Capsule())
                }
            }

            Text(formattedScore)
                .font(.title.bold())

            if trend != .insufficientData {
                HStack(spacing: 4) {
                    Image(systemName: trend.systemImage)
                        .foregroundStyle(trend.color)
                    Text("\(delta >= 0 ? "+" : "")\(formattedDelta)")
                        .font(.caption2)
                    Text("vs last wk.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Not enough data")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
    }

    private var filterLabel: String {
        switch filterMode {
        case nil: "All"
        case .highWeightLowReps: "Str"
        case .lowWeightHighReps: "End"
        }
    }

    private var formattedScore: String {
        if score >= 1000 {
            return String(format: "%.1fk", score / 1000)
        }
        return String(format: "%.0f", score)
    }

    private var formattedDelta: String {
        let abs = abs(delta)
        if abs >= 1000 {
            return String(format: "%.1fk", abs / 1000)
        }
        return String(format: "%.0f", abs)
    }
}
