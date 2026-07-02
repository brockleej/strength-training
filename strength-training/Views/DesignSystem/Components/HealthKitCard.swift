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
        ActivityRingsGlyph()
            .frame(width: 26, height: 26)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.uplift.ahGreen.opacity(0.14))
            .accessibilityLabel("Apple Health live workout")
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

/// Miniature Activity-rings nod: three concentric arcs in the Fitness colors.
private struct ActivityRingsGlyph: View {
    var body: some View {
        ZStack {
            ring(color: Color(hex: 0xFA114F), inset: 0)     // move
            ring(color: Color(hex: 0x92E82A), inset: 6)     // exercise
            ring(color: Color(hex: 0x1EEAEF), inset: 12)    // stand
        }
        .accessibilityHidden(true)
    }

    private func ring(color: Color, inset: CGFloat) -> some View {
        Circle()
            .trim(from: 0.08, to: 1)
            .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            .rotationEffect(.degrees(-90))
            .padding(inset / 2)
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
