//
//  AppDefaultsIsolationTests.swift
//  RockLogTests
//
//  The shared store switch: real stores without the UI-test flag, an
//  isolated suite and no iCloud writes with it.
//

import XCTest
@testable import RockLog

final class AppDefaultsIsolationTests: XCTestCase {
    func test_flagOff_usesRealStores() {
        let stores = AppDefaults.make(arguments: ["RockLog"])
        XCTAssertTrue(stores.local === UserDefaults.standard)
        XCTAssertTrue(stores.cloud === NSUbiquitousKeyValueStore.default)
        XCTAssertNil(stores.suiteName)
        XCTAssertFalse(stores.isIsolated)
    }

    func test_flagOn_usesIsolatedSuite_andNeverWritesKVS() throws {
        let key = "rocklog.isolationProbe.\(UUID().uuidString)"
        let stores = AppDefaults.make(arguments: ["RockLog", UITestLaunch.testingArgument])
        defer { AppDefaults.tearDown(stores) }
        XCTAssertTrue(stores.isIsolated)
        XCTAssertFalse(stores.local === UserDefaults.standard)
        let memory = try XCTUnwrap(stores.cloud as? MemoryCloudStore)

        stores.local.set("local", forKey: key)
        stores.cloud.set("cloud", forKey: key)

        XCTAssertEqual(stores.local.string(forKey: key), "local")
        XCTAssertEqual(memory.string(forKey: key), "cloud")
        XCTAssertEqual(memory.writeCount, 1)
        XCTAssertNil(UserDefaults.standard.object(forKey: key), "Isolated write leaked into .standard")
        XCTAssertNil(NSUbiquitousKeyValueStore.default.object(forKey: key), "Isolated write reached iCloud KVS")
    }

    func test_flagOn_eachLaunchStartsEmpty() {
        let key = "rocklog.isolationProbe.\(UUID().uuidString)"
        let first = AppDefaults.make(arguments: [UITestLaunch.testingArgument])
        first.local.set(true, forKey: key)
        AppDefaults.tearDown(first)
        let second = AppDefaults.make(arguments: [UITestLaunch.testingArgument])
        defer { AppDefaults.tearDown(second) }
        XCTAssertNotEqual(first.suiteName, second.suiteName)
        XCTAssertNil(second.local.object(forKey: key))
    }

    func test_unitTestHost_runsWithRealStoreSwitchOff() {
        // The unit-test host launches without -RockLogUITesting.
        XCTAssertFalse(AppDefaults.isIsolated)
    }

    func test_staleSuiteCleanup_neverTouchesStandardOrBundleDomain() throws {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent("prefs-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }
        let bundleID = Bundle.main.bundleIdentifier ?? "com.lee.lift2026"
        let current = AppDefaults.suitePrefix + "CURRENT"
        let stale = AppDefaults.suitePrefix + "OLD"
        for name in [bundleID, ".GlobalPreferences", current, stale, "RockLogUITestNoDash"] {
            try Data("x".utf8).write(to: dir.appendingPathComponent(name + ".plist"))
        }
        let probeKey = "rocklog.cleanupProbe.\(UUID().uuidString)"
        UserDefaults.standard.set("keep", forKey: probeKey)
        defer { UserDefaults.standard.removeObject(forKey: probeKey) }

        XCTAssertEqual(AppDefaults.staleSuiteNames(in: dir, excluding: current), [stale])
        let removed = AppDefaults.pruneStaleSuites(current: current, preferencesDirectory: dir)

        XCTAssertEqual(removed, [stale])
        XCTAssertFalse(removed.contains(bundleID))
        XCTAssertFalse(removed.contains(current))
        XCTAssertFalse(fm.fileExists(atPath: dir.appendingPathComponent(stale + ".plist").path))
        XCTAssertTrue(fm.fileExists(atPath: dir.appendingPathComponent(bundleID + ".plist").path))
        XCTAssertTrue(fm.fileExists(atPath: dir.appendingPathComponent(current + ".plist").path))
        XCTAssertEqual(UserDefaults.standard.string(forKey: probeKey), "keep")
    }
}
