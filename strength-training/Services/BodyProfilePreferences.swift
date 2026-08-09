//
//  BodyProfilePreferences.swift
//  strength-training
//
//  Height, sex, and body weight for Navy body-fat / FFMI / assisted lifts.
//  Local UserDefaults + iCloud KVS so values survive reinstall (same Apple ID).
//

import Foundation
import Observation

enum BiologicalSex: String, CaseIterable, Identifiable {
    case male
    case female

    var id: String { rawValue }

    var title: String {
        switch self {
        case .male: "Male"
        case .female: "Female"
        }
    }
}

@Observable
final class BodyProfileStore {
    static let shared = BodyProfileStore()

    static let heightInchesKey = "bodyHeightInches"
    static let sexKey = "bodyBiologicalSex"
    static let weightKey = BodyWeightPreferences.poundsKey

    /// Standing height in inches. 0 = not set.
    var heightInches: Double = 0 {
        didSet { persistDouble(heightInches, key: Self.heightInchesKey, old: oldValue) }
    }

    var sexRaw: String = BiologicalSex.male.rawValue {
        didSet { persistString(sexRaw, key: Self.sexKey, old: oldValue) }
    }

    /// Body weight in pounds. 0 = not set.
    var weightPounds: Double = 0 {
        didSet {
            persistDouble(weightPounds, key: Self.weightKey, old: oldValue, removeIfZero: true)
            // Keep legacy static API / assisted-lift path in sync.
            if !isApplyingRemote {
                BodyWeightPreferences.pounds = weightPounds
            }
        }
    }

    var sex: BiologicalSex {
        get { BiologicalSex(rawValue: sexRaw) ?? .male }
        set { sexRaw = newValue.rawValue }
    }

    var hasHeight: Bool { heightInches > 0 }
    var hasWeight: Bool { weightPounds > 0 }

    private var isApplyingRemote = false
    private var kvsObserver: NSObjectProtocol?

    private init() {
        loadMerged()
        kvsObserver = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default,
            queue: .main
        ) { [weak self] note in
            self?.applyExternalChange(note)
        }
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    deinit {
        if let kvsObserver {
            NotificationCenter.default.removeObserver(kvsObserver)
        }
    }

    func hydrateFromICloud() {
        NSUbiquitousKeyValueStore.default.synchronize()
        loadMerged()
    }

    func apply(weightPounds: Double, heightInches: Double, sex: BiologicalSex) {
        self.weightPounds = max(0, weightPounds)
        self.heightInches = max(0, heightInches)
        self.sex = sex
    }

    static func formatHeight(_ inches: Double) -> String {
        guard inches > 0 else { return "—" }
        let total = Int(inches.rounded())
        let feet = total / 12
        let rem = total % 12
        return "\(feet)′\(rem)\""
    }

    // MARK: - Private

    private func loadMerged() {
        isApplyingRemote = true
        defer { isApplyingRemote = false }

        let defaults = UserDefaults.standard
        let kvs = NSUbiquitousKeyValueStore.default

        weightPounds = preferredPositive(
            kvs.double(forKey: Self.weightKey),
            defaults.double(forKey: Self.weightKey)
        )
        heightInches = preferredPositive(
            kvs.double(forKey: Self.heightInchesKey),
            defaults.double(forKey: Self.heightInchesKey)
        )
        let sexKVS = kvs.string(forKey: Self.sexKey)
        let sexLocal = defaults.string(forKey: Self.sexKey)
        if let s = sexKVS, BiologicalSex(rawValue: s) != nil {
            sexRaw = s
        } else if let s = sexLocal, BiologicalSex(rawValue: s) != nil {
            sexRaw = s
        } else {
            sexRaw = BiologicalSex.male.rawValue
        }

        // Mirror into both stores + legacy body-weight key.
        persistAll()
        BodyWeightPreferences.pounds = weightPounds
    }

    private func applyExternalChange(_ notification: Notification) {
        if let keys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] {
            let ours: Set<String> = [Self.weightKey, Self.heightInchesKey, Self.sexKey]
            guard keys.contains(where: { ours.contains($0) }) else { return }
        }
        loadMerged()
    }

    private func preferredPositive(_ a: Double, _ b: Double) -> Double {
        if a > 0 { return a }
        if b > 0 { return b }
        return 0
    }

    private func persistDouble(
        _ value: Double,
        key: String,
        old: Double,
        removeIfZero: Bool = false
    ) {
        guard !isApplyingRemote, value != old else { return }
        let defaults = UserDefaults.standard
        let kvs = NSUbiquitousKeyValueStore.default
        if removeIfZero, value <= 0 {
            defaults.removeObject(forKey: key)
            kvs.removeObject(forKey: key)
        } else {
            defaults.set(value, forKey: key)
            kvs.set(value, forKey: key)
        }
        kvs.synchronize()
    }

    private func persistString(_ value: String, key: String, old: String) {
        guard !isApplyingRemote, value != old else { return }
        UserDefaults.standard.set(value, forKey: key)
        NSUbiquitousKeyValueStore.default.set(value, forKey: key)
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    private func persistAll() {
        let defaults = UserDefaults.standard
        let kvs = NSUbiquitousKeyValueStore.default
        if weightPounds > 0 {
            defaults.set(weightPounds, forKey: Self.weightKey)
            kvs.set(weightPounds, forKey: Self.weightKey)
        }
        if heightInches > 0 {
            defaults.set(heightInches, forKey: Self.heightInchesKey)
            kvs.set(heightInches, forKey: Self.heightInchesKey)
        }
        defaults.set(sexRaw, forKey: Self.sexKey)
        kvs.set(sexRaw, forKey: Self.sexKey)
        kvs.synchronize()
    }
}

/// Static façade for call sites that only need a quick read.
enum BodyProfilePreferences {
    static let heightInchesKey = BodyProfileStore.heightInchesKey
    static let sexKey = BodyProfileStore.sexKey

    static var heightInches: Double {
        get { BodyProfileStore.shared.heightInches }
        set { BodyProfileStore.shared.heightInches = newValue }
    }

    static var sex: BiologicalSex {
        get { BodyProfileStore.shared.sex }
        set { BodyProfileStore.shared.sex = newValue }
    }

    static var hasHeight: Bool { BodyProfileStore.shared.hasHeight }

    static func formatHeight(_ inches: Double = heightInches) -> String {
        BodyProfileStore.formatHeight(inches)
    }
}
