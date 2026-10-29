//
//  AppDefaults.swift
//  RockLog
//
//  The one place the app gets its key-value stores. Production uses
//  UserDefaults.standard and iCloud KVS. A `-RockLogUITesting` launch (Debug
//  only) gets a UserDefaults suite unique to that launch plus an in-memory
//  stand-in for iCloud KVS, so UI tests never read leftovers, never clear the
//  tester's real keys, and never write iCloud.
//

import Foundation
import UIKit

/// The subset of `NSUbiquitousKeyValueStore` the app uses.
nonisolated protocol CloudKeyValueStoring: AnyObject {
    func object(forKey key: String) -> Any?
    func string(forKey key: String) -> String?
    func bool(forKey key: String) -> Bool
    func double(forKey key: String) -> Double
    func set(_ value: Any?, forKey key: String)
    func removeObject(forKey key: String)
    @discardableResult func synchronize() -> Bool
}

extension NSUbiquitousKeyValueStore: CloudKeyValueStoring {}

/// In-memory iCloud stand-in for UI-test launches. Nothing leaves the process.
nonisolated final class MemoryCloudStore: CloudKeyValueStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Any] = [:]
    private(set) var writeCount = 0

    func object(forKey key: String) -> Any? { lock.withLock { values[key] } }
    func string(forKey key: String) -> String? { object(forKey: key) as? String }
    func bool(forKey key: String) -> Bool { (object(forKey: key) as? Bool) ?? false }
    func double(forKey key: String) -> Double { (object(forKey: key) as? Double) ?? 0 }
    func set(_ value: Any?, forKey key: String) {
        lock.withLock {
            writeCount += 1
            values[key] = value
        }
    }
    func removeObject(forKey key: String) { lock.withLock { _ = values.removeValue(forKey: key) } }
    func synchronize() -> Bool { true }
}

nonisolated enum AppDefaults {
    static let suitePrefix = "RockLogUITest-"

    struct Stores: @unchecked Sendable {
        let local: UserDefaults
        let cloud: any CloudKeyValueStoring
        /// Set only for an isolated test launch.
        let suiteName: String?
        var isIsolated: Bool { suiteName != nil }
    }

    /// Built once per process from the launch arguments.
    nonisolated(unsafe) static let current: Stores = make(arguments: ProcessInfo.processInfo.arguments)

    static var local: UserDefaults { current.local }
    static var cloud: any CloudKeyValueStoring { current.cloud }
    static var isIsolated: Bool { current.isIsolated }

    static func isTestLaunch(_ arguments: [String]) -> Bool {
        #if DEBUG
        arguments.contains(UITestLaunch.testingArgument)
        #else
        false
        #endif
    }

    static func make(arguments: [String]) -> Stores {
        guard isTestLaunch(arguments) else {
            return Stores(local: .standard, cloud: NSUbiquitousKeyValueStore.default, suiteName: nil)
        }
        let name = suitePrefix + UUID().uuidString
        let suite = UserDefaults(suiteName: name)!
        suite.removePersistentDomain(forName: name)
        let stores = Stores(local: suite, cloud: MemoryCloudStore(), suiteName: name)
        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: nil
        ) { _ in tearDown(stores) }
        return stores
    }

    /// Drops an isolated suite. Never touches `.standard` or iCloud.
    static func tearDown(_ stores: Stores) {
        guard let name = stores.suiteName else { return }
        stores.local.removePersistentDomain(forName: name)
    }
}
