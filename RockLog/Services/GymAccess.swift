//
//  GymAccess.swift
//  RockLog
//
//  Check-in places for the single Today button. One saved place is used as-is.
//  Several places use the nearest within 150 m when a one-shot location exists,
//  and the default place otherwise. Nothing here requests location.
//

import Foundation

nonisolated enum GymAccessMethod: String, Codable, CaseIterable, Identifiable, Sendable {
    case barcode
    case openApp
    case link

    var id: String { rawValue }

    var title: String {
        switch self {
        case .barcode: "Barcode"
        case .openApp: "Open app"
        case .link: "Link"
        }
    }
}

nonisolated enum BarcodeSymbology: String, Codable, CaseIterable, Identifiable, Sendable {
    case code128
    case qr
    case pdf417
    case aztec
    case code39
    case ean13

    var id: String { rawValue }

    var title: String {
        switch self {
        case .code128: "Code 128"
        case .qr: "QR"
        case .pdf417: "PDF417"
        case .aztec: "Aztec"
        case .code39: "Code 39"
        case .ean13: "EAN-13"
        }
    }

    /// Core Image draws these. Code 39 and EAN-13 use BarcodeModules.
    var usesCoreImage: Bool {
        switch self {
        case .code128, .qr, .pdf417, .aztec: true
        case .code39, .ean13: false
        }
    }
}

nonisolated enum GymAppPreset: String, Codable, CaseIterable, Identifiable, Sendable {
    case kisi
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .kisi: "Kisi"
        case .custom: "Custom"
        }
    }

    /// Public app URL. There is no Kisi SDK.
    var openURL: URL? {
        switch self {
        case .kisi: URL(string: "kisi://")
        case .custom: nil
        }
    }

    /// App Store page used when the app is not installed.
    var appStoreURL: URL? {
        switch self {
        case .kisi: URL(string: "https://apps.apple.com/app/kisi/id687291321")
        case .custom: nil
        }
    }
}

nonisolated enum GymAppLaunch: Equatable, Sendable {
    case open(URL)
    case appStore(URL)
}

nonisolated enum GymAppLaunchPlan {
    /// Prefer the app when `canOpen` says the scheme is allowed. Otherwise the store link.
    static func plan(openURL: URL?, appStoreURL: URL?, canOpen: (URL) -> Bool) -> GymAppLaunch? {
        if let openURL, canOpen(openURL) {
            return .open(openURL)
        }
        guard let appStoreURL else { return nil }
        return .appStore(appStoreURL)
    }
}

nonisolated struct GymAccessEntry: Codable, Identifiable, Equatable, Hashable, Sendable {
    var id: UUID
    var name: String
    var latitude: Double?
    var longitude: Double?
    var isDefault: Bool
    var method: GymAccessMethod
    var barcodePayload: String
    var symbology: BarcodeSymbology
    var appPreset: GymAppPreset
    var appOpenURL: String
    var appStoreURL: String
    var linkURL: String

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var coordinate: GeoPoint? {
        guard let latitude, let longitude else { return nil }
        return GeoPoint(latitude: latitude, longitude: longitude)
    }

    /// Barcode stays in the app. App and link leave it. `canOpen` is `UIApplication.shared.canOpenURL`.
    func externalURL(canOpen: (URL) -> Bool) -> URL? {
        switch method {
        case .barcode:
            return nil
        case .link:
            return URL(string: linkURL.trimmingCharacters(in: .whitespacesAndNewlines))
        case .openApp:
            let open = appPreset.openURL ?? URL(string: appOpenURL.trimmingCharacters(in: .whitespacesAndNewlines))
            let store = appPreset.appStoreURL ?? URL(string: appStoreURL.trimmingCharacters(in: .whitespacesAndNewlines))
            switch GymAppLaunchPlan.plan(openURL: open, appStoreURL: store, canOpen: canOpen) {
            case .open(let url), .appStore(let url):
                return url
            case nil:
                return nil
            }
        }
    }
}

nonisolated struct GeoPoint: Equatable, Sendable {
    var latitude: Double
    var longitude: Double
}

nonisolated enum GymAccessChoice {
    /// About 150 m. A gym farther than this is not "here".
    static let nearMeters = 150.0

    /// One saved gym is that gym. Several use the nearest within `nearMeters`
    /// when `location` is present. No location, or nothing nearby, uses the
    /// long-press pin when it still exists, then the default.
    static func select(
        entries: [GymAccessEntry],
        location: GeoPoint?,
        pinnedID: UUID?
    ) -> GymAccessEntry? {
        let saved = entries.filter { !$0.trimmedName.isEmpty }
        guard let first = saved.first else { return nil }
        if saved.count == 1 { return first }
        if let location,
           let nearest = nearest(in: saved, to: location, within: nearMeters) {
            return nearest
        }
        if let pinnedID, let pinned = saved.first(where: { $0.id == pinnedID }) {
            return pinned
        }
        return saved.first(where: \.isDefault) ?? first
    }

    static func nearest(
        in entries: [GymAccessEntry],
        to location: GeoPoint,
        within meters: Double
    ) -> GymAccessEntry? {
        entries
            .compactMap { entry -> (GymAccessEntry, Double)? in
                guard let coordinate = entry.coordinate else { return nil }
                let distance = Self.meters(from: location, to: coordinate)
                guard distance <= meters else { return nil }
                return (entry, distance)
            }
            .min { $0.1 < $1.1 }?
            .0
    }

    static func meters(from: GeoPoint, to: GeoPoint) -> Double {
        let earth = 6_371_000.0
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let dLat = (to.latitude - from.latitude) * .pi / 180
        let dLon = (to.longitude - from.longitude) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * earth * asin(min(1, sqrt(a)))
    }
}

nonisolated enum GymAccessCodec {
    static func decode(_ data: Data) -> [GymAccessEntry] {
        (try? JSONDecoder().decode([GymAccessEntry].self, from: data)) ?? []
    }

    static func encode(_ entries: [GymAccessEntry]) -> Data {
        (try? JSONEncoder().encode(entries)) ?? Data()
    }

    /// The old single Settings barcode becomes the default place once.
    static func migratingLegacy(
        entries: [GymAccessEntry],
        code: String,
        label: String,
        formatRaw: String
    ) -> [GymAccessEntry] {
        if !entries.isEmpty { return entries }
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let symbology: BarcodeSymbology = formatRaw == "qr" ? .qr : .code128
        let name = label.trimmingCharacters(in: .whitespacesAndNewlines)
        return [
            GymAccessEntry(
                id: UUID(),
                name: name.isEmpty ? "Gym membership" : name,
                latitude: nil,
                longitude: nil,
                isDefault: true,
                method: .barcode,
                barcodePayload: trimmed,
                symbology: symbology,
                appPreset: .custom,
                appOpenURL: "",
                appStoreURL: "",
                linkURL: ""
            ),
        ]
    }
}
