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

    func fetchSessions() -> [WorkoutSession] {
        // Fetch all completed sessions, then filter by dayType in Swift
        // to avoid #Predicate limitations with Codable enums
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> { $0.isCompleted == true },
            sortBy: [SortDescriptor(\WorkoutSession.date, order: .reverse)]
        )

        let all = (try? modelContext.fetch(descriptor)) ?? []

        if let filter = filterDayType {
            return all.filter { $0.dayType == filter }
        }
        return all
    }

    /// Group sessions by month/year for section headers.
    func groupedSessions() -> [(String, [WorkoutSession])] {
        let sessions = fetchSessions()
        let grouped = Dictionary(grouping: sessions) { session in
            session.date.formatted(.dateTime.month(.wide).year())
        }

        // Sort groups by the most recent session date in each group
        return grouped.sorted { a, b in
            let dateA = a.value.first?.date ?? .distantPast
            let dateB = b.value.first?.date ?? .distantPast
            return dateA > dateB
        }
    }

    func deleteSession(_ session: WorkoutSession) {
        modelContext.delete(session)
        try? modelContext.save()
        NotificationCenter.default.post(name: .workoutDataDidChange, object: nil)
    }
}
