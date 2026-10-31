//
//  NextBuildFixesTests.swift
//  RockLogTests
//
//  RockLog 1.2 fixes from Lee's 1.1 (1) test pass. Synthetic values only.
//

import XCTest
import SwiftData
@testable import RockLog

final class NextBuildFixesTests: XCTestCase {

    // MARK: Item 2 — Stack menu respects kg

    func test_machineStepOptions_followTheUnit() {
        XCTAssertEqual(MachineSteps.options(for: .pounds), [5, 10, 15, 20])
        XCTAssertEqual(MachineSteps.options(for: .kilograms), [2.5, 5, 10])
    }

    /// Regression (1.1 (1)): in kg mode the menu offered 5/10/15/20, which stored 15 and 20 kg steps.
    func test_regression_kgStackStep_isStoredInKilograms_andSnapsOnTheKgGrid() {
        let profile = MachineStackProfile(gymID: UUID(), exerciseID: UUID())
        profile.applyTyped(step: 2.5, pins: [], unit: .kilograms)
        XCTAssertEqual(profile.definition.step, 2.5)
        XCTAssertEqual(profile.definition.pinUnit, .kilograms)
        XCTAssertFalse(MachineSteps.options(for: .kilograms).contains(20))
        // 41 kg target lands on 40 or 42.5 kg, never a pound step.
        let target = MassMath.pounds(fromDisplay: 41, unit: .kilograms)
        let offer = StackMath.snap(weightPounds: target, reps: 10, stack: profile.definition)
        let shownKg = MassMath.exactDisplay(fromPounds: offer.weightPounds, unit: .kilograms)
        XCTAssertEqual((shownKg / 2.5).rounded() * 2.5, shownKg, accuracy: 0.001)
    }

    // MARK: Item 3 — 5 kg weight step

    func test_kgStepperCycle_includesFive_andStillStartsOnTwoPointFive() {
        XCTAssertEqual(MassUnit.kilograms.stepperSteps, [5, 2.5, 1, 0.5])
        XCTAssertEqual(MassUnit.kilograms.defaultStepperStep, 2.5)
        XCTAssertEqual(MassUnit.pounds.stepperSteps, [5, 1, 0.5])
        XCTAssertEqual(MassUnit.pounds.defaultStepperStep, 5)
        for unit in MassUnit.allCases {
            XCTAssertTrue(unit.stepperSteps.contains(unit.defaultStepperStep))
        }
    }

    // MARK: Item 4 — plate-math line

    func test_plateLine_showsOnlyForPlainBarTotals() {
        var stack = StackDefinition.empty
        XCTAssertTrue(PlateLinePolicy.shows(isAssisted: false, loadMode: .bar, stack: nil))
        XCTAssertTrue(PlateLinePolicy.shows(isAssisted: false, loadMode: .bar, stack: stack))
        XCTAssertFalse(PlateLinePolicy.shows(isAssisted: true, loadMode: .bar, stack: nil))
        XCTAssertFalse(PlateLinePolicy.shows(isAssisted: false, loadMode: .assist, stack: nil))
        XCTAssertFalse(PlateLinePolicy.shows(isAssisted: false, loadMode: .added, stack: nil))
        stack.step = 10
        XCTAssertFalse(PlateLinePolicy.shows(isAssisted: false, loadMode: .bar, stack: stack))
    }

    /// Regression: the plate line converted an already-displayed kg number as if it were pounds.
    func test_regression_kgPlateLine_usesTheDisplayedKgTotal() {
        let readout = PlateLinePolicy.readout(displayedWeight: 60, unit: .kilograms)
        XCTAssertEqual(readout.bar, 20)
        XCTAssertEqual(readout.platesPerSide, [20])
        XCTAssertEqual(PlateLinePolicy.readout(displayedWeight: 135, unit: .pounds).platesPerSide, [45])
    }
}
