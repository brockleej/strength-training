import SwiftUI

/// 7-day Mon-Sun grid showing which days had workouts and which day type.
/// Filled pill = workout completed (color = day type). Dashed pill = rest / future.
/// Today: accent 1.5pt border + small accent dot.
struct WeekDayGrid: View {
    /// Map of weekday index (0=Mon ... 6=Sun) → day type completed that day.
    let dayTypes: [Int: DayType]
    /// Index 0–6 of "today" within Mon-Sun. Used to highlight current day's pill.
    let todayIndex: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { idx in
                pill(at: idx)
            }
        }
    }

    private func pill(at idx: Int) -> some View {
        VStack(spacing: 4) {
            Text(weekdayLetter(at: idx))
                .font(.uplift.text(10, weight: .semibold))
                .tracking(0.4)
                .foregroundStyle(idx == todayIndex ? Color.uplift.accent : Color.uplift.fgDim)

            ZStack {
                if let dayType = dayTypes[idx] {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(dayTypeInk(dayType))
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(
                            Color.uplift.fgFaint,
                            style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                        )
                }

                if idx == todayIndex {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.uplift.accent, lineWidth: 1.5)
                    Circle()
                        .fill(Color.uplift.accent)
                        .frame(width: 4, height: 4)
                }
            }
            .frame(height: 28)
            .frame(maxWidth: .infinity)
        }
    }

    private func weekdayLetter(at idx: Int) -> String {
        ["M", "T", "W", "T", "F", "S", "S"][idx]
    }

    private func dayTypeInk(_ dayType: DayType) -> Color {
        switch dayType {
        case .arms:     .uplift.armsInk
        case .legs:     .uplift.legsInk
        case .fullBody: .uplift.fullInk
        }
    }
}

#Preview("WeekDayGrid") {
    VStack(spacing: 24) {
        // Wed is today, Mon = arms, Wed = legs (in-progress today), Fri = arms, Sat = full
        WeekDayGrid(
            dayTypes: [0: .arms, 4: .arms, 5: .fullBody],
            todayIndex: 2
        )
        // Empty week (no workouts yet, today = Tue)
        WeekDayGrid(dayTypes: [:], todayIndex: 1)
    }
    .padding(20)
    .background(Color.uplift.bgElev)
}
