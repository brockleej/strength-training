//
//  Build122Tests.swift
//  RockLogTests
//
//  1.2.2 items from Lee's notes (Nov 14 and Nov 19 2026): A/B on What's Next,
//  a way back into a lift after Done, and per-machine weight increments.
//  Synthetic fixtures only — no personal workout history.
//

import XCTest
import SwiftData
@testable import RockLog

@MainActor
final class Build122Tests: RockLogStoreTestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        MassUnitPreferences.useIsolatedUnit(.pounds)
    }

    // MARK: - What's Next shows the A/B week (Nov 14)

    func test_trackedDayTitle_addsTheWeek() {
        XCTAssertEqual(PlannedBlockQueue.trackedDayTitle(dayName: "Lower", track: .a), "Lower A")
        XCTAssertEqual(PlannedBlockQueue.trackedDayTitle(dayName: "Upper", track: .b), "Upper B")
        XCTAssertEqual(PlannedBlockQueue.trackedDayTitle(dayName: "Push", track: .every), "Push")
    }

    func test_plannedRow_titleUsesTheSessionsOwnTrack() {
        let a = PlannedWorkoutsCard.Row(id: UUID(), dayType: .lower, liftCount: 5, isNext: true, track: .a)
        let b = PlannedWorkoutsCard.Row(id: UUID(), dayType: .upper, liftCount: 5, isNext: false, track: .b)
        let plain = PlannedWorkoutsCard.Row(id: UUID(), dayType: .push, liftCount: 5, isNext: false)
        XCTAssertEqual(a.title, "Lower A")
        XCTAssertEqual(b.title, "Upper B")
        XCTAssertEqual(plain.title, "Push")
    }

    func test_importedBSession_keepsBForTheQueueLabel() throws {
        let document = programDocument(track: "B", exercises: [exercise("Demo Leg Press", sets: [200])])
        _ = try ProgramImportService.importDocument(document, context: container.mainContext)
        let session = try XCTUnwrap(container.mainContext.fetch(FetchDescriptor<WorkoutSession>()).first)
        XCTAssertEqual(PlannedBlockQueue.trackedDayTitle(dayName: session.day.rawValue, track: session.track), "Lower B")
    }

    // MARK: - Rounding to a machine increment (Nov 19)

    func test_rounding_toTheIncrement() {
        XCTAssertEqual(MachineIncrement.rounded(147, toStep: 10), 150)
        XCTAssertEqual(MachineIncrement.rounded(145, toStep: 10), 140, "A tie rounds down")
        XCTAssertEqual(MachineIncrement.rounded(52, toStep: 15), 45)
        XCTAssertEqual(MachineIncrement.rounded(53, toStep: 15), 60)
        XCTAssertEqual(MachineIncrement.rounded(100, toStep: 15), 105)
        XCTAssertEqual(MachineIncrement.rounded(90, toStep: 15), 90)
        XCTAssertEqual(MachineIncrement.rounded(3, toStep: 10), 10, "A real weight never rounds to 0")
        XCTAssertEqual(MachineIncrement.rounded(0, toStep: 10), 0)
        XCTAssertEqual(MachineIncrement.rounded(47.5, toStep: 2.5), 47.5)
        XCTAssertEqual(MachineIncrement.rounded(123, toStep: 0), 123, "No step: unchanged")
    }

    func test_incrementBounds() {
        XCTAssertTrue(MachineIncrement.isValid(10))
        XCTAssertTrue(MachineIncrement.isValid(15))
        XCTAssertTrue(MachineIncrement.isValid(2.5))
        XCTAssertFalse(MachineIncrement.isValid(0))
        XCTAssertFalse(MachineIncrement.isValid(-5))
        XCTAssertFalse(MachineIncrement.isValid(101))
        XCTAssertFalse(MachineIncrement.isValid(.nan))
        XCTAssertFalse(MachineIncrement.isValid(.infinity))
    }

    // MARK: - The stepper moves by the machine step

    func test_stepCycle_startsOnTheMachineStep() {
        XCTAssertEqual(FocusViewModel.stepCycle(machineStep: 15, unit: .pounds), [15, 5, 1, 0.5])
        XCTAssertEqual(FocusViewModel.stepCycle(machineStep: 10, unit: .pounds), [10, 5, 1, 0.5])
        XCTAssertEqual(FocusViewModel.stepCycle(machineStep: 5, unit: .pounds), [5, 1, 0.5])
        XCTAssertEqual(FocusViewModel.stepCycle(machineStep: nil, unit: .pounds), [5, 1, 0.5])
        XCTAssertEqual(FocusViewModel.stepCycle(machineStep: 2.5, unit: .kilograms), [2.5, 1, 0.5])
    }

    func test_stepperStep_fromTheStack() {
        var stack = StackDefinition.empty
        XCTAssertNil(MachineSteps.stepperStep(for: nil, unit: .pounds))
        XCTAssertNil(MachineSteps.stepperStep(for: stack, unit: .pounds))
        stack.step = 15
        XCTAssertEqual(MachineSteps.stepperStep(for: stack, unit: .pounds), 15)
        stack.pins = [10, 25, 40]
        XCTAssertNil(MachineSteps.stepperStep(for: stack, unit: .pounds), "A pin list keeps the normal stepper")
        var kg = StackDefinition.empty
        kg.step = 5
        kg.pinUnit = .kilograms
        XCTAssertEqual(MachineSteps.stepperStep(for: kg, unit: .kilograms), 5)
        XCTAssertEqual(try XCTUnwrap(MachineSteps.stepperStep(for: kg, unit: .pounds)), 11.02, accuracy: 0.01)
    }

    func test_focusViewModel_adoptsMachineStep_andCyclesBack() {
        let vm = FocusViewModel(prefill: .init(weight: 105, reps: 10, weightDelta: nil, repsDelta: nil))
        XCTAssertEqual(vm.weightStep, 5)
        vm.adoptMachineStep(15)
        XCTAssertEqual(vm.weightStep, 15)
        vm.cycleWeightStep()
        XCTAssertEqual(vm.weightStep, 5)
        vm.cycleWeightStep()
        vm.cycleWeightStep()
        XCTAssertEqual(vm.weightStep, 0.5)
        vm.cycleWeightStep()
        XCTAssertEqual(vm.weightStep, 15, "Back around to the machine step")
        XCTAssertEqual(vm.weight, 105, "Weight stays a real stack weight")
        vm.adoptMachineStep(nil)
        XCTAssertEqual(vm.weightStep, 5)
    }

    // MARK: - .rocklogprogram carries the increment

    func test_oldFileWithoutIncrement_stillImports() throws {
        let json = """
        {"format":"rocklog.program","schemaVersion":1,"exportedAt":"2026-11-01T00:00:00Z",
         "block":{"id":"\(UUID().uuidString)","name":"Synthetic Old Block","startDate":"2026-11-02",
          "sessions":[{"id":"\(UUID().uuidString)","date":"2026-11-02","dayType":"Lower","rotationTrack":"A",
           "exercises":[{"id":"\(UUID().uuidString)","name":"Demo Leg Extension","sets":[{"setNumber":1,"weightLbs":52,"reps":10}]}]}]}}
        """
        let document = try ProgramCodec.decode(Data(json.utf8))
        XCTAssertNil(document.block.sessions[0].exercises[0].weightIncrementLbs)
        let result = try ProgramImportService.importDocument(document, context: container.mainContext)
        XCTAssertEqual(result.summary.machineStepsSet, 0)
        XCTAssertEqual(plannedWeights("Demo Leg Extension"), [52], "No increment: weights stay as written")
        let lift = try XCTUnwrap(liftNamed("Demo Leg Extension"))
        XCTAssertNil(StackProfileStore.resolved(exerciseID: lift.id, in: container.mainContext))
    }

    func test_encode_writesIncrementOnlyWhenSet() throws {
        let with = programDocument(exercises: [exercise("Demo Leg Extension", sets: [45], increment: 15)])
        let without = programDocument(exercises: [exercise("Demo Bench", sets: [135])])
        let withText = String(decoding: try ProgramCodec.encode(with), as: UTF8.self)
        let withoutText = String(decoding: try ProgramCodec.encode(without), as: UTF8.self)
        XCTAssertTrue(withText.contains("\"weightIncrementLbs\" : 15"), withText)
        XCTAssertFalse(withoutText.contains("weightIncrementLbs"))
    }

    func test_import_setsHomeStep_andRoundsTargets() throws {
        let document = programDocument(exercises: [
            exercise("Demo Leg Extension", sets: [52, 100], increment: 15),
            exercise("Demo Kneeling Hamstring Curl", sets: [47, 65], increment: 10),
        ])
        let result = try ProgramImportService.importDocument(document, context: container.mainContext)
        XCTAssertEqual(result.summary.machineStepsSet, 2)
        XCTAssertEqual(plannedWeights("Demo Leg Extension"), [45, 105])
        XCTAssertEqual(plannedWeights("Demo Kneeling Hamstring Curl"), [50, 60], "65 is a tie on a 10 lb stack: down")
        let leg = try XCTUnwrap(liftNamed("Demo Leg Extension"))
        let ham = try XCTUnwrap(liftNamed("Demo Kneeling Hamstring Curl"))
        XCTAssertEqual(StackProfileStore.resolved(exerciseID: leg.id, in: container.mainContext)?.step, 15)
        XCTAssertEqual(StackProfileStore.resolved(exerciseID: ham.id, in: container.mainContext)?.step, 10)
        XCTAssertEqual(StackProfileStore.resolved(exerciseID: leg.id, in: container.mainContext)?.origin, .typed)
        XCTAssertTrue(ProgramImportService.resultMessage(summary: result.summary, replacedSplit: false)
            .contains("Machine steps set for 2 lifts"))
    }

    func test_import_keepsAStepHePickedOnThePhone() throws {
        let context = container.mainContext
        let lift = Exercise.make(name: "Demo Leg Extension", dayType: nil, muscleGroup: "Quads", isCustom: true)
        context.insert(lift)
        let home = GymLibrary.ensureHome(in: context)
        StackProfileStore.findOrCreate(gymID: home.id, exerciseID: lift.id, in: context)
            .applyTyped(step: 20, pins: [], unit: .pounds)
        try context.save()

        let document = programDocument(exercises: [exercise("Demo Leg Extension", id: lift.id, sets: [60], increment: 15)])
        let result = try ProgramImportService.importDocument(document, context: context)
        XCTAssertEqual(result.summary.machineStepsSet, 0)
        XCTAssertEqual(result.summary.machineStepsKept, 1)
        XCTAssertEqual(StackProfileStore.resolved(exerciseID: lift.id, in: context)?.step, 20)
    }

    func test_import_rejectsABadIncrement() {
        for bad in [0.0, -10, 150] {
            let document = programDocument(exercises: [exercise("Demo Leg Extension", sets: [45], increment: bad)])
            XCTAssertThrowsError(try ProgramCodec.decode(try ProgramCodec.encode(document))) { error in
                guard case ProgramDocument.ProgramFormatError.weightIncrementOutOfRange = error else {
                    return XCTFail("expected weightIncrementOutOfRange for \(bad), got \(error)")
                }
            }
        }
    }

    func test_programExportImport_roundTripKeepsIncrementsTracksAndTargets() throws {
        let document = programDocument(track: "B", exercises: [
            exercise("Demo Leg Extension", sets: [45, 60], increment: 15),
            exercise("Demo Kneeling Hamstring Curl", sets: [50], increment: 10),
            exercise("Demo Barbell Row", sets: [135]),
        ])
        let imported = try ProgramImportService.importDocument(document, context: container.mainContext)

        let data = try XCTUnwrap(try ProgramExportService.data(blockID: imported.blockID, context: container.mainContext))
        let exported = try ProgramCodec.decode(data)
        let lifts = exported.block.sessions[0].exercises
        XCTAssertEqual(exported.block.sessions[0].rotationTrack, "B")
        XCTAssertEqual(lifts.map(\.name), ["Demo Leg Extension", "Demo Kneeling Hamstring Curl", "Demo Barbell Row"])
        XCTAssertEqual(lifts.map(\.weightIncrementLbs), [15, 10, nil])
        XCTAssertEqual(lifts.map { $0.sets.map(\.weightLbs) }, [[45, 60], [50], [135]])

        // Into a second phone: the same steps and targets.
        try openSecondaryContainer()
        let other = try XCTUnwrap(secondaryContainer).mainContext
        let again = try ProgramImportService.importDocument(exported, context: other)
        XCTAssertEqual(again.summary.machineStepsSet, 2)
        let leg = try XCTUnwrap(try other.fetch(FetchDescriptor<Exercise>()).first { $0.name == "Demo Leg Extension" })
        XCTAssertEqual(StackProfileStore.resolved(exerciseID: leg.id, in: other)?.step, 15)
        let session = try XCTUnwrap(try other.fetch(FetchDescriptor<WorkoutSession>()).first)
        XCTAssertEqual(session.track, .b)
    }

    // MARK: - Backup carries the step

    func test_backupRoundTrip_keepsTheMachineStep() throws {
        let context = container.mainContext
        let lift = Exercise.make(name: "Demo Leg Extension", dayType: .legs, muscleGroup: "Quads", isCustom: true)
        context.insert(lift)
        let home = GymLibrary.ensureHome(in: context)
        StackProfileStore.findOrCreate(gymID: home.id, exerciseID: lift.id, in: context)
            .applyTyped(step: 15, pins: [], unit: .pounds)
        try context.save()

        let data = try BackupService.export(context: context)
        try openSecondaryContainer()
        let other = try XCTUnwrap(secondaryContainer).mainContext
        try BackupService.restore(from: data, context: other)
        let stack = StackProfileStore.resolved(exerciseID: lift.id, in: other)
        XCTAssertEqual(stack?.step, 15)
        XCTAssertEqual(stack?.origin, .typed)
        XCTAssertEqual(MachineSteps.stepperStep(for: stack, unit: .pounds), 15)
    }

    // MARK: - Helpers (synthetic names and numbers)

    private func exercise(_ name: String, id: UUID = UUID(), sets: [Double], increment: Double? = nil) -> ProgramExercisePayload {
        ProgramExercisePayload(
            id: id,
            name: name,
            muscleGroup: "Quads",
            trainingMode: "Strength",
            notes: nil,
            sets: sets.enumerated().map {
                ProgramSetPayload(setNumber: $0.offset + 1, weightLbs: $0.element, reps: 10, isWarmup: nil, isEachSide: nil, isAssisted: nil)
            },
            weightIncrementLbs: increment
        )
    }

    private func programDocument(track: String = "A", exercises: [ProgramExercisePayload]) -> ProgramDocument {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        return ProgramDocument(
            format: ProgramFormat.formatName,
            schemaVersion: ProgramFormat.schemaVersion,
            exportedAt: date,
            block: ProgramBlockPayload(
                id: UUID(),
                name: "Synthetic 1.2.2 Block",
                notes: nil,
                startDate: date,
                sessions: [
                    ProgramSessionPayload(id: UUID(), date: date, dayType: "Lower", rotationTrack: track, notes: nil, exercises: exercises)
                ]
            )
        )
    }

    private func liftNamed(_ name: String) -> Exercise? {
        ((try? container.mainContext.fetch(FetchDescriptor<Exercise>())) ?? []).first { $0.name == name }
    }

    private func plannedWeights(_ name: String) -> [Double] {
        let records = (try? container.mainContext.fetch(FetchDescriptor<ExerciseRecord>())) ?? []
        return records.first { $0.exercise?.name == name }?.plannedSetsArray.map(\.weightLbs) ?? []
    }
}
