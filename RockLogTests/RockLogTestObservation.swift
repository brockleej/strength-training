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
        let label = Self.rlDiagLabel(testCase)
        WorkoutViewModel.diagnosticTestName = label
        print("[RLDIAG] test start \(label)")
        #else
        _ = testCase
        #endif
    }

    func testCaseDidFinish(_ testCase: XCTestCase) {
        #if DEBUG
        print("[RLDIAG] test end \(Self.rlDiagLabel(testCase))")
        #else
        _ = testCase
        #endif
    }

    #if DEBUG
    /// `XCTestCase.name` is `-[WorkoutSessionLogicTests test_starterExtras_stepApplySnapshot]`.
    /// The method token is repeated so a log search shows whether that test ran.
    private static func rlDiagLabel(_ testCase: XCTestCase) -> String {
        let reported = testCase.name
        let method = rlDiagMethod(from: reported)
        guard !method.isEmpty, method != reported else { return reported }
        return "\(reported) method=\(method)"
    }

    private static func rlDiagMethod(from reported: String) -> String {
        guard let space = reported.lastIndex(of: " ") else { return "" }
        var method = String(reported[reported.index(after: space)...])
        if method.hasSuffix("]") {
            method.removeLast()
        }
        return method
    }
    #endif
}
