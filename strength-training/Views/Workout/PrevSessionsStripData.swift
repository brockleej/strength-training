//
//  PrevSessionsStripData.swift
//  strength-training
//
//  Pure shaping for the Focus screen's history strip. Chronological order
//  (oldest first) — the strip renders left→right with the most recent
//  session right-most and initial scroll anchored trailing.
//

import Foundation

enum PrevSessionsStripData {

    struct SetPair: Equatable {
        let weight: Double
        let reps: Int
    }

    /// One prior session's working sets, pre-sorted by set number.
    struct SessionSets {
        let id: UUID
        let date: Date
        let sets: [SetPair]
    }

    struct Run: Equatable {
        let weight: Double
        let reps: [Int]
    }

    struct Entry: Identifiable, Equatable {
        let id: UUID          // session/record id
        let dateLabel: String // "3 wk ago" — rendered uppercase by the card
        let runs: [Run]       // one run per consecutive same-weight streak

        /// "20 pounds by 15, 9 reps" style a11y string, one clause per run.
        var linesAccessibility: String {
            runs
                .map { run in
                    let reps = run.reps.map(String.init).joined(separator: ", ")
                    return "\(StepperLogic.format(run.weight)) pounds by \(reps) reps"
                }
                .joined(separator: ", ")
        }
    }

    /// Oldest-first entries, capped to the 10 most recent non-empty sessions.
    static func entries(
        from sessions: [SessionSets],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [Entry] {
        sessions
            .filter { !$0.sets.isEmpty }
            .suffix(10)
            .map { session in
                Entry(
                    id: session.id,
                    dateLabel: relativeLabel(for: session.date, now: now, calendar: calendar),
                    runs: runs(for: session.sets)
                )
            }
    }

    /// One run per consecutive same-weight streak, preserving set order.
    static func runs(for sets: [SetPair]) -> [Run] {
        var result: [Run] = []
        var runWeight: Double?
        var runReps: [Int] = []

        func flush() {
            guard let weight = runWeight, !runReps.isEmpty else { return }
            result.append(Run(weight: weight, reps: runReps))
        }

        for set in sets {
            if set.weight == runWeight {
                runReps.append(set.reps)
            } else {
                flush()
                runWeight = set.weight
                runReps = [set.reps]
            }
        }
        flush()
        return result
    }

    /// Compact relative label: Today / Yesterday / N days ago / N wk ago / N mo ago.
    static func relativeLabel(for date: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        let start = calendar.startOfDay(for: date)
        let end = calendar.startOfDay(for: now)
        let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        switch days {
        case ..<1: return "Today"
        case 1: return "Yesterday"
        case 2...6: return "\(days) days ago"
        case 7...55: return "\(days / 7) wk ago"
        default: return "\(days / 30) mo ago"
        }
    }
}
