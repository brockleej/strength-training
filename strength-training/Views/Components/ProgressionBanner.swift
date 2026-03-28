//
//  ProgressionBanner.swift
//  strength-training
//

import SwiftUI

struct ProgressionBanner: View {
    let suggestion: ProgressionSuggestion?
    let average: RecentAverage?

    var body: some View {
        if let s = suggestion {
            suggestionView(s)
        } else {
            Text("No history yet")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private func suggestionView(_ s: ProgressionSuggestion) -> some View {
        switch s.basis {
        case .notEnoughData:
            // Single-session reference — no "Target:" label, just raw values
            Text("\(formattedWeight(s.targetWeight)) lbs × \(s.targetReps)")
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quaternary)
                .clipShape(Capsule())

        case .consistent, .improving:
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 3) {
                    if s.basis == .consistent {
                        Image(systemName: "arrow.up")
                            .font(.caption2.weight(.semibold))
                    }
                    Text("Target: \(formattedWeight(s.targetWeight)) lbs × \(s.targetReps)")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundStyle(.tint)

                if let avg = average {
                    Text("Avg: \(formattedWeight(avg.weight)) lbs × \(avg.reps) (last \(avg.sessionCount))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func formattedWeight(_ weight: Double) -> String {
        weight.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", weight)
            : String(format: "%.1f", weight)
    }
}

#Preview("Consistent — weight bump") {
    ProgressionBanner(
        suggestion: ProgressionSuggestion(targetWeight: 45, targetReps: 10, basis: .consistent),
        average: RecentAverage(weight: 40, reps: 10, sessionCount: 4)
    )
    .padding()
}

#Preview("Improving — rep bump") {
    ProgressionBanner(
        suggestion: ProgressionSuggestion(targetWeight: 40, targetReps: 11, basis: .improving),
        average: RecentAverage(weight: 40, reps: 10, sessionCount: 4)
    )
    .padding()
}

#Preview("Not enough data") {
    ProgressionBanner(
        suggestion: ProgressionSuggestion(targetWeight: 35, targetReps: 8, basis: .notEnoughData),
        average: nil
    )
    .padding()
}

#Preview("No history") {
    ProgressionBanner(suggestion: nil, average: nil)
        .padding()
}
