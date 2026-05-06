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

    // MARK: - Card subtitle data

    /// "{N} lifts · last session {duration}" (or " · no history" suffix when no prior).
    func cardSubtitle(for dayType: DayType) -> String {
        let liftCount = liftCount(for: dayType)
        if let duration = lastSessionDuration(for: dayType) {
            return "\(liftCount) lifts · last session \(formatDuration(duration))"
        }
        return "\(liftCount) lifts · no history"
    }

    private func liftCount(for dayType: DayType) -> Int {
        let descriptor = FetchDescriptor<Exercise>()
        let all = (try? modelContext.fetch(descriptor)) ?? []
        switch dayType {
        case .arms:     return all.filter { $0.dayType == .arms }.count
        case .legs:     return all.filter { $0.dayType == .legs }.count
        case .fullBody: return all.count   // arms + legs union
        }
    }

    /// Duration of most recent completed session of this day type, in seconds.
    /// Returns nil if no such session exists or the session has no logged sets.
    private func lastSessionDuration(for dayType: DayType) -> TimeInterval? {
        // SwiftData #Predicate can't compare enum values directly, so fetch all
        // completed sessions sorted descending by date, then filter in Swift.
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> { $0.isCompleted == true },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let candidates = (try? modelContext.fetch(descriptor)) ?? []
        guard let session = candidates.first(where: { $0.dayType == dayType }) else { return nil }

        // Prefer the time of the last logged set; return nil if no sets.
        let allSets = session.exerciseRecordsArray.flatMap { $0.setsArray }
        guard let lastSetAt = allSets.map(\.completedAt).max() else { return nil }
        return lastSetAt.timeIntervalSince(session.date)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let totalMinutes = Int(seconds / 60)
        if totalMinutes < 60 {
            return "\(totalMinutes) min"
        }
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return "\(hours)h \(minutes)m"
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
