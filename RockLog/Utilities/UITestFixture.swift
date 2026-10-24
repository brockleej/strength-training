//
//  UITestFixture.swift
//  RockLog
//
//  Synthetic stores for the four UI-test presets. Every lift name starts
//  with "UI " so it cannot be mistaken for a logged workout. No CSV and
//  no backup JSON is read here.
//

import Foundation
import SwiftData

#if DEBUG
enum UITestFixture {
    static let benchName = "UI Bench Press"
    static let freshName = "UI Fresh Lift"
    static let rowName = "UI Row"
    static let squatName = "UI Squat"
    static let blockName = "UI Block"

    static func seed(_ preset: UITestPreset, context: ModelContext) {
        switch preset {
        case .empty:
            // Match a real first launch: stock catalog is in the library,
            // no split and no workouts, so the picker can pin starters.
            SeedData.seedIfNeeded(context: context, allowEmptyCatalogSeed: true)
        case .typical:
            seedSplit(context: context)
            let lifts = seedLifts(context: context)
            seedCompletedHistory(context: context, lifts: lifts, sessionCount: 2)
        case .longHistory:
            seedSplit(context: context)
            let lifts = seedLifts(context: context)
            seedCompletedHistory(context: context, lifts: lifts, sessionCount: 36)
        case .planWaiting:
            seedSplit(context: context)
            let lifts = seedLifts(context: context)
            seedCompletedHistory(context: context, lifts: lifts, sessionCount: 2)
            seedWaitingPlan(context: context, lifts: lifts)
        }
        try? context.save()
    }

    // MARK: - Split and library

    private static func seedSplit(context: ModelContext) {
        let days: [(String, Int)] = [("Push", 0), ("Pull", 1), ("Legs", 2)]
        for (name, order) in days {
            context.insert(SplitDay(
                name: name,
                systemImage: "dumbbell.fill",
                subtitle: "Synthetic",
                colorHex: 0x3F9CFF,
                sortOrder: order
            ))
        }
    }

    private struct Lifts {
        let bench: Exercise
        let fresh: Exercise
        let row: Exercise
        let squat: Exercise
    }

    private static func seedLifts(context: ModelContext) -> Lifts {
        let bench = Exercise(name: benchName, dayType: .push, muscleGroup: "Chest", sortOrder: 0, isCustom: true)
        let fresh = Exercise(name: freshName, dayType: .push, muscleGroup: "Chest", sortOrder: 1, isCustom: true)
        let row = Exercise(name: rowName, dayType: .pull, muscleGroup: "Back", sortOrder: 2, isCustom: true)
        let squat = Exercise(name: squatName, dayType: .legs, muscleGroup: "Quads", sortOrder: 3, isCustom: true)
        for exercise in [bench, fresh, row, squat] {
            context.insert(exercise)
        }
        return Lifts(bench: bench, fresh: fresh, row: row, squat: squat)
    }

    /// Newest completed session is Legs, so rolling Today suggests Push.
    private static func seedCompletedHistory(context: ModelContext, lifts: Lifts, sessionCount: Int) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let cycle: [(DayType, Exercise)] = [
            (.push, lifts.bench),
            (.pull, lifts.row),
            (.legs, lifts.squat),
        ]
        let count = max(1, sessionCount)
        for offset in 1...count {
            let date = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            // offset 1 → Legs (index 2), so the next rolling day is Push.
            let slot = cycle[(offset + 1) % cycle.count]
            let session = WorkoutSession(dayType: slot.0, date: date, rotationTrack: .a)
            session.isCompleted = true
            session.durationSeconds = 40 * 60
            context.insert(session)

            let record = ExerciseRecord(trainingMode: .highWeightLowReps, sortOrder: 0)
            record.exercise = slot.1
            record.session = session
            context.insert(record)
            session.exerciseRecords = [record]

            let setCount = sessionCount > 4 ? 3 : 1
            var sets: [SetRecord] = []
            for number in 1...setCount {
                let set = SetRecord(
                    setNumber: number,
                    weightLbs: 100 + Double(number - 1) * 5,
                    reps: 5
                )
                set.completedAt = date.addingTimeInterval(Double(number) * 60)
                set.exerciseRecord = record
                context.insert(set)
                sets.append(set)
            }
            record.sets = sets
        }
    }

    private static func seedWaitingPlan(context: ModelContext, lifts: Lifts) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let block = TrainingBlock(name: blockName, startDate: today, notes: "Synthetic queue")
        context.insert(block)

        let planned: [(Int, DayType, Exercise, Double)] = [
            (0, .push, lifts.bench, 0),
            (1, .pull, lifts.row, 10_000),
        ]
        var sessions: [WorkoutSession] = []
        for (order, day, exercise, weight) in planned {
            let date = calendar.date(byAdding: .day, value: -(7 + order), to: today) ?? today
            let session = WorkoutSession(dayType: day, date: date, rotationTrack: .a)
            session.isCompleted = false
            session.planStatus = .planned
            session.planOrder = order
            session.followsSessionRoster = true
            session.trainingBlock = block
            context.insert(session)

            let record = ExerciseRecord(trainingMode: .highWeightLowReps, sortOrder: 0)
            record.exercise = exercise
            record.session = session
            context.insert(record)
            session.exerciseRecords = [record]

            let set = SetRecord(setNumber: 1, weightLbs: weight, reps: 5, isTarget: true)
            set.completedAt = date
            set.exerciseRecord = record
            context.insert(set)
            record.sets = [set]
            sessions.append(session)
        }
        block.sessions = sessions
    }
}
#endif
