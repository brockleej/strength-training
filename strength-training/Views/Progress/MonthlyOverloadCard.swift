//
//  MonthlyOverloadCard.swift
//  strength-training
//
//  Progress-tab month-over-month best-set recap. Visual language matches
//  PRsThisMonthCard (surface1, 18pt continuous corners, muted eyebrow).
//

import SwiftUI
import SwiftData

struct MonthlyOverloadCard: View {
    let review: MonthlyOverload.Review
    let exercises: [Exercise]
    let modelContext: ModelContext

    @State private var selectedExerciseID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if review.isEmpty {
                emptyState
            } else {
                workoutCounts
                columnHeaders
                ForEach(review.groups) { group in
                    dayHeader(group.dayTypeName)
                    ForEach(group.rows) { row in
                        liftRow(row)
                    }
                }
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.uplift.surface1)
        }
        .navigationDestination(item: $selectedExerciseID) { id in
            if let exercise = exercises.first(where: { $0.id == id }) {
                ExerciseDrillDownView(exercise: exercise, modelContext: modelContext)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Monthly overload")
                .textCase(.uppercase)
                .font(.uplift.text(11, weight: .semibold))
                .tracking(0.4)
                .foregroundStyle(Color.uplift.fgMuted)
            Spacer()
            if !review.thisMonthLabel.isEmpty {
                Text("\(review.thisMonthLabel) vs \(review.lastMonthLabel)")
                    .font(.uplift.text(12, weight: .medium))
                    .foregroundStyle(Color.uplift.fgDim)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var emptyState: some View {
        Text("Log working sets this month or last to see each lift’s best set versus last month.")
            .font(.uplift.text(13, weight: .medium))
            .foregroundStyle(Color.uplift.fgDim)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var workoutCounts: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text("\(review.thisMonthWorkoutCount) workout\(review.thisMonthWorkoutCount == 1 ? "" : "s") this month")
                .font(.uplift.text(12, weight: .medium))
                .foregroundStyle(Color.uplift.fgMuted)
            Text("·")
                .foregroundStyle(Color.uplift.fgFaint)
            Text("\(review.lastMonthWorkoutCount) last")
                .font(.uplift.text(12, weight: .medium))
                .foregroundStyle(Color.uplift.fgDim)
            Spacer(minLength: 0)
        }
    }

    private var columnHeaders: some View {
        HStack(spacing: 8) {
            Text("Lift")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(review.lastMonthLabel)
                .frame(width: 62, alignment: .trailing)
            Text(review.thisMonthLabel)
                .frame(width: 62, alignment: .trailing)
            Text("Δ")
                .frame(width: 58, alignment: .trailing)
        }
        .textCase(.uppercase)
        .font(.uplift.text(10, weight: .semibold))
        .tracking(0.3)
        .foregroundStyle(Color.uplift.fgDim)
        .padding(.top, 2)
        .accessibilityHidden(true)
    }

    // MARK: - Rows

    private func dayHeader(_ name: String) -> some View {
        let day = DayType(rawValue: name)
        return Text(name)
            .textCase(.uppercase)
            .font(.uplift.text(11, weight: .semibold))
            .tracking(0.3)
            .foregroundStyle(day.upliftInk)
            .padding(.top, 8)
            .accessibilityAddTraits(.isHeader)
            .accessibilityLabel(name)
    }

    private func liftRow(_ row: MonthlyOverload.Row) -> some View {
        Button {
            selectedExerciseID = row.exerciseID
        } label: {
            HStack(spacing: 8) {
                Text(row.exerciseName)
                    .font(.uplift.text(14, weight: .medium))
                    .foregroundStyle(Color.uplift.fg)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, alignment: .leading)

                setCell(row.lastMonth)
                setCell(row.thisMonth)
                deltaCell(row)
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rowAccessibility(row))
        .accessibilityHint("Opens lift history")
    }

    private func setCell(_ set: MonthlyOverload.WorkingSet?) -> some View {
        Text(set?.formatted ?? "—")
            .font(.uplift.mono(12, weight: .semibold))
            .foregroundStyle(set == nil ? Color.uplift.fgDim : Color.uplift.fg)
            .frame(width: 62, alignment: .trailing)
    }

    private func deltaCell(_ row: MonthlyOverload.Row) -> some View {
        Text(row.deltaLabel)
            .font(.uplift.mono(12, weight: .semibold))
            .foregroundStyle(deltaColor(row.comparison))
            .frame(width: 58, alignment: .trailing)
    }

    private func deltaColor(_ comparison: MonthlyOverload.Comparison) -> Color {
        switch comparison {
        case .up: Color.uplift.up
        case .down: Color.uplift.down
        case .flat: Color.uplift.flat
        case .new: Color.uplift.accent
        case .missing: Color.uplift.fgDim
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

#Preview("Monthly overload") {
    let bench = UUID()
    let ohp = UUID()
    let squat = UUID()
    let review = MonthlyOverload.Review(
        thisMonthLabel: "Aug",
        lastMonthLabel: "Jul",
        thisMonthWorkoutCount: 12,
        lastMonthWorkoutCount: 10,
        groups: [
            .init(dayTypeName: "Push", rows: [
                .init(
                    exerciseID: bench,
                    exerciseName: "Bench Press",
                    dayTypeName: "Push",
                    sortOrder: 0,
                    thisMonth: .init(weightLbs: 230, reps: 5),
                    lastMonth: .init(weightLbs: 225, reps: 5),
                    comparison: .up,
                    deltaLabel: "+5 lb"
                ),
                .init(
                    exerciseID: ohp,
                    exerciseName: "Overhead Press",
                    dayTypeName: "Push",
                    sortOrder: 1,
                    thisMonth: .init(weightLbs: 135, reps: 8),
                    lastMonth: nil,
                    comparison: .new,
                    deltaLabel: "New"
                ),
            ]),
            .init(dayTypeName: "Legs", rows: [
                .init(
                    exerciseID: squat,
                    exerciseName: "Squat",
                    dayTypeName: "Legs",
                    sortOrder: 0,
                    thisMonth: .init(weightLbs: 315, reps: 5),
                    lastMonth: .init(weightLbs: 315, reps: 5),
                    comparison: .flat,
                    deltaLabel: "="
                ),
            ]),
        ]
    )

    ScrollView {
        MonthlyOverloadCard(
            review: review,
            exercises: [],
            modelContext: previewContainer.mainContext
        )
        .padding(20)
    }
    .background(Color.uplift.bgElev)
    .preferredColorScheme(.dark)
}
