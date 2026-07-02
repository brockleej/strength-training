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

    struct Entry: Identifiable, Equatable {
        let id: UUID          // session/record id
        let dateLabel: String // "3 wk ago" — rendered uppercase by the card
        let lines: [String]   // one line per consecutive same-weight run
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
                    lines: runLines(for: session.sets)
                )
            }
    }

    /// "225 × 5 · 5" per consecutive same-weight run, preserving set order.
    static func runLines(for sets: [SetPair]) -> [String] {
        var lines: [String] = []
        var runWeight: Double?
        var runReps: [Int] = []

        func flush() {
            guard let weight = runWeight, !runReps.isEmpty else { return }
            let reps = runReps.map(String.init).joined(separator: " · ")
            lines.append("\(StepperLogic.format(weight)) × \(reps)")
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
        return lines
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
