//
//  ThisWeekCard.swift
//  strength-training
//

import SwiftUI

/// Current-week stats: big session count, volume · sets line, Mon–Sun grid.
/// No goal/target framing (deliberate scope decision).
struct ThisWeekCard: View {
    let sessionCount: Int
    let volumeText: String   // "38,460"
    let setCount: Int
    let cells: [TodayStats.WeekDayCell]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Num(sessionCount, size: 32)
                    Text("session\(sessionCount == 1 ? "" : "s")")
                        .font(.uplift.text(16, weight: .medium))
                        .foregroundStyle(Color.uplift.fgMuted)
                }
                (
                    Text("\(volumeText) lb").font(.uplift.mono(12, weight: .medium))
                    + Text(" · ").font(.uplift.text(12, weight: .medium))
                    + Text("\(setCount) sets").font(.uplift.text(12, weight: .medium))
                )
                .foregroundStyle(Color.uplift.fgMuted)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(statsAccessibilityLabel)

            HStack(spacing: 6) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                    VStack(spacing: 4) {
                        Text(cell.letter)
                            .font(.uplift.text(10, weight: .semibold))
                            .tracking(0.4)
                            .foregroundStyle(cell.isToday ? Color.uplift.accent : Color.uplift.fgDim)
                        cellBody(cell)
                            .frame(maxWidth: .infinity)
                            .frame(height: 28)
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(weekAccessibilityLabel)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.uplift.surface1)
        }
    }

    @ViewBuilder
    private func cellBody(_ cell: TodayStats.WeekDayCell) -> some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        ZStack {
            if let trained = cell.trained {
                shape.fill(trained.upliftInk)
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            } else if !cell.isToday {
                shape.strokeBorder(Color.uplift.fgFaint, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
            if cell.isToday {
                shape.strokeBorder(Color.uplift.accent, lineWidth: 1.5)
                if cell.trained == nil {
                    Circle().fill(Color.uplift.accent).frame(width: 4, height: 4)
                }
            }
        }
    }

    private var statsAccessibilityLabel: String {
        let plural = sessionCount == 1 ? "" : "s"
        return "\(sessionCount) session\(plural) this week, \(volumeText) pounds, \(setCount) sets"
    }

    private var weekAccessibilityLabel: String {
        let dayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        let trained = zip(dayNames, cells)
            .compactMap { name, cell in cell.trained.map { "\(name): \($0.rawValue)" } }
        return trained.isEmpty ? "No sessions yet this week" : trained.joined(separator: ", ")
    }
}

#Preview("ThisWeekCard") {
    ThisWeekCard(
        sessionCount: 3,
        volumeText: "38,460",
        setCount: 56,
        cells: [
            .init(letter: "M", trained: .arms, isToday: false),
            .init(letter: "T", trained: nil, isToday: false),
            .init(letter: "W", trained: .legs, isToday: true),
            .init(letter: "T", trained: nil, isToday: false),
            .init(letter: "F", trained: .arms, isToday: false),
            .init(letter: "S", trained: .arms, isToday: false),
            .init(letter: "S", trained: nil, isToday: false),
        ]
    )
    .padding(20)
    .background(Color.uplift.bgElev)
    .preferredColorScheme(.dark)
}
