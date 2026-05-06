import SwiftUI

/// One of the 3 day-type cards on TodayView's day picker. Renders DayChip + title +
/// subtitle ("N lifts · last session 47 min") + selection indicator. Selected card
/// has an accent border + a radial accent glow in the top-right corner.
///
/// Tap handling lives at the call site (`TodayView`) — this view is pure visual.
struct DayPickerCard: View {
    let dayType: DayType
    let subtitle: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 14) {
            DayChip(dayType: dayType, size: .md)
            VStack(alignment: .leading, spacing: 2) {
                Text(dayType.cardTitle)
                    .font(.uplift.display(19, weight: .semibold))
                    .kerning(-0.3)
                    .foregroundStyle(Color.uplift.fg)
                Text(subtitle)
                    .font(.uplift.text(12, weight: .medium))
                    .foregroundStyle(Color.uplift.fgMuted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.uplift.accent)
            } else {
                Circle()
                    .strokeBorder(Color.uplift.fgFaint, lineWidth: 1.5)
                    .frame(width: 22, height: 22)
            }
        }
        .padding(14)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.uplift.surface1)
                if isSelected {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [Color.uplift.accent.opacity(0.15), .clear],
                                center: .topTrailing,
                                startRadius: 0,
                                endRadius: 140
                            )
                        )
                }
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(isSelected ? Color.uplift.accent : .clear, lineWidth: 1.5)
        }
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

private extension DayType {
    /// Display title on the picker card. "Full body" is title-cased to match the design
    /// (existing `DayType.rawValue` is "Full Body" — adjust if it differs).
    var cardTitle: String {
        switch self {
        case .arms:     "Arms"
        case .legs:     "Legs"
        case .fullBody: "Full body"
        }
    }
}

#Preview("DayPickerCard — selected + unselected") {
    VStack(spacing: 8) {
        DayPickerCard(dayType: .arms, subtitle: "10 lifts · last session 47 min", isSelected: false)
        DayPickerCard(dayType: .legs, subtitle: "7 lifts · last session 52 min", isSelected: true)
        DayPickerCard(dayType: .fullBody, subtitle: "17 lifts · no history", isSelected: false)
    }
    .padding(20)
    .background(Color.uplift.bgElev)
}
