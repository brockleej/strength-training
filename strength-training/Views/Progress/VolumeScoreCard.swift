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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("VOLUME")
                    .font(.uplift.text(11, weight: .semibold))
                    .tracking(0.4)
                    .foregroundStyle(Color.uplift.fgMuted)
                Spacer()
            }

            modeToggleRow

            Num(formattedScore, size: 28, weight: .bold, color: .uplift.fg)

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

    private var modeToggleRow: some View {
        HStack(spacing: 4) {
            modeChip("All", isActive: filterMode == nil) { filterMode = nil }
            modeChip("Str", isActive: filterMode == .highWeightLowReps) { filterMode = .highWeightLowReps }
            modeChip("End", isActive: filterMode == .lowWeightHighReps) { filterMode = .lowWeightHighReps }
        }
        .padding(3)
        .background(Color.uplift.surface2, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private func modeChip(_ title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.uplift.text(11, weight: .semibold))
                .foregroundStyle(isActive ? Color.uplift.fg : Color.uplift.fgMuted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(
                    isActive ? Color.uplift.surface3 : Color.clear,
                    in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                )
        }
        .buttonStyle(.plain)
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
            Text(trend == .insufficientData ? "—" : "\(prefix)\(formattedDelta)")
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
