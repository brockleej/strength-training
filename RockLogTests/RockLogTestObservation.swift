//
//  RockLogTestObservation.swift
//  RockLogTests
//

import XCTest
#if DEBUG
@testable import RockLog
#endif

/// Records the running test so deferred saves can print it, and logs each test's edges.
/// The test bundle lists this as its principal class, so `init` runs before the first test.
@objc(RockLogTestObservation)
final class RockLogTestObservation: NSObject, XCTestObservation {
    private static var retained: RockLogTestObservation?

    override init() {
        super.init()
        Self.install(self)
    }

    /// Backup for a run that did not instantiate the principal class.
    static func installIfNeeded() {
        guard retained == nil else { return }
        _ = RockLogTestObservation()
    }

    private static func install(_ observer: RockLogTestObservation) {
        guard retained == nil else { return }
        retained = observer
        XCTestObservationCenter.shared.addTestObserver(observer)
    }

    func testCaseWillStart(_ testCase: XCTestCase) {
        #if DEBUG
        let name = testCase.name
        WorkoutViewModel.diagnosticTestName = name
        print("[RLDIAG] test start \(name)")
        #else
        _ = testCase
        #endif
    }

    func testCaseDidFinish(_ testCase: XCTestCase) {
        #if DEBUG
        print("[RLDIAG] test end \(testCase.name)")
        #else
        _ = testCase
        #endif
    }
}
