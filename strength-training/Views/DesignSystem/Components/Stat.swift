//
//  Stat.swift
//  strength-training
//

import SwiftUI

/// Eyebrow label + hero value + optional unit. 20pt value — stats cards.
struct Stat: View {
    let label: String
    let value: String
    var unit: String? = nil
    var tone: Color = .uplift.fg

    var body: some View {
        StatLayout(label: label, value: value, unit: unit, tone: tone, valueSize: 20, valueWeight: .semibold)
    }
}

/// 22pt value — History summary strip.
struct SummaryStat: View {
    let label: String
    let value: String
    var unit: String? = nil
    var tone: Color = .uplift.fg

    var body: some View {
        StatLayout(label: label, value: value, unit: unit, tone: tone, valueSize: 22, valueWeight: .bold)
    }
}

/// 28pt value — Workout Summary 2×2 grid.
struct BigStat: View {
    let label: String
    let value: String
    var unit: String? = nil
    var tone: Color = .uplift.fg

    var body: some View {
        StatLayout(label: label, value: value, unit: unit, tone: tone, valueSize: 28, valueWeight: .bold)
    }
}

private struct StatLayout: View {
    let label: String
    let value: String
    let unit: String?
    let tone: Color
    let valueSize: CGFloat
    let valueWeight: Font.Weight

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .textCase(.uppercase)
                .font(.uplift.text(11, weight: .semibold))
                .tracking(0.3)
                .foregroundStyle(Color.uplift.fgMuted)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Num(value, size: valueSize, weight: valueWeight, color: tone)
                if let unit {
                    Text(unit)
                        .font(.uplift.text(12, weight: .medium))
                        .foregroundStyle(Color.uplift.fgMuted)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)\(unit.map { " \($0)" } ?? "")")
    }
}

#Preview("Stat trio") {
    VStack(spacing: 20) {
        // Stats card row (session detail pattern)
        HStack(spacing: 14) {
            Stat(label: "Duration", value: "47", unit: "min")
            Stat(label: "Volume", value: "12,840", unit: "lb")
            Stat(label: "Sets", value: "19")
            Stat(label: "PRs", value: "2", tone: .uplift.pr)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.uplift.surface1))

        // Summary strip (history pattern)
        HStack(spacing: 12) {
            SummaryStat(label: "This month", value: "14", unit: "sessions")
            Rectangle().fill(Color.uplift.hairline).frame(width: 1)
            SummaryStat(label: "Volume", value: "187k", unit: "lb")
            Rectangle().fill(Color.uplift.hairline).frame(width: 1)
            SummaryStat(label: "PRs", value: "6", tone: .uplift.pr)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.uplift.surface1))

        // 2×2 grid (workout summary pattern)
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
            BigStat(label: "Duration", value: "52", unit: "min")
            BigStat(label: "Volume", value: "14,820", unit: "lb")
            BigStat(label: "Sets", value: "18")
            BigStat(label: "PRs", value: "1", tone: .uplift.pr)
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.uplift.surface1))
    }
    .padding(20)
    .background(Color.uplift.bgElev)
    .preferredColorScheme(.dark)
}
