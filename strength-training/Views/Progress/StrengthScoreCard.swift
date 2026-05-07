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
        VStack(alignment: .leading, spacing: 8) {
            Text("EST. 1RM TOTAL")
                .font(.uplift.text(11, weight: .semibold))
                .tracking(0.4)
                .foregroundStyle(Color.uplift.fgMuted)

            Num(formattedScore, size: 28, weight: .bold, color: .uplift.fg)

            Text("lbs combined")
                .font(.uplift.text(11, weight: .medium))
                .foregroundStyle(Color.uplift.fgMuted)

            Spacer(minLength: 0)

            HStack {
                Spacer(minLength: 0)
                trendPill
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.uplift.surface1)
        )
    }

    private var formattedScore: String {
        Int(score.rounded()).formatted(.number)
    }

    private var trendPill: some View {
        let color: Color
        let arrow: String
        let prefix: String
        switch trend {
        case .up:
            color = Color.uplift.up
            arrow = "arrow.up"
            prefix = delta >= 0 ? "+" : ""
        case .down:
            color = Color.uplift.down
            arrow = "arrow.down"
            prefix = delta >= 0 ? "+" : ""
        case .flat:
            color = Color.uplift.fgDim
            arrow = "arrow.right"
            prefix = delta >= 0 ? "+" : ""
        case .insufficientData:
            color = Color.uplift.fgDim
            arrow = "minus"
            prefix = ""
        }

        return HStack(spacing: 3) {
            Image(systemName: arrow)
                .font(.system(size: 11, weight: .semibold))
            Text(trend == .insufficientData ? "—" : "\(prefix)\(Int(delta.rounded()))")
                .font(.uplift.mono(12, weight: .semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            color.opacity(0.16),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
    }
}
