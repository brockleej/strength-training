//
//  TodayStats.swift
//  strength-training
//
//  Pure date/format helpers for the Today screen — unit-tested, no SwiftData.
//

import Foundation

enum TodayStats {

    // MARK: - Relative day label

    /// Section-header label for the most recent completed session.
    /// Same day → "Today"; 1 day ago → "Yesterday"; 2–6 days → weekday name;
    /// 7+ days → "N days ago". (Rendered uppercase by SectionHeader.)
    static func relativeDayLabel(for date: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        let startNow = calendar.startOfDay(for: now)
        let startDate = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: startDate, to: startNow).day ?? 0
        switch days {
        case ..<1:
            return "Today"
        case 1:
            return "Yesterday"
        case 2...6:
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            formatter.locale = Locale(identifier: "en_US")   // app ships en-US copy throughout
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        default:
            return "\(days) days ago"
        }
    }

    // MARK: - Week grid

    struct WeekDayCell: Equatable {
        let letter: String       // "M", "T", …
        let trained: DayType?    // day-type ink fill when non-nil
        let isToday: Bool
    }

    /// Seven cells for the current Monday-start week. A day trained more than
    /// once shows its most recent session's day type.
    static func weekCells(
        sessions: [(date: Date, dayType: DayType)],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [WeekDayCell] {
        var cal = calendar
        cal.firstWeekday = 2   // Monday
        guard let weekStart = cal.dateInterval(of: .weekOfYear, for: now)?.start else { return [] }

        let letters = ["M", "T", "W", "T", "F", "S", "S"]
        return (0..<7).map { offset in
            let dayDate = cal.date(byAdding: .day, value: offset, to: weekStart)!
            let trained = sessions
                .filter { cal.isDate($0.date, inSameDayAs: dayDate) }
                .max { $0.date < $1.date }?
                .dayType
            return WeekDayCell(
                letter: letters[offset],
                trained: trained,
                isToday: cal.isDate(dayDate, inSameDayAs: now)
            )
        }
    }

    // MARK: - Volume formatting

    /// "12,840" — grouped, no fraction (rounded).
    static func formatVolume(_ lbs: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: NSNumber(value: lbs.rounded())) ?? String(Int(lbs.rounded()))
    }
}
