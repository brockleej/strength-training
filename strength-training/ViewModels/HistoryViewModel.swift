//
//  HistoryViewModel.swift
//  strength-training
//
//  Created by Daniel Kuhlwein on 2026-02-21.
//

import SwiftUI
import SwiftData

@Observable
final class HistoryViewModel {
    var modelContext: ModelContext
    var filterDayType: DayType?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Group sessions by month/year for section headers, applying the current filter.
    func groupedSessions(from sessions: [WorkoutSession]) -> [(String, [WorkoutSession])] {
        let filtered: [WorkoutSession]
        if let filter = filterDayType {
            filtered = sessions.filter { $0.dayType == filter }
        } else {
            filtered = sessions
        }

        let grouped = Dictionary(grouping: filtered) { session in
            session.date.formatted(.dateTime.month(.wide).year())
        }

        return grouped.sorted { a, b in
            let dateA = a.value.first?.date ?? .distantPast
            let dateB = b.value.first?.date ?? .distantPast
            return dateA > dateB
        }
    }

    func deleteSession(_ session: WorkoutSession) {
        modelContext.delete(session)
        try? modelContext.save()
    }
}
