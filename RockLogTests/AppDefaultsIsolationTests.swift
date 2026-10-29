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
}
