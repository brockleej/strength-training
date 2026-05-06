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

    // MARK: - This Week stats

    /// Aggregate counts for the current ISO week (Mon-Sun, local time zone).
    struct WeekStats: Equatable {
        let sessionCount: Int
        let totalVolume: Int  // Int because UI shows whole pounds
        let totalSets: Int
    }

    /// Aggregate of sessions completed in the current ISO week.
    /// Volume is sum of weight × reps across all non-warmup sets in those sessions.
    func thisWeekStats(now: Date = .now) -> WeekStats {
        let sessions = sessionsInWeek(containing: now)
        var totalVolume: Double = 0
        var totalSets = 0
        for session in sessions {
            for record in session.exerciseRecordsArray {
                for set in record.setsArray where !set.isWarmup {
                    totalVolume += set.weightLbs * Double(set.reps)
                    totalSets += 1
                }
            }
        }
        return WeekStats(
            sessionCount: sessions.count,
            totalVolume: Int(totalVolume),
            totalSets: totalSets
        )
    }

    /// Maps weekday index 0–6 (Monday=0 ... Sunday=6) to the day type of the most
    /// recent completed session on that day, or nil if none.
    /// If multiple sessions on one day (rare), the last wins.
    func weekDayTypes(now: Date = .now) -> [Int: DayType] {
        let sessions = sessionsInWeek(containing: now)
        let cal = isoCalendar()
        var result: [Int: DayType] = [:]
        for session in sessions {
            let weekday = cal.component(.weekday, from: session.date)
            // Calendar's weekday: 1=Sunday, 2=Monday ... 7=Saturday
            // We want 0=Monday ... 6=Sunday
            let mondayBased = (weekday + 5) % 7
            result[mondayBased] = session.dayType
        }
        return result
    }

    /// Percent change in this-week volume vs last-week volume, as a fraction.
    /// E.g. +100% → 1.0, −20% → -0.2. Returns nil if last week's volume was zero.
    func weeklyVolumeDelta(now: Date = .now) -> Double? {
        let cal = isoCalendar()
        let thisWeekSessions = sessionsInWeek(containing: now)
        let lastWeekStart = cal.date(byAdding: .day, value: -7, to: cal.startOfWeek(for: now))!
        let lastWeekSessions = sessionsInWeek(containing: lastWeekStart)

        let thisVol = totalVolume(for: thisWeekSessions)
        let lastVol = totalVolume(for: lastWeekSessions)
        guard lastVol > 0 else { return nil }
        return (thisVol - lastVol) / lastVol
    }

    // MARK: - Yesterday data

    /// Display data for the Yesterday card. Returns nil when no completed session exists.
    /// Note: PR count is hard-coded to 0 for Phase 1 — Phase 3 wires PR detection.
    struct YesterdayData {
        let session: WorkoutSession
        let label: String              // "YESTERDAY" / "MONDAY" / "12 DAYS AGO"
        let dayType: DayType
        let durationLabel: String      // "47 min" / "1h 15m"
        let totalVolume: Int           // pounds
        let totalSets: Int
        let prCount: Int               // always 0 in Phase 1
    }

    /// Build the Yesterday-card data from the most recent completed session.
    func yesterdayData(now: Date = .now) -> YesterdayData? {
        guard let session = mostRecentCompletedSession() else { return nil }
        let label = Self.relativeDayLabel(for: session.date, now: now)
        var totalVolume: Double = 0
        var totalSets = 0
        for record in session.exerciseRecordsArray {
            for set in record.setsArray where !set.isWarmup {
                totalVolume += set.weightLbs * Double(set.reps)
                totalSets += 1
            }
        }
        let allSets = session.exerciseRecordsArray.flatMap { $0.setsArray }
        let durationSec = (allSets.map(\.completedAt).max()?.timeIntervalSince(session.date)) ?? 0

        return YesterdayData(
            session: session,
            label: label,
            dayType: session.dayType,
            durationLabel: formatDuration(durationSec),
            totalVolume: Int(totalVolume),
            totalSets: totalSets,
            prCount: 0  // TODO: Phase 3 wires PR detection
        )
    }

    // MARK: - Private query helpers

    private func sessionsInWeek(containing date: Date) -> [WorkoutSession] {
        let cal = isoCalendar()
        let weekStart = cal.startOfWeek(for: date)
        let weekEnd = cal.date(byAdding: .day, value: 7, to: weekStart)!
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> {
                $0.isCompleted == true && $0.date >= weekStart && $0.date < weekEnd
            },
            sortBy: [SortDescriptor(\.date)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func totalVolume(for sessions: [WorkoutSession]) -> Double {
        sessions.reduce(0.0) { sum, session in
            sum + session.exerciseRecordsArray.reduce(0.0) { recSum, record in
                recSum + record.setsArray.filter { !$0.isWarmup }.reduce(0.0) { setSum, set in
                    setSum + set.weightLbs * Double(set.reps)
                }
            }
        }
    }

    private func isoCalendar() -> Calendar {
        var cal = Calendar(identifier: .iso8601)
        cal.firstWeekday = 2  // Monday — matches ISO 8601
        return cal
    }
}

private extension Calendar {
    /// Start-of-week (Monday 00:00 in this calendar) for the given date.
    func startOfWeek(for date: Date) -> Date {
        let comps = self.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return self.date(from: comps)!
    }
}
