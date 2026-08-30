//
//  PlannedWorkoutsCard.swift
//  strength-training
//
//  Upcoming imported plan days. Testers should see today’s planned workout here.
//

import SwiftUI

struct PlannedWorkoutsCard: View {
    let blockName: String
    let rows: [Row]

    struct Row: Identifiable {
        let id: UUID
        let date: Date
        let dayType: DayType
        let liftCount: Int
        let isToday: Bool
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !blockName.isEmpty {
                Text(blockName)
                    .font(.uplift.text(13, weight: .semibold))
                    .foregroundStyle(Color.uplift.fgMuted)
            }
            ForEach(rows) { row in
                HStack(spacing: 12) {
                    DayChip(dayType: row.dayType, size: .sm)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            Text(row.dayType.rawValue)
                                .font(.uplift.text(15, weight: .semibold))
                                .kerning(-0.2)
                                .foregroundStyle(Color.uplift.fg)
                            if row.isToday {
                                Text("Today")
                                    .font(.uplift.text(10, weight: .bold))
                                    .foregroundStyle(Color.uplift.accent)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.uplift.accent.opacity(0.16)))
                            }
                        }
                        Text(secondaryLine(for: row))
                            .font(.uplift.text(12, weight: .medium))
                            .foregroundStyle(Color.uplift.fgMuted)
                    }
                    Spacer(minLength: 8)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.uplift.surface1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private func secondaryLine(for row: Row) -> String {
        let when = row.isToday
            ? "Planned for today"
            : row.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        let lifts = row.liftCount == 1 ? "1 lift" : "\(row.liftCount) lifts"
        return "\(when) · \(lifts)"
    }

    private var accessibilityText: String {
        let names = rows.map { row in
            let when = row.isToday
                ? "today"
                : row.date.formatted(.dateTime.weekday(.wide).month(.wide).day())
            return "\(row.dayType.rawValue) \(when)"
        }
        return "Upcoming planned workouts: \(names.joined(separator: ", "))"
    }
}

#Preview("PlannedWorkoutsCard") {
    PlannedWorkoutsCard(
        blockName: "Demo 8-Week Strength Block",
        rows: [
            .init(id: UUID(), date: .now, dayType: .push, liftCount: 3, isToday: true),
            .init(id: UUID(), date: .now.addingTimeInterval(172_800), dayType: .pull, liftCount: 3, isToday: false),
        ]
    )
    .padding(20)
    .background(Color.uplift.bgElev)
    .preferredColorScheme(.dark)
    .modelContainer(previewContainer)
}
