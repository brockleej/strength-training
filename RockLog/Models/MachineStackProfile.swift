//
//  MachineStackProfile.swift
//  RockLog
//
//  One stack for a (gym, lift) pair. Empty means the normal stepper.
//  Learning writes here. A step he typed is not replaced by learning.
//

import Foundation
import SwiftData

@Model
final class MachineStackProfile {
    var id: UUID = UUID()
    var gymID: UUID = UUID()
    var exerciseID: UUID = UUID()
    /// 0 means "no fixed step" (a pin list, or no profile).
    var stepPounds: Double = 0
    /// Comma-separated pin weights in `pinUnitRaw`.
    var pinsRaw: String = ""
    var pinUnitRaw: String = "lb"
    /// Comma-separated add-on plates, one at a time, in the pin unit.
    var addOnsRaw: String = ""
    var policyRaw: String = "nearest"
    /// "learned", "typed", or "" when the row is unused.
    var originRaw: String = ""
    var learnedSessionIDsRaw: String = ""
    var clearedAt: Date? = nil
    var learningEnabled: Bool = true
    var rangeMin: Double = 0
    var rangeMax: Double = 0

    init(gymID: UUID, exerciseID: UUID) {
        self.id = UUID()
        self.gymID = gymID
        self.exerciseID = exerciseID
    }

    var definition: StackDefinition {
        get {
            StackDefinition(
                step: stepPounds > 0 ? stepPounds : nil,
                pins: Self.numbers(pinsRaw),
                pinUnit: MassUnit(rawValue: pinUnitRaw) ?? .pounds,
                addOns: Self.numbers(addOnsRaw),
                rangeMin: rangeMin,
                rangeMax: rangeMax,
                policy: StackPolicy(rawValue: policyRaw) ?? .nearest,
                origin: StackOrigin(rawValue: originRaw),
                learningEnabled: learningEnabled,
                clearedAt: clearedAt,
                learnedSessionIDs: learnedSessionIDsRaw.split(separator: ",").compactMap { UUID(uuidString: String($0)) }
            )
        }
        set {
            stepPounds = newValue.step ?? 0
            pinsRaw = Self.joined(newValue.pins)
            pinUnitRaw = newValue.pinUnit.rawValue
            addOnsRaw = Self.joined(newValue.addOns)
            rangeMin = newValue.rangeMin
            rangeMax = newValue.rangeMax
            policyRaw = newValue.policy.rawValue
            originRaw = newValue.origin?.rawValue ?? ""
            learningEnabled = newValue.learningEnabled
            clearedAt = newValue.clearedAt
            learnedSessionIDsRaw = newValue.learnedSessionIDs.map(\.uuidString).joined(separator: ",")
        }
    }

    func applyTyped(step: Double?, pins: [Double], unit: MassUnit) {
        var next = definition
        next.step = step
        next.pins = pins
        next.pinUnit = unit
        next.origin = .typed
        next.learnedSessionIDs = []
        if let step, pins.isEmpty {
            next.rangeMin = step
            next.rangeMax = max(step * 40, 200)
        }
        definition = next
    }

    func clearLearned(at date: Date = .now) {
        var next = definition
        guard next.origin == .learned || next.origin == nil else { return }
        next.step = nil
        next.pins = []
        next.origin = nil
        next.learnedSessionIDs = []
        next.clearedAt = date
        definition = next
    }

    private static func numbers(_ raw: String) -> [Double] {
        raw.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
    }

    private static func joined(_ values: [Double]) -> String {
        values.map { MassMath.formatDisplay($0) }.joined(separator: ",")
    }
}

enum StackProfileStore {
    @MainActor
    static func profile(gymID: UUID, exerciseID: UUID, in context: ModelContext) -> MachineStackProfile? {
        let gym = gymID
        let exercise = exerciseID
        let descriptor = FetchDescriptor<MachineStackProfile>(
            predicate: #Predicate { $0.gymID == gym && $0.exerciseID == exercise }
        )
        return try? context.fetch(descriptor).first
    }

    @MainActor
    static func findOrCreate(gymID: UUID, exerciseID: UUID, in context: ModelContext) -> MachineStackProfile {
        if let existing = profile(gymID: gymID, exerciseID: exerciseID, in: context) {
            return existing
        }
        let created = MachineStackProfile(gymID: gymID, exerciseID: exerciseID)
        context.insert(created)
        return created
    }

    /// Current gym, then Home, then nil (callers snap 5 lb / 2.5 kg).
    @MainActor
    static func resolved(exerciseID: UUID, in context: ModelContext) -> StackDefinition? {
        guard GymLibrary.storeHasGyms(context) else { return nil }
        let gyms = (try? context.fetch(FetchDescriptor<Gym>())) ?? []
        let home = gyms.first(where: \.isHome)?.id
        let active = GymLibrary.activeID(in: context)
        let profiles = ((try? context.fetch(FetchDescriptor<MachineStackProfile>())) ?? []).map {
            (gymID: $0.gymID, exerciseID: $0.exerciseID, stack: $0.definition)
        }
        return GymStackLookup.resolve(
            exerciseID: exerciseID,
            gymID: active,
            homeGymID: home,
            profiles: profiles
        )
    }
}
