// strength-training/Views/Progress/ProgressVolumeStats.swift
import Foundation

/// Pure-function shaper for the Progress dashboard's TOTAL VOLUME headline and area chart.
enum ProgressVolumeStats {

    /// One bar / one chart point.
    struct VolumePoint: Equatable, Identifiable {
        let id = UUID()
        let date: Date
        let volume: Double

        static func == (l: VolumePoint, r: VolumePoint) -> Bool {
            l.date == r.date && l.volume == r.volume
        }
    }

    /// Aggregate total non-warmup volume across `sessions` whose date is within
    /// `range`'s window ending at `now`. `.all` includes everything.
    static func totalVolume(
        in range: ProgressTimeRange,
        sessions: [WorkoutSession],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Double {
        let inRange = filter(sessions, in: range, now: now, calendar: calendar)
        return rawVolume(of: inRange)
    }

    /// Percent change vs the immediately-preceding window of the same duration.
    /// Returns nil when no comparable prior window exists (e.g. user has no data
    /// before the current window's start).
    static func deltaPct(
        in range: ProgressTimeRange,
        sessions: [WorkoutSession],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Double? {
        guard let start = range.startDate(now: now, calendar: calendar) else {
            // .all → split history at midpoint
            let sorted = sessions.sorted { $0.date < $1.date }
            guard sorted.count >= 2,
                  let first = sorted.first?.date,
                  let last = sorted.last?.date else { return nil }
            let mid = first.addingTimeInterval(last.timeIntervalSince(first) / 2)
            let pre = sorted.filter { $0.date < mid }
            let post = sorted.filter { $0.date >= mid }
            return percentDelta(prior: rawVolume(of: pre), current: rawVolume(of: post))
        }

        let duration = now.timeIntervalSince(start)
        let priorEnd = start
        let priorStart = priorEnd.addingTimeInterval(-duration)

        let priorVolume = rawVolume(of: sessions.filter { $0.date >= priorStart && $0.date < priorEnd })
        guard priorVolume > 0 else { return nil }
        let currentVolume = rawVolume(of: sessions.filter { $0.date >= start && $0.date <= now })
        return percentDelta(prior: priorVolume, current: currentVolume)
    }

    /// Bucketed series for the area chart. Buckets are aligned to the start of each
    /// day/week/month and labeled by their start date. Empty buckets emit zero volume
    /// (so the line drops cleanly).
    static func bucketedSeries(
        in range: ProgressTimeRange,
        sessions: [WorkoutSession],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [VolumePoint] {
        let cfg = bucketConfig(for: range, now: now, sessions: sessions, calendar: calendar)
        guard cfg.count > 0 else { return [] }

        // Emit `count` buckets, oldest → newest, each containing the volume of
        // sessions whose date falls in [bucketStart, bucketStart + step).
        var points: [VolumePoint] = []
        var bucketStart = cfg.firstStart
        for _ in 0..<cfg.count {
            let bucketEnd = calendar.date(byAdding: cfg.unit, value: cfg.value, to: bucketStart) ?? bucketStart
            let inBucket = sessions.filter { $0.date >= bucketStart && $0.date < bucketEnd }
            points.append(VolumePoint(date: bucketStart, volume: rawVolume(of: inBucket)))
            bucketStart = bucketEnd
        }
        return points
    }

    // MARK: - Private

    private struct BucketConfig {
        let firstStart: Date
        let count: Int
        let unit: Calendar.Component
        let value: Int  // step per bucket (1 day, 1 week, 1 month, etc.)
    }

    private static func bucketConfig(
        for range: ProgressTimeRange,
        now: Date,
        sessions: [WorkoutSession],
        calendar: Calendar
    ) -> BucketConfig {
        switch range {
        case .week:
            let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) ?? now
            return BucketConfig(firstStart: start, count: 7, unit: .day, value: 1)
        case .month:
            // 5 weekly buckets ending at the current week so the chart spans ~30 days
            // (matches the "Month" picker label rather than ~21 past + current week).
            let start = calendar.date(byAdding: .weekOfYear, value: -4, to: startOfWeek(for: now, calendar: calendar)) ?? now
            return BucketConfig(firstStart: start, count: 5, unit: .weekOfYear, value: 1)
        case .threeMonths:
            let start = calendar.date(byAdding: .weekOfYear, value: -11, to: startOfWeek(for: now, calendar: calendar)) ?? now
            return BucketConfig(firstStart: start, count: 12, unit: .weekOfYear, value: 1)
        case .year:
            let start = calendar.date(byAdding: .month, value: -11, to: startOfMonth(for: now, calendar: calendar)) ?? now
            return BucketConfig(firstStart: start, count: 12, unit: .month, value: 1)
        case .all:
            let sorted = sessions.sorted { $0.date < $1.date }
            guard let first = sorted.first?.date else { return BucketConfig(firstStart: now, count: 0, unit: .day, value: 1) }
            let span = now.timeIntervalSince(first)
            let oneYear: TimeInterval = 365 * 24 * 3600
            if span >= oneYear {
                let firstMonth = startOfMonth(for: first, calendar: calendar)
                let monthsSpan = max(1, Int((span / (30 * 24 * 3600)).rounded(.up)))
                let bucketCount = min(12, monthsSpan)
                let step = max(1, Int((Double(monthsSpan) / Double(bucketCount)).rounded(.up)))
                return BucketConfig(firstStart: firstMonth, count: bucketCount, unit: .month, value: step)
            } else {
                let firstWeek = startOfWeek(for: first, calendar: calendar)
                let weeksSpan = max(1, Int((span / (7 * 24 * 3600)).rounded(.up)))
                let bucketCount = min(12, weeksSpan)
                let step = max(1, Int((Double(weeksSpan) / Double(bucketCount)).rounded(.up)))
                return BucketConfig(firstStart: firstWeek, count: bucketCount, unit: .weekOfYear, value: step)
            }
        }
    }

    private static func startOfWeek(for date: Date, calendar: Calendar) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
    }

    private static func startOfMonth(for date: Date, calendar: Calendar) -> Date {
        calendar.dateInterval(of: .month, for: date)?.start ?? date
    }

    private static func filter(
        _ sessions: [WorkoutSession],
        in range: ProgressTimeRange,
        now: Date,
        calendar: Calendar
    ) -> [WorkoutSession] {
        guard let start = range.startDate(now: now, calendar: calendar) else { return sessions }
        return sessions.filter { $0.date >= start && $0.date <= now }
    }

    private static func rawVolume(of sessions: [WorkoutSession]) -> Double {
        var total: Double = 0
        for session in sessions {
            for record in session.exerciseRecordsArray {
                for set in record.setsArray where !set.isWarmup {
                    total += set.weightLbs * Double(set.reps)
                }
            }
        }
        return total
    }

    private static func percentDelta(prior: Double, current: Double) -> Double? {
        guard prior > 0 else { return nil }
        return ((current - prior) / prior) * 100
    }
}
