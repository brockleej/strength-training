//
//  RockLogTestHost.swift
//  RockLog
//
//  The unit-test host is the app process. It must not open SwiftData or
//  CloudKit. UI tests are a different process: they launch with
//  `-RockLogUITesting` and get the in-memory store in `UITestLaunch`.
//

import Foundation

enum RockLogTestHost {
    /// Optional explicit flag. `XCTestConfigurationFilePath` is the signal
    /// XCTest sets on the host. UI tests do not set either one on the app.
    static let unitTestingArgument = "-RockLogUnitTesting"

    static var isUnitTestHost: Bool {
        // UI tests launch a separate process with -RockLogUITesting. That
        // process must open the in-memory store, even if a runner environment
        // variable leaked across.
        if UITestLaunch.isEnabled { return false }
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return true
        }
        return ProcessInfo.processInfo.arguments.contains(unitTestingArgument)
    }
}
