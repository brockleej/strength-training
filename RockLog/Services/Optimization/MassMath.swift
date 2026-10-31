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
        case .kilograms: [5, 2.5, 1, 0.5]
        }
    }

    /// Step a fresh Focus screen starts on. Kilograms keep 2.5 even though 5 is in the cycle.
    var defaultStepperStep: Double {
        switch self {
        case .pounds: 5
        case .kilograms: 2.5
        }
    }

    /// Readout quantum. Staying in one unit rounds back onto this grid.
    var readoutQuantum: Double {
        switch self {
        case .pounds: 0.5
        case .kilograms: 0.25
        }
    }

    /// Smallest stack step this unit will store. A typed kilogram step below this is raised.
    var minimumStackStep: Double {
        switch self {
        case .pounds: 5
        case .kilograms: 2.5
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

/// One mass unit for the app. Local UserDefaults and iCloud hold the same
/// raw value after a read: a choice on this device is written to iCloud, and
/// a cloud value is copied locally only when this device has none.
nonisolated struct MassUnitReading: Equatable, Sendable {
    var unit: MassUnit
    /// Nil leaves that side untouched.
    var writeLocal: String?
    var writeCloud: String?
}

nonisolated enum MassUnitResolution {
    static func resolve(local: String?, cloud: String?) -> MassUnitReading {
        if let local, let unit = MassUnit(rawValue: local) {
            return MassUnitReading(
                unit: unit,
                writeLocal: nil,
                writeCloud: cloud == local ? nil : local
            )
        }
        if let cloud, let unit = MassUnit(rawValue: cloud) {
            return MassUnitReading(unit: unit, writeLocal: cloud, writeCloud: nil)
        }
        return MassUnitReading(unit: .pounds, writeLocal: nil, writeCloud: nil)
    }
}

nonisolated protocol MassUnitStoring: AnyObject {
    var unit: MassUnit { get set }
}

/// In-memory unit for the unit-test host and UI-test launches. It never
/// reads or writes `NSUbiquitousKeyValueStore`.
nonisolated final class MemoryMassUnitStore: MassUnitStoring, @unchecked Sendable {
    nonisolated(unsafe) var unit: MassUnit
    init(unit: MassUnit) { self.unit = unit }
}

/// Production store. UserDefaults is what `@AppStorage` reads. iCloud is
/// updated to that same value, or copied in when this device has no choice.
nonisolated final class ProductionMassUnitStore: MassUnitStoring {
    var unit: MassUnit {
        get {
            let local = AppDefaults.local.string(forKey: MassUnitPreferences.key)
            let cloud = AppDefaults.cloud.string(forKey: MassUnitPreferences.key)
            let reading = MassUnitResolution.resolve(local: local, cloud: cloud)
            if let writeLocal = reading.writeLocal {
                AppDefaults.local.set(writeLocal, forKey: MassUnitPreferences.key)
            }
            if let writeCloud = reading.writeCloud {
                AppDefaults.cloud.set(writeCloud, forKey: MassUnitPreferences.key)
            }
            return reading.unit
        }
        set {
            let raw = newValue.rawValue
            AppDefaults.local.set(raw, forKey: MassUnitPreferences.key)
            AppDefaults.cloud.set(raw, forKey: MassUnitPreferences.key)
        }
    }
}

nonisolated enum MassUnitPreferences {
    static let key = "massUnit"
    /// UI tests pass `-RockLogMassUnit lb` or `kg`. The unit-test host omits
    /// it and stays on pounds.
    static let launchArgument = "-RockLogMassUnit"

    private static let lock = NSLock()
    nonisolated(unsafe) private static var storage: any MassUnitStoring = makeStore()

    static var unit: MassUnit {
        get { lock.withLock { storage.unit } }
        set { lock.withLock { storage.unit = newValue } }
    }

    static var isIsolatedFromCloud: Bool {
        RockLogTestHost.isUnitTestHost || UITestLaunch.isEnabled
    }

    static func unitFromLaunchArguments(_ arguments: [String]) -> MassUnit {
        guard let index = arguments.firstIndex(of: launchArgument),
              index + 1 < arguments.count,
              let unit = MassUnit(rawValue: arguments[index + 1]) else {
            return .pounds
        }
        return unit
    }

    /// Tests and UI launches only. Production keeps the store `makeStore` built.
    static func useIsolatedUnit(_ unit: MassUnit) {
        lock.withLock {
            storage = MemoryMassUnitStore(unit: unit)
        }
    }

    /// Adopt iCloud when this device has no local choice, and publish a local
    /// choice that iCloud does not have yet. No-ops in tests.
    static func pullFromCloud() {
        guard !isIsolatedFromCloud else { return }
        AppDefaults.cloud.synchronize()
        _ = unit
    }

    private static func makeStore() -> any MassUnitStoring {
        if isIsolatedFromCloud {
            return MemoryMassUnitStore(unit: unitFromLaunchArguments(ProcessInfo.processInfo.arguments))
        }
        return ProductionMassUnitStore()
    }
}

nonisolated enum MassMath {
    /// International pound. Exact enough that 100 kg round-trips to 100 kg.
    static let poundsPerKilogram = 2.2046226218

    static let maximumStoredPounds = 10_000.0
    /// Two stored weights are the same inside this band. Callers do not use `==`.
    static let sameStoredToleranceLbs = 0.01

    static func sameStoredPounds(_ lhs: Double, _ rhs: Double) -> Bool {
        lhs.isFinite && rhs.isFinite && abs(lhs - rhs) <= sameStoredToleranceLbs
    }

    /// True when both stored weights snap to the same number on `unit`'s readout.
    /// A kg round-trip can move the stored pounds by a few tenths without
    /// changing the kilograms the lifter sees. That is not a heavier set.
    static func sameDisplayed(_ lhsPounds: Double, _ rhsPounds: Double, unit: MassUnit) -> Bool {
        guard lhsPounds.isFinite, rhsPounds.isFinite else { return false }
        return display(fromPounds: lhsPounds, unit: unit) == display(fromPounds: rhsPounds, unit: unit)
    }

    static func isHeavier(_ lhsPounds: Double, than rhsPounds: Double, unit: MassUnit) -> Bool {
        guard lhsPounds.isFinite, rhsPounds.isFinite else { return false }
        return display(fromPounds: lhsPounds, unit: unit) > display(fromPounds: rhsPounds, unit: unit)
    }

    /// What to show. The original entry wins when the display unit matches it,
    /// so lb → kg → lb does not walk the number.
    static func shown(
        enteredValue: Double?,
        enteredUnit: MassUnit?,
        canonicalPounds: Double,
        display: MassUnit
    ) -> Double {
        if let enteredUnit, enteredUnit == display, let enteredValue, enteredValue.isFinite {
            return enteredValue
        }
        return self.display(fromPounds: canonicalPounds, unit: display)
    }

    static func clampedStackStep(_ step: Double, unit: MassUnit) -> Double {
        guard step.isFinite, step > 0 else { return unit.minimumStackStep }
        if unit == .kilograms { return max(step, unit.minimumStackStep) }
        return step
    }

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

    /// What an edit to a saved set stores. If the weight on screen is the same
    /// number the set already shows in `unit`, the stored pounds and the original
    /// entry stay exactly as they were (a reps-only edit in kg must not rewrite a
    /// set entered in lb). Otherwise the new number is stored as typed in `unit`.
    static func editedEntry(
        previousPounds: Double,
        previousEnteredValue: Double?,
        previousEnteredUnit: MassUnit?,
        newDisplay: Double,
        unit: MassUnit
    ) -> (pounds: Double, enteredValue: Double?, enteredUnit: MassUnit?) {
        let shownBefore = shown(
            enteredValue: previousEnteredUnit == nil ? nil : previousEnteredValue,
            enteredUnit: previousEnteredUnit,
            canonicalPounds: previousPounds,
            display: unit
        )
        if snap(newDisplay, quantum: unit.readoutQuantum) == snap(shownBefore, quantum: unit.readoutQuantum) {
            return (previousPounds, previousEnteredUnit == nil ? nil : previousEnteredValue, previousEnteredUnit)
        }
        return (storedPounds(fromEntered: newDisplay, unit: unit), newDisplay, unit)
    }

    /// Store the pound equivalent of a number the lifter typed in `unit`,
    /// snapped onto that unit's readout so the next view matches.
    static func storedPounds(fromEntered value: Double, unit: MassUnit) -> Double {
        let shown = snap(value, quantum: unit.readoutQuantum)
        return Self.pounds(fromDisplay: shown, unit: unit)
    }

    /// Snap an ideal pound target onto the active unit's plate grid, then
    /// convert back to stored pounds. A second snap in the same unit does not walk.
    static func snapProgression(pounds: Double, unit: MassUnit) -> Double {
        let shown = exactDisplay(fromPounds: pounds, unit: unit)
        let snapped = snap(shown, quantum: unit.progressionQuantum)
        return Self.pounds(fromDisplay: snapped, unit: unit)
    }

    /// Switching units and back moves at most one readout step. A second
    /// toggle in the same direction does not walk further.
    static func switched(_ pounds: Double, from: MassUnit, to: MassUnit) -> Double {
        let shown = display(fromPounds: pounds, unit: to)
        return Self.pounds(fromDisplay: shown, unit: to)
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
