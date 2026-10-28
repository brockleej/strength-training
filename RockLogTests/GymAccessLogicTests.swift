//
//  GymAccessLogicTests.swift
//  RockLogTests
//
//  Nearest-gym choice, barcode modules, and the app-open fallback.
//  Synthetic coordinates only.
//

import XCTest
@testable import RockLog

final class GymAccessLogicTests: XCTestCase {
    func test_oneGym_isUsedWithoutLocation() {
        let only = place("UI Gym", lat: nil, lon: nil, isDefault: true)
        let chosen = GymAccessChoice.select(entries: [only], location: GeoPoint(latitude: 0, longitude: 0), pinnedID: nil)
        XCTAssertEqual(chosen, only)
    }

    func test_nearestWithin150m_winsOverTheDefault() {
        let home = place("Home", lat: 37.0000, lon: -122.0000, isDefault: true)
        let nearby = place("Nearby", lat: 37.0010, lon: -122.0000, isDefault: false)
        let here = GeoPoint(latitude: 37.0010, longitude: -122.0000)
        XCTAssertLessThan(GymAccessChoice.meters(from: here, to: nearby.coordinate!), 150)
        let chosen = GymAccessChoice.select(entries: [home, nearby], location: here, pinnedID: nil)
        XCTAssertEqual(chosen?.name, "Nearby")
    }

    func test_fartherThan150m_usesTheDefault() {
        let home = place("Home", lat: 37.0000, lon: -122.0000, isDefault: true)
        let far = place("Far", lat: 37.0100, lon: -122.0000, isDefault: false)
        let here = GeoPoint(latitude: 37.0000, longitude: -122.0000)
        XCTAssertGreaterThan(GymAccessChoice.meters(from: here, to: far.coordinate!), 150)
        let chosen = GymAccessChoice.select(entries: [home, far], location: here, pinnedID: nil)
        XCTAssertEqual(chosen?.name, "Home")
    }

    func test_noLocation_usesTheDefault_andAPinOverridesIt() {
        let home = place("Home", lat: 37, lon: -122, isDefault: true)
        let other = place("Other", lat: 38, lon: -122, isDefault: false)
        XCTAssertEqual(
            GymAccessChoice.select(entries: [home, other], location: nil, pinnedID: nil)?.name,
            "Home"
        )
        XCTAssertEqual(
            GymAccessChoice.select(entries: [home, other], location: nil, pinnedID: other.id)?.name,
            "Other"
        )
    }

    func test_boundary150m_isIncluded() {
        let origin = GeoPoint(latitude: 0, longitude: 0)
        let north = GeoPoint(latitude: 140 / 111_320, longitude: 0)
        let distance = GymAccessChoice.meters(from: origin, to: north)
        XCTAssertLessThanOrEqual(distance, GymAccessChoice.nearMeters)
        XCTAssertGreaterThan(distance, 100)
        let gym = place("Edge", lat: north.latitude, lon: 0, isDefault: false)
        let home = place("Home", lat: 10, lon: 10, isDefault: true)
        XCTAssertEqual(
            GymAccessChoice.select(entries: [home, gym], location: origin, pinnedID: nil)?.name,
            "Edge"
        )
    }

    func test_code39_wrapsWithStartAndStop_andRejectsUnknownCharacters() {
        let modules = BarcodeModules.code39("A1")
        XCTAssertNotNil(modules)
        XCTAssertTrue(modules?.hasPrefix("100010111011101") == true)
        XCTAssertTrue(modules?.hasSuffix("100010111011101") == true)
        XCTAssertNil(BarcodeModules.code39("a!"))
        XCTAssertNil(BarcodeModules.code39(" "))
        XCTAssertNil(BarcodeModules.code39(""))
    }

    func test_ean13_checkDigit_andRejectsABadCode() {
        XCTAssertEqual(BarcodeModules.ean13CheckDigit(twelve: "400638133393"), 1)
        XCTAssertNotNil(BarcodeModules.ean13("400638133393"))
        XCTAssertNotNil(BarcodeModules.ean13("4006381333931"))
        XCTAssertNil(BarcodeModules.ean13("4006381333932"))
        XCTAssertNil(BarcodeModules.ean13("123"))
    }

    func test_appOpen_fallsBackToTheStoreWhenTheSchemeCannotOpen() {
        let app = URL(string: "kisi://")!
        let store = URL(string: "https://apps.apple.com/app/kisi/id687291321")!
        XCTAssertEqual(GymAppLaunchPlan.plan(openURL: app, appStoreURL: store, canOpen: { _ in true }), .open(app))
        XCTAssertEqual(GymAppLaunchPlan.plan(openURL: app, appStoreURL: store, canOpen: { _ in false }), .appStore(store))
        XCTAssertNil(GymAppLaunchPlan.plan(openURL: app, appStoreURL: nil, canOpen: { _ in false }))
        XCTAssertEqual(GymAppPreset.kisi.appStoreURL, store)
    }

    func test_legacyBarcode_becomesTheDefaultGymOnce() {
        let migrated = GymAccessCodec.migratingLegacy(
            entries: [],
            code: "12345",
            label: "Synthetic Gym",
            formatRaw: "qr"
        )
        XCTAssertEqual(migrated.count, 1)
        XCTAssertEqual(migrated[0].name, "Synthetic Gym")
        XCTAssertEqual(migrated[0].barcodePayload, "12345")
        XCTAssertEqual(migrated[0].symbology, .qr)
        XCTAssertTrue(migrated[0].isDefault)
        XCTAssertEqual(
            GymAccessCodec.migratingLegacy(entries: migrated, code: "999", label: "Other", formatRaw: "code128").count,
            1
        )
    }

    private func place(_ name: String, lat: Double?, lon: Double?, isDefault: Bool) -> GymAccessEntry {
        GymAccessEntry(
            id: UUID(),
            name: name,
            latitude: lat,
            longitude: lon,
            isDefault: isDefault,
            method: .barcode,
            barcodePayload: "12345",
            symbology: .code128,
            appPreset: .custom,
            appOpenURL: "",
            appStoreURL: "",
            linkURL: ""
        )
    }
}
