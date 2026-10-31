//
//  LoadMath.swift
//  RockLog
//
//  Bar, assist, and added load. Body weight is the latest weigh-in on or
//  before the set, then the Settings number. We do not invent past weigh-ins.
//

import Foundation

nonisolated enum LoadMode: String, Codable, CaseIterable, Sendable {
    case bar
    case assist
    case added

    var title: String {
        switch self {
        case .bar: "Total"
        case .assist: "Assist"
        case .added: "Added"
        }
    }

    /// Plain menu wording. The pill shows `title`.
    var menuLabel: String {
        switch self {
        case .bar: "Total — the weight I lift"
        case .assist: "Assist — machine helps (body weight minus)"
        case .added: "Added — on top of body weight"
        }
    }

    /// Pill text, e.g. "Load: Total".
    var pillLabel: String { "Load: \(title)" }

    init(stored raw: String, isAssisted: Bool) {
        if let mode = LoadMode(rawValue: raw), !raw.isEmpty {
            self = mode
        } else {
            self = isAssisted ? .assist : .bar
        }
    }
}

nonisolated enum LoadMath {
    struct WeighIn: Equatable, Sendable {
        var date: Date
        var pounds: Double
    }

    /// Latest weigh-in on or before `date`. Nil when the log has nothing that old.
    static func loggedPounds(asOf date: Date, weighIns: [WeighIn]) -> Double? {
        weighIns
            .filter { $0.date <= date && $0.pounds > 0 }
            .max { $0.date < $1.date }?
            .pounds
    }

    /// Log first, then the Settings fallback. 0 means neither is set.
    static func bodyWeight(asOf date: Date, weighIns: [WeighIn], settingsPounds: Double) -> Double {
        if let logged = loggedPounds(asOf: date, weighIns: weighIns) { return logged }
        return settingsPounds > 0 ? settingsPounds : 0
    }

    /// The Settings number tracks the newest log by date, not a backdated row.
    static func settingsPounds(afterLogging weighIns: [WeighIn], previousSettings: Double) -> Double {
        guard let newest = weighIns.filter({ $0.pounds > 0 }).max(by: { $0.date < $1.date }) else {
            return previousSettings
        }
        return newest.pounds
    }

    /// Load used for volume, e1RM, and progression.
    static func effective(mode: LoadMode, entered: Double, bodyWeight: Double) -> Double {
        switch mode {
        case .bar:
            return max(0, entered)
        case .assist:
            guard bodyWeight > 0 else { return 0 }
            return max(0, bodyWeight - entered)
        case .added:
            guard bodyWeight > 0 else { return 0 }
            return max(0, bodyWeight + entered)
        }
    }

    /// Turn an effective-load target back into the number the lifter dials.
    static func entered(fromEffective effective: Double, mode: LoadMode, bodyWeight: Double) -> Double {
        switch mode {
        case .bar:
            return max(0, effective)
        case .assist:
            guard bodyWeight > 0 else { return 0 }
            return max(0, bodyWeight - effective)
        case .added:
            guard bodyWeight > 0 else { return max(0, effective) }
            return max(0, effective - bodyWeight)
        }
    }

    /// e1RM divided by that day's body weight. Nil when there is no weigh-in to divide by.
    static func relativeStrength(e1RM: Double, bodyWeight: Double) -> Double? {
        guard bodyWeight > 0, e1RM.isFinite else { return nil }
        return e1RM / bodyWeight
    }
}

/// When the Focus screen shows "bar + plates per side".
nonisolated enum PlateLinePolicy {
    /// Plates only make sense for a plain total on a bar: not assisted, not added to body weight,
    /// and not on a machine whose steps were set for this lift.
    static func shows(isAssisted: Bool, loadMode: LoadMode, stack: StackDefinition?) -> Bool {
        guard !isAssisted, loadMode == .bar else { return false }
        return !(stack?.isActive ?? false)
    }

    /// The readout for the number on the weight stepper. That number is already in `unit`.
    static func readout(displayedWeight: Double, unit: MassUnit) -> MassMath.PlateReadout {
        MassMath.plates(forTotal: displayedWeight, unit: unit)
    }
}
