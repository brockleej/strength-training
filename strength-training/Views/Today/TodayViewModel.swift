import SwiftUI
import SwiftData

/// Derived state for the Today screen — weekly aggregates, last-trained day type,
/// per-card subtitle data, yesterday-card data. Pure read model: doesn't mutate.
/// Mutating actions (start workout, cancel suspended) go through `WorkoutViewModel`.
@Observable
final class TodayViewModel {
    let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Yesterday-section eyebrow label rule (pure)
    //
    // The "Yesterday" section header label varies by how recent the most recent
    // completed session is:
    //   - literally yesterday → "YESTERDAY"
    //   - 2–6 days ago        → uppercase weekday name (e.g. "MONDAY")
    //   - 7+ days ago         → "N DAYS AGO"

    /// Pure helper exposed for unit testing. `now` parameter lets tests pin time.
    static func relativeDayLabel(for date: Date, now: Date = .now) -> String {
        let cal = Calendar(identifier: .gregorian)
        let startOfRef = cal.startOfDay(for: date)
        let startOfNow = cal.startOfDay(for: now)
        let days = cal.dateComponents([.day], from: startOfRef, to: startOfNow).day ?? 0

        switch days {
        case 0:
            return "TODAY"
        case 1:
            return "YESTERDAY"
        case 2...6:
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date).uppercased()
        default:
            return "\(days) DAYS AGO"
        }
    }

    // MARK: - Initial day-card selection

    /// Pick which day card the picker should auto-select on appear.
    /// Priority: suspended → most recent completed session → `.arms` fallback.
    func initialDayType(suspendedDayType: DayType?) -> DayType {
        if let suspendedDayType { return suspendedDayType }
        if let mostRecent = mostRecentCompletedSession()?.dayType { return mostRecent }
        return .arms
    }

    // MARK: - Queries (private)

    /// The single most-recent completed `WorkoutSession`, or nil.
    private func mostRecentCompletedSession() -> WorkoutSession? {
        var descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> { $0.isCompleted == true },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }
}
