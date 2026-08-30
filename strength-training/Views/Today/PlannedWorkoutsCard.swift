//
//  PlannedWorkoutsCard.swift
//  strength-training
//
//  Unused imported sessions as a queue. First row is next up — never “you missed Monday.”
//

import SwiftUI

struct PlannedWorkoutsCard: View {
    let blockName: String
    let rows: [Row]
    var onStartNext: (() -> Void)?

    struct Row: Identifiable {
        let id: UUID
        let dayType: DayType
        let liftCount: Int
        let isNext: Bool
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !blockName.isEmpty {
                Text(blockName)
                    .font(.uplift.text(13, weight: .semibold))
                    .foregroundStyle(Color.uplift.fgMuted)
            }
            ForEach(rows) { row in
                rowContent(row)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if row.isNext {
                            onStartNext?()
                        }
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
        .accessibilityAddTraits(onStartNext == nil ? [] : .isButton)
        .accessibilityHint(onStartNext == nil ? "" : "Starts the next unused workout")
        .accessibilityAction {
            onStartNext?()
        }
    }

    private func rowContent(_ row: Row) -> some View {
        HStack(spacing: 12) {
            DayChip(dayType: row.dayType, size: .sm)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(row.dayType.rawValue)
                        .font(.uplift.text(15, weight: .semibold))
                        .kerning(-0.2)
                        .foregroundStyle(Color.uplift.fg)
                    if row.isNext {
                        Text("Next up")
                            .font(.uplift.text(10, weight: .bold))
                            .foregroundStyle(Color.uplift.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.uplift.accent.opacity(0.16)))
                    }
                }
                Text(PlannedBlockQueue.cardSecondary(isNext: row.isNext, liftCount: row.liftCount))
                    .font(.uplift.text(12, weight: .medium))
                    .foregroundStyle(Color.uplift.fgMuted)
            }
            Spacer(minLength: 8)
        }
    }

    private var accessibilityText: String {
        let names = rows.map { row in
            row.isNext
                ? PlannedBlockQueue.nextUpLabel(dayName: row.dayType.rawValue)
                : row.dayType.rawValue
        }
        return "Unused planned workouts: \(names.joined(separator: ", "))"
    }
}

#Preview("PlannedWorkoutsCard") {
    PlannedWorkoutsCard(
        blockName: "Demo 8-Week Strength Block",
        rows: [
            .init(id: UUID(), dayType: .lower, liftCount: 6, isNext: true),
            .init(id: UUID(), dayType: .push, liftCount: 6, isNext: false),
        ]
    )
    .padding(20)
    .background(Color.uplift.bgElev)
    .preferredColorScheme(.dark)
    .modelContainer(previewContainer)
}
