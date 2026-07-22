//
//  DayPickerCard.swift
//  strength-training
//

import SwiftUI

/// Selectable day-type card for the Today picker.
/// Selected: accent border + top-right radial glow + filled check.
/// Suspended: "N exercises in progress" badge under the subtitle.
struct DayPickerCard: View {
    let dayType: DayType
    let lastDuration: String?      // "52 min" — appended as "· 52 min last time"
    let isSelected: Bool
    let inProgressCount: Int?      // non-nil → suspended-session badge
    /// 1-based position in the user's weekly day order (Settings → Training Split).
    var weekPosition: Int? = nil
    /// Weekly mode: already trained this calendar week.
    var isCompletedInCycle: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                if let weekPosition {
                    Text("\(weekPosition)")
                        .font(.uplift.mono(14, weight: .bold))
                        .foregroundStyle(isCompletedInCycle ? Color.uplift.up : Color.uplift.fgDim)
                        .frame(width: 18, alignment: .center)
                        .accessibilityHidden(true)
                }

                DayChip(dayType: dayType, size: .md)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(dayType.rawValue)
                            .font(.uplift.display(19, weight: .semibold))
                            .kerning(-0.3)
                            .foregroundStyle(Color.uplift.fg)
                        if isCompletedInCycle {
                            Text("Done")
                                .font(.uplift.text(10, weight: .bold))
                                .foregroundStyle(Color.uplift.up)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.uplift.up.opacity(0.16)))
                        }
                    }
                    subtitle
                    if let inProgressCount {
                        Text("\(inProgressCount) exercise\(inProgressCount == 1 ? "" : "s") in progress")
                            .font(.uplift.text(11, weight: .semibold))
                            .foregroundStyle(Color.uplift.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.uplift.accentSoft))
                            .padding(.top, 4)
                    }
                }

                Spacer(minLength: 8)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.uplift.accent)
                } else if isCompletedInCycle {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.uplift.up.opacity(0.55))
                } else {
                    Circle()
                        .strokeBorder(Color.uplift.fgFaint, lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.uplift.surface1)
                    if isSelected {
                        // top-right radial accent glow
                        RadialGradient(
                            colors: [Color.uplift.accent.opacity(0.15), .clear],
                            center: .topTrailing, startRadius: 0, endRadius: 140
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(isSelected ? Color.uplift.accent : .clear, lineWidth: 1.5)
            }
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var subtitle: some View {
        // muscles in text face; duration suffix in mono, per the design
        var text = Text(dayType.subtitle)
            .font(.uplift.text(12, weight: .medium))
        if let lastDuration {
            text = text
                + Text(" · ").font(.uplift.text(12, weight: .medium))
                + Text("\(lastDuration) last time").font(.uplift.mono(12, weight: .medium))
        }
        return text
            .foregroundStyle(Color.uplift.fgMuted)
            .lineLimit(2)
    }

    private var accessibilityText: String {
        var parts: [String] = []
        if let weekPosition { parts.append("day \(weekPosition) of week") }
        parts.append(dayType.rawValue)
        parts.append(dayType.subtitle)
        if let lastDuration { parts.append("\(lastDuration) last time") }
        if isCompletedInCycle { parts.append("done this week") }
        if let inProgressCount {
            let plural = inProgressCount == 1 ? "" : "s"
            parts.append("\(inProgressCount) exercise\(plural) in progress")
        }
        return parts.joined(separator: ", ")
    }
}

#Preview("DayPickerCard") {
    VStack(spacing: 8) {
        DayPickerCard(dayType: .arms, lastDuration: "47 min", isSelected: false, inProgressCount: nil) {}
        DayPickerCard(dayType: .legs, lastDuration: "52 min", isSelected: true, inProgressCount: nil) {}
        DayPickerCard(dayType: .fullBody, lastDuration: nil, isSelected: false, inProgressCount: 3) {}
    }
    .padding(20)
    .background(Color.uplift.bgElev)
    .preferredColorScheme(.dark)
}
