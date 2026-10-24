//
//  Gym.swift
//  RockLog
//
//  Where the lifter is training. Home exists even when he has never picked
//  another gym. Stack profiles are keyed by (gym, lift), not by the lift alone.
//

import Foundation
import SwiftData

@Model
final class Gym {
    var id: UUID = UUID()
    var name: String = "Home"
    var isHome: Bool = false
    var createdAt: Date = Date.now
    var sortOrder: Int = 0
    /// Reserved for a later "switch to this gym?" prompt. Empty in this build.
    var latitude: Double? = nil
    var longitude: Double? = nil
    var radiusMeters: Double? = nil

    init(name: String, isHome: Bool = false, sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.isHome = isHome
        self.createdAt = .now
        self.sortOrder = sortOrder
    }
}

enum GymLibrary {
    static let activeKey = "activeGymID"

    /// Inserts Home when the store has no gym. Does not delete or rewrite anything else.
    @MainActor
    static func storeHasGyms(_ context: ModelContext) -> Bool {
        context.container.schema.entities.contains { $0.name == "Gym" }
    }

    @MainActor
    static func ensureHome(in context: ModelContext) -> Gym {
        guard storeHasGyms(context) else {
            return Gym(name: "Home", isHome: true)
        }
        let existing = (try? context.fetch(FetchDescriptor<Gym>())) ?? []
        var dirty = false
        let home: Gym
        if let existingHome = existing.first(where: \.isHome) ?? existing.first(where: { $0.name == "Home" }) {
            if !existingHome.isHome {
                existingHome.isHome = true
                dirty = true
            }
            home = existingHome
        } else {
            home = Gym(name: "Home", isHome: true, sortOrder: 0)
            context.insert(home)
            dirty = true
        }
        if backfillEmptySessions(home: home, in: context) { dirty = true }
        if dirty { try? context.save() }
        return home
    }

    /// Sessions saved before the gym field count as Home. Returns true when a row changed.
    @MainActor
    @discardableResult
    static func backfillEmptySessions(home: Gym, in context: ModelContext) -> Bool {
        let sessions = (try? context.fetch(FetchDescriptor<WorkoutSession>())) ?? []
        var changed = false
        for session in sessions where session.gymID == nil {
            session.gymID = home.id
            if session.gymName.isEmpty { session.gymName = home.name }
            changed = true
        }
        return changed
    }

    @MainActor
    static func nameIsTaken(_ name: String, in context: ModelContext, ignoring: UUID? = nil) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        let gyms = (try? context.fetch(FetchDescriptor<Gym>())) ?? []
        return gyms.contains { gym in
            gym.id != ignoring && gym.name.compare(trimmed, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
    }

    /// Profiles stay on the gym they were learned for. The fallback follows the new Home.
    @MainActor
    static func makeHome(_ gym: Gym, in context: ModelContext) {
        let gyms = (try? context.fetch(FetchDescriptor<Gym>())) ?? []
        for other in gyms { other.isHome = other.id == gym.id }
        try? context.save()
    }

    /// Home cannot be deleted. A travel gym takes its profiles with it.
    @MainActor
    static func deleteTravelGym(_ gym: Gym, in context: ModelContext) {
        guard !gym.isHome else { return }
        let id = gym.id
        let profiles = (try? context.fetch(FetchDescriptor<MachineStackProfile>())) ?? []
        for profile in profiles where profile.gymID == id {
            context.delete(profile)
        }
        context.delete(gym)
        if UserDefaults.standard.string(forKey: activeKey) == id.uuidString {
            UserDefaults.standard.removeObject(forKey: activeKey)
        }
        try? context.save()
    }

    @MainActor
    static func activeID(in context: ModelContext) -> UUID {
        guard storeHasGyms(context) else { return UUID() }
        let home = ensureHome(in: context)
        if let raw = UserDefaults.standard.string(forKey: activeKey),
           let id = UUID(uuidString: raw),
           ((try? context.fetch(FetchDescriptor<Gym>())) ?? []).contains(where: { $0.id == id }) {
            return id
        }
        UserDefaults.standard.set(home.id.uuidString, forKey: activeKey)
        return home.id
    }

    @MainActor
    static func select(_ gym: Gym) {
        UserDefaults.standard.set(gym.id.uuidString, forKey: activeKey)
    }
}
