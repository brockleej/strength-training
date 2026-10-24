//
//  MassMath.swift
//  RockLog
//
//  Pounds stay the stored unit. Kilograms are a display and plate-math view.
//  Half-pound and quarter-kilogram ties round half away from zero (`rounded()`).
//

import Foundation

nonisolated enum MassUnit: String, Codable, CaseIterable, Sendable {
    case pounds = "lb"
    case kilograms = "kg"

    var title: String {
        switch self {
        case .pounds: "Pounds"
        case .kilograms: "Kilograms"
        }
    }

    /// Stepper cycle, coarsest first.
    var stepperSteps: [Double] {
        switch self {
        case .pounds: [5, 1, 0.5]
        case .kilograms: [2.5, 1, 0.5]
        }
    }

    /// Readout quantum. Staying in one unit rounds back onto this grid.
    var readoutQuantum: Double {
        switch self {
        case .pounds: 0.5
        case .kilograms: 0.25
        }
    }

    /// Progression snap in this unit (5 lb or 2.5 kg).
    var progressionQuantum: Double {
        switch self {
        case .pounds: 5
        case .kilograms: 2.5
        }
    }

    var barWeight: Double {
        switch self {
        case .pounds: 45
        case .kilograms: 20
        }
    }

    /// Plates per side, heaviest first. Pairs only — one plate of a size means one per side.
    var platePairs: [Double] {
        switch self {
        case .pounds: [45, 35, 25, 10, 5, 2.5, 1.25]
        case .kilograms: [25, 20, 15, 10, 5, 2.5, 1.25]
        }
    }
}

nonisolated enum MassUnitPreferences {
    static let key = "massUnit"

    static var unit: MassUnit {
        get {
            let raw = UserDefaults.standard.string(forKey: key)
                ?? NSUbiquitousKeyValueStore.default.string(forKey: key)
            return MassUnit(rawValue: raw ?? "") ?? .pounds
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: key)
            NSUbiquitousKeyValueStore.default.set(newValue.rawValue, forKey: key)
        }
    }

    /// Pull a value another device wrote. Does not overwrite a local choice
    /// when iCloud has nothing stored.
    static func pullFromCloud() {
        NSUbiquitousKeyValueStore.default.synchronize()
        guard UserDefaults.standard.string(forKey: key) == nil,
              let raw = NSUbiquitousKeyValueStore.default.string(forKey: key),
              MassUnit(rawValue: raw) != nil
        else { return }
        UserDefaults.standard.set(raw, forKey: key)
    }
}

nonisolated enum MassMath {
    /// International pound. Exact enough that 100 kg round-trips to 100 kg.
    static let poundsPerKilogram = 2.2046226218

    static let maximumStoredPounds = 10_000.0

    static func snap(_ value: Double, quantum: Double) -> Double {
        guard quantum > 0, value.isFinite else { return value }
        return (value / quantum).rounded() * quantum
    }

    static func pounds(fromDisplay value: Double, unit: MassUnit) -> Double {
        switch unit {
        case .pounds: value
        case .kilograms: value * poundsPerKilogram
        }
    }

    /// Convert stored pounds to the display unit without readout rounding.
    static func exactDisplay(fromPounds pounds: Double, unit: MassUnit) -> Double {
        switch unit {
        case .pounds: pounds
        case .kilograms: pounds / poundsPerKilogram
        }
    }

    /// What the stepper shows for a stored pound value.
    static func display(fromPounds pounds: Double, unit: MassUnit) -> Double {
        snap(exactDisplay(fromPounds: pounds, unit: unit), quantum: unit.readoutQuantum)
    }

    /// Store the pound equivalent of a number the lifter typed in `unit`,
    /// snapped onto that unit's readout so the next view matches.
    static func storedPounds(fromEntered value: Double, unit: MassUnit) -> Double {
        let shown = snap(value, quantum: unit.readoutQuantum)
        return pounds(fromDisplay: shown, unit: unit)
    }

    /// Snap an ideal pound target onto the active unit's plate grid, then
    /// convert back to stored pounds. A second snap in the same unit does not walk.
    static func snapProgression(pounds: Double, unit: MassUnit) -> Double {
        let display = exactDisplay(fromPounds: pounds, unit: unit)
        let snapped = snap(display, quantum: unit.progressionQuantum)
        return pounds(fromDisplay: snapped, unit: unit)
    }

    /// Switching units and back moves at most one readout step. A second
    /// toggle in the same direction does not walk further.
    static func switched(_ pounds: Double, from: MassUnit, to: MassUnit) -> Double {
        let shown = display(fromPounds: pounds, unit: to)
        return pounds(fromDisplay: shown, unit: to)
    }

    static func format(_ pounds: Double, unit: MassUnit) -> String {
        let shown = display(fromPounds: pounds, unit: unit)
        return formatDisplay(shown) + " " + unit.rawValue
    }

    static func formatDisplay(_ value: Double) -> String {
        if abs(value.rounded() - value) < 0.001 {
            return String(Int(value.rounded()))
        }
        return String(format: "%g", value)
    }

    struct PlateReadout: Equatable, Sendable {
        var bar: Double
        var platesPerSide: [Double]
        var unit: MassUnit

        var text: String {
            let barText = "\(MassMath.formatDisplay(bar)) \(unit.rawValue) bar"
            if platesPerSide.isEmpty { return barText }
            let plates = platesPerSide.map { MassMath.formatDisplay($0) }.joined(separator: "+")
            return "\(barText) + \(plates) / side"
        }
    }

    /// Greedy pairs. The calculator does not change the stored weight.
    static func plates(forTotal total: Double, unit: MassUnit) -> PlateReadout {
        var remainingPerSide = (total - unit.barWeight) / 2
        var plates: [Double] = []
        if remainingPerSide > 0.001 {
            for plate in unit.platePairs {
                while remainingPerSide + 0.001 >= plate {
                    plates.append(plate)
                    remainingPerSide -= plate
                }
            }
        }
        return PlateReadout(bar: unit.barWeight, platesPerSide: plates, unit: unit)
    }

    static func isStorable(_ pounds: Double) -> Bool {
        pounds.isFinite && pounds >= 0 && pounds <= maximumStoredPounds
    }
}
