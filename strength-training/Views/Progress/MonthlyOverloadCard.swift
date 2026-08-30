//
//  MonthlyOverloadCard.swift
//  strength-training
//
//  Progress-tab month-over-month best-set recap. Shared table + uplift tokens.
//

import SwiftUI
import SwiftData

struct MonthlyOverloadCard: View {
    let review: MonthlyOverload.Review
    let exercises: [Exercise]
    let modelContext: ModelContext

    @State private var selectedExerciseID: UUID?

    var body: some View {
        MonthlyOverloadTable(
            review: review,
            palette: .uplift,
            emptyMessage: "Log a working set this month or last to compare each lift’s best set.",
            onSelect: { selectedExerciseID = $0.exerciseID },
            selectionHint: "Opens lift history"
        )
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
}

extension MonthlyOverloadPalette {
    static let uplift = MonthlyOverloadPalette(
        nest: Color.uplift.surface2,
        foreground: Color.uplift.fg,
        muted: Color.uplift.fgMuted,
        dim: Color.uplift.fgDim,
        faint: Color.uplift.fgFaint,
        accent: Color.uplift.accent,
        up: Color.uplift.up,
        down: Color.uplift.down,
        flat: Color.uplift.flat,
        hairline: Color.uplift.hairline,
        dayInk: { DayType(rawValue: $0).upliftInk }
    )
}

#Preview("Monthly overload") {
    let bench = UUID()
    let ohp = UUID()
    let squat = UUID()
    let curl = UUID()
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
                    thisMonth: .init(weightLbs: 315, reps: 4),
                    lastMonth: .init(weightLbs: 315, reps: 5),
                    comparison: .down,
                    deltaLabel: "−1"
                ),
            ]),
            .init(dayTypeName: "Pull", rows: [
                .init(
                    exerciseID: curl,
                    exerciseName: "Barbell Curl",
                    dayTypeName: "Pull",
                    sortOrder: 0,
                    thisMonth: .init(weightLbs: 95, reps: 8),
                    lastMonth: .init(weightLbs: 95, reps: 8),
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
