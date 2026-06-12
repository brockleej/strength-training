//
//  HealthKitCard.swift
//  strength-training
//

import SwiftUI

/// Apple Health live-metrics tile bar: source badge + BPM / kcal / elapsed tiles.
/// Apple-Health green identity, tuned to the dark surface. Presentational —
/// callers pass current values and re-render as they tick.
struct HealthKitCard: View {
    var bpm: Int? = nil      // nil → "—" (heart-rate sample not yet available)
    let kcal: Int
    let elapsed: String      // pre-formatted "18:42"

    var body: some View {
        HStack(spacing: 0) {
            sourceBadge
            tile(icon: "heart.fill", iconColor: .uplift.ahRed,
                 value: bpm.map(String.init) ?? "—", unit: "bpm", pulses: true)
            divider
            tile(icon: "flame.fill", iconColor: .uplift.kcalFlame,
                 value: String(kcal), unit: "kcal")
            divider
            tile(icon: "clock.fill", iconColor: .uplift.ahGreen,
                 value: elapsed, unit: nil)
        }
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.uplift.ahGreen.opacity(0.10))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.uplift.ahGreen.opacity(0.28), lineWidth: 0.5)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var sourceBadge: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.uplift.ahGreen)
                .frame(width: 22, height: 22)
                .overlay {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .accessibilityHidden(true)   // decorative — badge text carries the label
                }
            VStack(alignment: .leading, spacing: 1) {
                Text("APPLE HEALTH")
                    .font(.uplift.text(9, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(Color.uplift.ahGreen)
                Text("Workout · live")
                    .font(.uplift.text(10, weight: .medium))
                    .foregroundStyle(Color.uplift.fgMuted)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.uplift.ahGreen.opacity(0.14))
    }

    private func tile(icon: String, iconColor: Color, value: String, unit: String?, pulses: Bool = false) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(iconColor)
                .symbolEffect(.pulse, isActive: pulses)
                .accessibilityHidden(true)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.uplift.mono(16, weight: .bold))
                    .kerning(-0.4)
                    .foregroundStyle(Color.uplift.fg)
                if let unit {
                    Text(unit.uppercased())
                        .font(.uplift.text(9, weight: .semibold))
                        .tracking(0.2)
                        .foregroundStyle(Color.uplift.fgMuted)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tileAccessibilityLabel(icon: icon, value: value, unit: unit))
    }

    private func tileAccessibilityLabel(icon: String, value: String, unit: String?) -> String {
        let unitText = unit.map { " \($0)" } ?? ""
        switch icon {
        case "heart.fill": return "Heart rate \(value)\(unitText)"
        case "flame.fill": return "Calories \(value)\(unitText)"
        case "clock.fill": return "Elapsed time \(value)"
        default: return "\(value)\(unitText)"
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.uplift.ahGreen.opacity(0.22))
            .frame(width: 0.5)
            .padding(.vertical, 8)
    }
}

#Preview("HealthKitCard") {
    VStack(spacing: 16) {
        HealthKitCard(bpm: 142, kcal: 234, elapsed: "18:42")
        HealthKitCard(bpm: nil, kcal: 12, elapsed: "0:48")   // HR not yet sampled
    }
    .padding(20)
    .background(Color.uplift.bgElev)
    .preferredColorScheme(.dark)
}
