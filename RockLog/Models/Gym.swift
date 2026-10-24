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
        if let home = existing.first(where: \.isHome) ?? existing.first(where: { $0.name == "Home" }) {
            if !home.isHome { home.isHome = true }
            return home
        }
        let home = Gym(name: "Home", isHome: true, sortOrder: 0)
        context.insert(home)
        try? context.save()
        return home
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
