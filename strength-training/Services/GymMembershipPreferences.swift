//
//  GymMembershipPreferences.swift
//  strength-training
//
//  Gym check-in code for the barcode pass.
//  Local UserDefaults + NSUbiquitousKeyValueStore so the pass survives
//  reinstall and follows the user’s iCloud account across devices.
//

import Foundation
import Observation

@Observable
final class GymMembershipStore {
    static let shared = GymMembershipStore()

    static let codeKey = "gymMembershipCode"
    static let labelKey = "gymMembershipLabel"
    static let formatKey = "gymMembershipFormat"
    static let defaultLabel = "Gym membership"

    var code: String = "" {
        didSet { persistIfNeeded(code, key: Self.codeKey, old: oldValue) }
    }
    var label: String = "" {
        didSet { persistIfNeeded(label, key: Self.labelKey, old: oldValue) }
    }
    var formatRaw: String = Format.code128.rawValue {
        didSet { persistIfNeeded(formatRaw, key: Self.formatKey, old: oldValue) }
    }

    var format: Format {
        get { Format(rawValue: formatRaw) ?? .code128 }
        set { formatRaw = newValue.rawValue }
    }

    var displayLabel: String {
        let t = label.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? Self.defaultLabel : t
    }

    var isConfigured: Bool {
        !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isApplyingRemote = false
    private var kvsObserver: NSObjectProtocol?

    enum Format: String, CaseIterable, Identifiable {
        case code128 = "code128"
        case qr = "qr"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .code128: "Barcode (Code 128)"
            case .qr: "QR code"
            }
        }

        var detail: String {
            switch self {
            case .code128: "Horizontal barcode most scanners expect"
            case .qr: "Square QR — some apps / kiosks use this"
            }
        }
    }

    private init() {
        loadMerged()
        kvsObserver = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default,
            queue: .main
        ) { [weak self] note in
            self?.applyExternalChange(note)
        }
        // Values arrive later via didChangeExternally — do not call synchronize()
        // here; it blocks the main thread on first launch.
    }

    deinit {
        if let kvsObserver {
            NotificationCenter.default.removeObserver(kvsObserver)
        }
    }

    /// Call on launch (and after iCloud becomes available) to pull remote values.
    func hydrateFromICloud() {
        loadMerged()
    }

    // MARK: - Load / save

    private func loadMerged() {
        isApplyingRemote = true
        defer { isApplyingRemote = false }

        let defaults = UserDefaults.standard
        let kvs = NSUbiquitousKeyValueStore.default

        // Prefer non-empty iCloud value so reinstall recovers the pass.
        code = firstNonEmpty(
            kvs.string(forKey: Self.codeKey),
            defaults.string(forKey: Self.codeKey)
        ) ?? ""
        label = firstNonEmpty(
            kvs.string(forKey: Self.labelKey),
            defaults.string(forKey: Self.labelKey)
        ) ?? ""
        let formatCandidate = firstNonEmpty(
            kvs.string(forKey: Self.formatKey),
            defaults.string(forKey: Self.formatKey)
        )
        formatRaw = Format(rawValue: formatCandidate ?? "")?.rawValue ?? Format.code128.rawValue

        // Push local-only values up so a phone that never synced still backs up.
        persistAll()
    }

    private func applyExternalChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reason = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int
        else {
            loadMerged()
            return
        }
        // Ignore account change wipe unless we want to clear — still reload.
        _ = reason
        if let keys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] {
            let ours: Set<String> = [Self.codeKey, Self.labelKey, Self.formatKey]
            guard keys.contains(where: { ours.contains($0) }) else { return }
        }
        loadMerged()
    }

    private func persistIfNeeded(_ value: String, key: String, old: String) {
        guard !isApplyingRemote, value != old else { return }
        UserDefaults.standard.set(value, forKey: key)
        NSUbiquitousKeyValueStore.default.set(value, forKey: key)
    }

    private func persistAll() {
        let defaults = UserDefaults.standard
        let kvs = NSUbiquitousKeyValueStore.default
        defaults.set(code, forKey: Self.codeKey)
        defaults.set(label, forKey: Self.labelKey)
        defaults.set(formatRaw, forKey: Self.formatKey)
        kvs.set(code, forKey: Self.codeKey)
        kvs.set(label, forKey: Self.labelKey)
        kvs.set(formatRaw, forKey: Self.formatKey)
    }

    private func firstNonEmpty(_ a: String?, _ b: String?) -> String? {
        let ta = a?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !ta.isEmpty { return a }
        let tb = b?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !tb.isEmpty { return b }
        return nil
    }
}

/// Compatibility façade used by barcode generation and simple reads.
enum GymMembershipPreferences {
    static let codeKey = GymMembershipStore.codeKey
    static let labelKey = GymMembershipStore.labelKey
    static let formatKey = GymMembershipStore.formatKey
    static let defaultLabel = GymMembershipStore.defaultLabel

    typealias Format = GymMembershipStore.Format

    static var code: String { GymMembershipStore.shared.code }
    static var label: String { GymMembershipStore.shared.displayLabel }
    static var format: Format { GymMembershipStore.shared.format }
    static var isConfigured: Bool { GymMembershipStore.shared.isConfigured }
}
