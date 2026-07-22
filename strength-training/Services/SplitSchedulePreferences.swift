//
//  SplitSchedulePreferences.swift
//  strength-training
//
//  Rolling vs weekly split schedule + carryover for incomplete weeks.
//

import Foundation

/// How the app advances through the ordered training split.
enum SplitScheduleMode: String, CaseIterable, Identifiable {
    /// After each workout, suggest the next day in order (wraps). Ignores calendar weeks.
    case rolling = "rolling"
    /// Aim to complete every split day once per calendar week (Mon–Sun).
    case weekly = "weekly"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rolling: "Rolling"
        case .weekly: "Strict weekly"
        }
    }

    /// Short label for Settings rows / segmented control when space is tight.
    var shortTitle: String {
        switch self {
        case .rolling: "Rolling"
        case .weekly: "Weekly"
        }
    }

    var detail: String {
        switch self {
        case .rolling:
            "Always suggests the next day after your last workout. Miss a day, keep going — no calendar week reset."
        case .weekly:
            "One pass through your split per Mon–Sun week. Incomplete weeks prompt you to finish remaining days or restart."
        }
    }
}

enum SplitSchedulePreferences {
    static let modeKey = "splitScheduleMode"
    static let carryoverKey = "splitScheduleCarryoverDays"
    static let promptWeekKey = "splitSchedulePromptWeekStart"

    static var mode: SplitScheduleMode {
        get {
            let raw = UserDefaults.standard.string(forKey: modeKey) ?? ""
            return SplitScheduleMode(rawValue: raw) ?? .rolling
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: modeKey)
        }
    }

    /// Day names still owed from a prior incomplete week (weekly mode).
    static var carryoverDayNames: [String] {
        get {
            (UserDefaults.standard.string(forKey: carryoverKey) ?? "")
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        set {
            UserDefaults.standard.set(newValue.joined(separator: ","), forKey: carryoverKey)
        }
    }

    /// ISO date string for the Monday of a week we already prompted.
    static var promptedWeekStartID: String? {
        get { UserDefaults.standard.string(forKey: promptWeekKey) }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue, forKey: promptWeekKey)
            } else {
                UserDefaults.standard.removeObject(forKey: promptWeekKey)
            }
        }
    }

    static func markPrompted(weekStart: Date, calendar: Calendar = .current) {
        promptedWeekStartID = weekStartID(weekStart, calendar: calendar)
    }

    static func didPrompt(forWeekStart weekStart: Date, calendar: Calendar = .current) -> Bool {
        promptedWeekStartID == weekStartID(weekStart, calendar: calendar)
    }

    static func weekStartID(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        let y = c.yearForWeekOfYear ?? 0
        let w = c.weekOfYear ?? 0
        return String(format: "%04d-W%02d", y, w)
    }

    static func clearCarryover() {
        carryoverDayNames = []
    }

    static func setCarryover(_ days: [DayType]) {
        carryoverDayNames = days.map(\.rawValue)
    }
}
