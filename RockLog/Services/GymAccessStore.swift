//
//  GymAccessStore.swift
//  RockLog
//
//  Saved check-in places. Local defaults plus iCloud key-value, same as the
//  old single membership barcode. Location is not stored here as a track;
//  a caller passes one coordinate when it has one.
//

import Foundation
import CoreLocation
import Observation

@Observable
final class GymAccessStore {
    static let shared = GymAccessStore()
    static let storageKey = "gymAccessEntriesJSON"
    static let pinnedKey = "gymAccessPinnedID"

    private(set) var entries: [GymAccessEntry] = []
    /// Long-press choice. A later nearby fix replaces it.
    var pinnedID: UUID?

    private var isApplying = false

    private init() {
        load()
    }

    func load() {
        isApplying = true
        defer { isApplying = false }
        let defaults = UserDefaults.standard
        let kvs = NSUbiquitousKeyValueStore.default
        let raw = kvs.string(forKey: Self.storageKey) ?? defaults.string(forKey: Self.storageKey)
        let decoded = raw.flatMap { $0.data(using: .utf8) }.map { GymAccessCodec.decode($0) } ?? []
        let legacy = GymMembershipStore.shared
        entries = GymAccessCodec.migratingLegacy(
            entries: decoded,
            code: legacy.code,
            label: legacy.label,
            formatRaw: legacy.formatRaw
        )
        if let pin = defaults.string(forKey: Self.pinnedKey) {
            pinnedID = UUID(uuidString: pin)
        }
        if entries != decoded {
            persist()
        }
    }

    func select(at location: GeoPoint?) -> GymAccessEntry? {
        GymAccessChoice.select(entries: entries, location: location, pinnedID: pinnedID)
    }

    func pin(_ entry: GymAccessEntry) {
        pinnedID = entry.id
        UserDefaults.standard.set(entry.id.uuidString, forKey: Self.pinnedKey)
    }

    func save(_ entry: GymAccessEntry) {
        var next = entries
        if let index = next.firstIndex(where: { $0.id == entry.id }) {
            next[index] = entry
        } else {
            next.append(entry)
        }
        if entry.isDefault {
            for index in next.indices where next[index].id != entry.id {
                next[index].isDefault = false
            }
        } else if !next.contains(where: \.isDefault), let first = next.indices.first {
            next[first].isDefault = true
        }
        entries = next
        persist()
    }

    func delete(_ id: UUID) {
        entries.removeAll { $0.id == id }
        if pinnedID == id { pinnedID = nil }
        if !entries.contains(where: \.isDefault), !entries.isEmpty {
            entries[0].isDefault = true
        }
        persist()
    }

    /// One-shot location when a workout starts. Unit tests and UI tests skip it.
    func noteWorkoutStarted() {
        guard shouldRequestLocation else { return }
        Task { await refreshFromLocation() }
    }

    func refreshFromLocation() async {
        guard shouldRequestLocation else { return }
        let fix = await WhenInUseLocation.shared.requestOnce()
        let point = fix.map { GeoPoint(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude) }
        guard let point,
              let nearest = GymAccessChoice.nearest(in: entries, to: point, within: GymAccessChoice.nearMeters)
        else { return }
        pin(nearest)
    }

    private var shouldRequestLocation: Bool {
        if RockLogTestHost.isUnitTestHost { return false }
        #if DEBUG
        if UITestLaunch.isEnabled { return false }
        #endif
        return entries.count > 1
    }

    private func persist() {
        guard !isApplying else { return }
        let data = GymAccessCodec.encode(entries)
        let json = String(data: data, encoding: .utf8) ?? "[]"
        UserDefaults.standard.set(json, forKey: Self.storageKey)
        NSUbiquitousKeyValueStore.default.set(json, forKey: Self.storageKey)
        if let pinnedID {
            UserDefaults.standard.set(pinnedID.uuidString, forKey: Self.pinnedKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.pinnedKey)
        }
    }
}
