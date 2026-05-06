import SwiftUI

/// Compact row showing the most recent completed workout: chip + summary + optional PR badge + chevron.
/// Tap handling lives at the call site (TodayView wraps it in a NavigationLink).
struct YesterdayCard: View {
    let dayType: DayType
    let durationLabel: String   // "47 min" / "1h 15m"
    let totalVolume: Int
    let totalSets: Int
    let prCount: Int            // 0 → no badge

    var body: some View {
        HStack(spacing: 12) {
            DayChip(dayType: dayType, size: .sm)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("\(dayType.rawValue) · \(durationLabel)")
                        .font(.uplift.text(15, weight: .semibold))
                        .kerning(-0.2)
                        .foregroundStyle(Color.uplift.fg)
                }
                HStack(spacing: 6) {
                    Num(totalVolume.formatted(.number), size: 12)
                        .foregroundStyle(Color.uplift.fgMuted)
                    Text("lb")
                        .font(.uplift.text(12, weight: .medium))
                        .foregroundStyle(Color.uplift.fgMuted)
                    Text("·")
                        .font(.uplift.text(12, weight: .medium))
                        .foregroundStyle(Color.uplift.fgMuted)
                    Num(totalSets, size: 12)
                        .foregroundStyle(Color.uplift.fgMuted)
                    Text("sets")
                        .font(.uplift.text(12, weight: .medium))
                        .foregroundStyle(Color.uplift.fgMuted)
                }
            }

            Spacer(minLength: 6)

            if prCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.uplift.pr)
                    Num(prCount, size: 12, color: .uplift.pr)
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.uplift.fgDim)
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.uplift.surface1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview("YesterdayCard — variants") {
    VStack(spacing: 12) {
        YesterdayCard(dayType: .arms,     durationLabel: "47 min",  totalVolume: 12_840, totalSets: 19, prCount: 0)
        YesterdayCard(dayType: .legs,     durationLabel: "52 min",  totalVolume: 15_420, totalSets: 22, prCount: 2)
        YesterdayCard(dayType: .fullBody, durationLabel: "1h 15m",  totalVolume: 28_100, totalSets: 31, prCount: 1)
    }
    .padding(20)
    .background(Color.uplift.bgElev)
}
