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

    // MARK: Item 5 — Machine steps clarity

    func test_machineSteps_pillShowsTheChosenStep() {
        XCTAssertEqual(MachineSteps.pillLabel(for: nil), "Machine steps")
        XCTAssertEqual(MachineSteps.pillLabel(for: .empty), "Machine steps")
        var stack = StackDefinition.empty
        stack.step = 10
        XCTAssertEqual(MachineSteps.pillLabel(for: stack), "Steps 10 lb")
        stack.step = 2.5
        stack.pinUnit = .kilograms
        XCTAssertEqual(MachineSteps.pillLabel(for: stack), "Steps 2.5 kg")
        XCTAssertEqual(MachineSteps.optionLabel(10, unit: .pounds), "Every 10 lb")
        XCTAssertEqual(MachineSteps.optionLabel(2.5, unit: .kilograms), "Every 2.5 kg")
    }

    /// Regression (t277u): picking a step did nothing visible; the shown weight must snap at once.
    func test_regression_pickingAStep_snapsTheShownWeight() {
        let profile = MachineStackProfile(gymID: UUID(), exerciseID: UUID())
        profile.applyTyped(step: 10, pins: [], unit: .pounds)
        XCTAssertEqual(MachineSteps.snappedDisplay(137, unit: .pounds, stack: profile.definition), 140)
        XCTAssertEqual(MachineSteps.snappedDisplay(140, unit: .pounds, stack: profile.definition), 140)
        XCTAssertEqual(MachineSteps.snappedDisplay(137, unit: .pounds, stack: .empty), 137)
        profile.applyTyped(step: 5, pins: [], unit: .kilograms)
        XCTAssertEqual(MachineSteps.snappedDisplay(52, unit: .kilograms, stack: profile.definition), 50, accuracy: 0.26)
    }

    func test_noMachineSteps_turnsTheStackOff() {
        let profile = MachineStackProfile(gymID: UUID(), exerciseID: UUID())
        profile.applyTyped(step: 10, pins: [], unit: .pounds)
        profile.applyTyped(step: nil, pins: [], unit: .pounds)
        XCTAssertFalse(profile.definition.isActive)
    }

    // MARK: Item 6 — load pill names the mode

    func test_loadPill_namesTheActiveMode() {
        XCTAssertEqual(LoadMode.bar.pillLabel, "Load: Total")
        XCTAssertEqual(LoadMode.assist.pillLabel, "Load: Assist")
        XCTAssertEqual(LoadMode.added.pillLabel, "Load: Added")
        XCTAssertEqual(Set(LoadMode.allCases.map(\.menuLabel)).count, 3)
        // Stored raw values are unchanged so old sets still decode.
        XCTAssertEqual(LoadMode(stored: "bar", isAssisted: false), .bar)
    }
}
