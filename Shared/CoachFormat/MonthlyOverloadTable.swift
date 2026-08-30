//
//  MonthlyOverloadTable.swift
//  Shared recap layout for RockLog Progress and RockCoach.
//  Palette is supplied by each app so tokens stay local.
//

import SwiftUI

struct MonthlyOverloadPalette {
    var nest: Color
    var foreground: Color
    var muted: Color
    var dim: Color
    var faint: Color
    var accent: Color
    var up: Color
    var down: Color
    var flat: Color
    var hairline: Color
    var dayInk: (String) -> Color
}

struct MonthlyOverloadTable: View {
    let review: MonthlyOverload.Review
    var palette: MonthlyOverloadPalette
    var emptyMessage: String
    var onSelect: ((MonthlyOverload.Row) -> Void)?
    var selectionHint: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if review.isEmpty {
                emptyState
            } else {
                workoutCounts
                ForEach(review.groups) { group in
                    groupBlock(group)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("Monthly overload")
                .textCase(.uppercase)
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.4)
                .foregroundStyle(palette.muted)
            Spacer(minLength: 8)
            if !review.thisMonthLabel.isEmpty {
                Text("\(review.thisMonthLabel) vs \(review.lastMonthLabel)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(palette.dim)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var emptyState: some View {
        Text(emptyMessage)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(palette.dim)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var workoutCounts: some View {
        HStack(spacing: 10) {
            countTile(value: review.thisMonthWorkoutCount, caption: "This month")
            countTile(value: review.lastMonthWorkoutCount, caption: "Last month")
        }
    }

    private func countTile(value: Int, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(value)")
                .font(.system(size: 26, weight: .bold, design: .monospaced))
                .foregroundStyle(palette.foreground)
                .monospacedDigit()
            Text(caption)
                .textCase(.uppercase)
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.3)
                .foregroundStyle(palette.dim)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(palette.nest)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(caption): \(value) workout\(value == 1 ? "" : "s")")
    }

    // MARK: - Groups / rows

    private func groupBlock(_ group: MonthlyOverload.Group) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(group.dayTypeName)
                .textCase(.uppercase)
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.35)
                .foregroundStyle(palette.dayInk(group.dayTypeName))
                .padding(.bottom, 6)
                .accessibilityAddTraits(.isHeader)

            ForEach(Array(group.rows.enumerated()), id: \.element.id) { index, row in
                rowContent(row)
                if index < group.rows.count - 1 {
                    Rectangle()
                        .fill(palette.hairline)
                        .frame(height: 1)
                }
            }
        }
        .padding(.top, 2)
    }

    @ViewBuilder
    private func rowContent(_ row: MonthlyOverload.Row) -> some View {
        if let onSelect {
            Button {
                onSelect(row)
            } label: {
                rowLabel(row)
            }
            .buttonStyle(.plain)
            .accessibilityHint(selectionHint ?? "Opens lift history")
        } else {
            rowLabel(row)
        }
    }

    private func rowLabel(_ row: MonthlyOverload.Row) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(row.exerciseName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.foreground)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 7) {
                    Text(row.lastMonth?.formatted ?? "—")
                        .foregroundStyle(row.lastMonth == nil ? palette.dim : palette.muted)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(palette.faint)
                    Text(row.thisMonth?.formatted ?? "—")
                        .foregroundStyle(row.thisMonth == nil ? palette.dim : palette.foreground)
                }
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .monospacedDigit()
            }

            Spacer(minLength: 8)

            Text(row.deltaLabel)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(deltaColor(row.comparison))
                .lineLimit(1)
                .layoutPriority(1)
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rowAccessibility(row))
    }

    private func deltaColor(_ comparison: MonthlyOverload.Comparison) -> Color {
        switch comparison {
        case .up: palette.up
        case .down: palette.down
        case .flat: palette.flat
        case .new: palette.accent
        case .missing: palette.dim
        }
    }

    private func rowAccessibility(_ row: MonthlyOverload.Row) -> String {
        let last = row.lastMonth.map { "\($0.formatted) last month" } ?? "no set last month"
        let current = row.thisMonth.map { "\($0.formatted) this month" } ?? "no set this month"
        return "\(row.exerciseName), \(last), \(current), \(row.deltaLabel)"
    }

    private var accessibilitySummary: String {
        if review.isEmpty {
            return "Monthly overload. Not enough history yet."
        }
        return "Monthly overload, \(review.thisMonthLabel) versus \(review.lastMonthLabel). \(review.thisMonthWorkoutCount) workouts this month, \(review.lastMonthWorkoutCount) last month. \(review.rows.count) lifts."
    }
}
