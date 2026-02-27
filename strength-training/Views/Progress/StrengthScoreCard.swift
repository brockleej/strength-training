//
//  StrengthScoreCard.swift
//  strength-training
//

import SwiftUI

struct StrengthScoreCard: View {
    let score: Double
    let trend: TrendDirection
    let delta: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Strength", systemImage: "flame")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(score, format: .number.precision(.fractionLength(0)))
                .font(.title.bold())

            if trend != .insufficientData {
                HStack(spacing: 4) {
                    Image(systemName: trend.systemImage)
                        .foregroundStyle(trend.color)
                    Text("\(delta >= 0 ? "+" : "")\(delta, specifier: "%.0f")")
                        .font(.caption2)
                    Text("vs last mo.")
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
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
