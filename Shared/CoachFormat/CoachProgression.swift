//
//  CoachProgression.swift
//  Shared by RockCoach (and tests). Compares raw working sets — no tonnage.
//

import Foundation

nonisolated enum CoachProgression {
    enum Direction: String, Equatable {
        case up
        case down
        case same
        case new
    }

    struct Snapshot: Equatable, Identifiable {
        var name: String
        var current: CoachSetPayload?
        var previous: CoachSetPayload?
        var direction: Direction

        var id: String { name }
    }

    /// Best working set: highest weight, then higher reps. Warm-ups ignored.
    nonisolated static func bestWorkingSet(in exercise: CoachExercisePayload) -> CoachSetPayload? {
        exercise.sets
            .filter { !$0.resolvedWarmup }
            .max { lhs, rhs in
                if lhs.weightLbs != rhs.weightLbs {
                    return lhs.weightLbs < rhs.weightLbs
                }
                return lhs.reps < rhs.reps
            }
    }

    nonisolated static func direction(from previous: CoachSetPayload?, to current: CoachSetPayload?) -> Direction {
        guard let current else { return previous == nil ? .new : .down }
        guard let previous else { return .new }
        if current.weightLbs > previous.weightLbs { return .up }
        if current.weightLbs < previous.weightLbs { return .down }
        if current.reps > previous.reps { return .up }
        if current.reps < previous.reps { return .down }
        return .same
    }

    /// Latest session versus the most recent earlier session that logged the same lift.
    nonisolated static func snapshots(current: CoachSessionDocument, history: [CoachSessionDocument]) -> [Snapshot] {
        let prior = history
            .filter { $0.session.id != current.session.id }
            .sorted { $0.session.startedAt > $1.session.startedAt }

        return current.session.exercises.compactMap { exercise in
            let now = bestWorkingSet(in: exercise)
            guard now != nil || !exercise.sets.isEmpty else { return nil }
            let earlier = prior
                .compactMap { doc in
                    doc.session.exercises.first { $0.name.caseInsensitiveCompare(exercise.name) == .orderedSame }
                }
                .first
            let before = earlier.flatMap { bestWorkingSet(in: $0) }
            return Snapshot(
                name: exercise.name,
                current: now,
                previous: before,
                direction: direction(from: before, to: now)
            )
        }
    }

    struct SessionColumn: Equatable, Identifiable {
        var id: UUID
        var startedAt: Date
        var dayType: String
        var rotationTrack: String?
        var effortRating: Int?
    }

    struct CompareCell: Equatable {
        var workingSets: [CoachSetPayload]
        var best: CoachSetPayload?
        var direction: Direction
    }

    struct LiftRow: Equatable, Identifiable {
        var name: String
        var cells: [CompareCell]
        var id: String { name }
    }

    struct CompareGrid: Equatable {
        var columns: [SessionColumn]
        var rows: [LiftRow]
    }

    /// Oldest → newest columns (left to right). Sessions should already be the same day type.
    nonisolated static func compareGrid(from documents: [CoachSessionDocument], limit: Int = 4) -> CompareGrid {
        let newestFirst = documents.sorted { $0.session.startedAt > $1.session.startedAt }
        let window = Array(newestFirst.prefix(max(1, limit))).reversed()
        let columns = window.map { doc in
            SessionColumn(
                id: doc.session.id,
                startedAt: doc.session.startedAt,
                dayType: doc.session.dayType,
                rotationTrack: doc.session.rotationTrack,
                effortRating: doc.session.effortRating
            )
        }

        var names: [String] = []
        var seen = Set<String>()
        for doc in window.reversed() {
            for exercise in doc.session.exercises {
                let key = exercise.name.lowercased()
                if seen.insert(key).inserted {
                    names.append(exercise.name)
                }
            }
        }

        let rows: [LiftRow] = names.map { name in
            var cells: [CompareCell] = []
            var previousBest: CoachSetPayload?
            for doc in window {
                let exercise = doc.session.exercises.first {
                    $0.name.caseInsensitiveCompare(name) == .orderedSame
                }
                let working = (exercise?.sets ?? [])
                    .filter { !$0.resolvedWarmup }
                    .sorted { $0.setNumber < $1.setNumber }
                let best = exercise.flatMap(bestWorkingSet(in:))
                cells.append(
                    CompareCell(
                        workingSets: working,
                        best: best,
                        direction: direction(from: previousBest, to: best)
                    )
                )
                if best != nil { previousBest = best }
            }
            return LiftRow(name: name, cells: cells)
        }

        return CompareGrid(columns: columns, rows: rows)
    }

    nonisolated static func setLabel(_ set: CoachSetPayload) -> String {
        let weight: String
        if set.resolvedAssisted {
            weight = "−\(trimmed(set.weightLbs))"
        } else {
            weight = trimmed(set.weightLbs)
        }
        var suffix = ""
        if set.resolvedEachSide { suffix += " ea" }
        return "\(weight)×\(set.reps)\(suffix)"
    }

    nonisolated private static func trimmed(_ value: Double) -> String {
        if value.rounded() == value { return String(Int(value)) }
        return String(format: "%g", value)
    }
}
