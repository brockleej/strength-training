import SwiftUI

/// Top-of-section "This week" summary card: session count + volume/sets subtitle,
/// 7-day grid of which days had workouts, and a this-vs-last week volume comparison bar.
struct ThisWeekCard: View {
    let sessionCount: Int
    let totalVolume: Int
    let totalSets: Int
    let dayTypes: [Int: DayType]
    let todayIndex: Int
    let weeklyDelta: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            WeekDayGrid(dayTypes: dayTypes, todayIndex: todayIndex)
            WeeklyVolumeBar(thisWeekVolume: totalVolume, delta: weeklyDelta)
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.uplift.surface1)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Num(sessionCount, size: 32, weight: .bold)
                    Text(sessionCount == 1 ? "session" : "sessions")
                        .font(.uplift.text(16, weight: .medium))
                        .foregroundStyle(Color.uplift.fgMuted)
                }
                HStack(spacing: 4) {
                    Num(totalVolume.formatted(.number), size: 12)
                        .foregroundStyle(Color.uplift.fg)
                    Text("lb · \(totalSets) sets")
                        .font(.uplift.text(12, weight: .medium))
                        .foregroundStyle(Color.uplift.fgMuted)
                }
            }
            Spacer()
        }
    }
}

#Preview("ThisWeekCard") {
    VStack(spacing: 16) {
        // Realistic mid-week state
        ThisWeekCard(
            sessionCount: 3,
            totalVolume: 38_460,
            totalSets: 56,
            dayTypes: [0: .arms, 2: .legs, 4: .arms],
            todayIndex: 4,
            weeklyDelta: 0.24
        )
        // Empty week
        ThisWeekCard(
            sessionCount: 0,
            totalVolume: 0,
            totalSets: 0,
            dayTypes: [:],
            todayIndex: 1,
            weeklyDelta: nil
        )
    }
    .padding(20)
    .background(Color.uplift.bgElev)
}
