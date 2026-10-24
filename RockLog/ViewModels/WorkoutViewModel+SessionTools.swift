//
//  WorkoutViewModel+SessionTools.swift
//  RockLog
//
//  Live-session behavior that does not belong in the lifecycle methods:
//  same-weight carry, today's order, circuits, and stack learning.
//

import Foundation
import SwiftData

struct SessionCarryState: Equatable {
    var rows: [CarrySet]
    var changed: Set<Int>
    var undo: CarryUndo?
    var line: String?
}

extension WorkoutViewModel {
    func bodyWeightPoundsForLogging(on date: Date = .now) -> Double {
        let entries = (try? modelContext.fetch(FetchDescriptor<BodyMetricEntry>())) ?? []
        let weighIns = entries.filter { $0.kind == .weight }.map {
            LoadMath.WeighIn(date: $0.date, pounds: $0.value)
        }
        return LoadMath.bodyWeight(asOf: date, weighIns: weighIns, settingsPounds: BodyWeightPreferences.pounds)
    }

    func stackDefinition(for exercise: Exercise) -> StackDefinition? {
        StackProfileStore.resolved(exerciseID: exercise.id, in: modelContext)
    }

    func carriedOpening(for exercise: Exercise, setNumber: Int) -> CarrySet? {
        carryByExercise[exercise.id]?.rows.first { $0.setNumber == setNumber && !$0.isLogged }
    }

    func carryLine(for exercise: Exercise) -> String? {
        guard !isRevisitingSavedSession else { return nil }
        return carryByExercise[exercise.id]?.line
    }

    func undoCarry(for exercise: Exercise) {
        guard var state = carryByExercise[exercise.id], let undo = state.undo else { return }
        state.rows = SameWeightCarry.undo(sets: state.rows, undo: undo)
        state.changed = []
        state.undo = nil
        state.line = nil
        carryByExercise[exercise.id] = state
        setMutationEpoch &+= 1
    }

    /// Logged or edited a working weight. History edits do not carry or snap.
    func applyCarry(
        exercise: Exercise,
        setNumber: Int,
        newWeight: Double,
        isWarmup: Bool,
        loggedTheOffer: Bool,
        repsOnly: Bool
    ) {
        guard !isRevisitingSavedSession else { return }
        var rows = rebuiltRows(for: exercise)
        let edit = SameWeightCarry.Edit(
            setNumber: setNumber,
            newWeight: newWeight,
            isWarmup: isWarmup,
            loggedTheOffer: loggedTheOffer,
            repsOnly: repsOnly
        )
        let carried = SameWeightCarry.apply(sets: rows, edit: edit)
        rows = carried.sets
        var protected = Set(carried.changedSetNumbers)
        protected.insert(setNumber)
        let snapped = SameWeightCarry.snapUnprotected(
            sets: rows,
            stack: stackDefinition(for: exercise),
            protected: protected
        )
        var changed = Set(carried.changedSetNumbers)
        changed.formUnion(snapped.snapped)
        // Undo must restore snaps too. Fold pre-snap weights into the carry undo.
        var undo = carried.undo
        if !snapped.snapped.isEmpty {
            var stored = undo?.stored ?? [:]
            for number in snapped.snapped where stored[number] == nil {
                if let before = rebuiltRows(for: exercise).first(where: { $0.setNumber == number }) {
                    stored[number] = CarryUndo.CarrySnapshot(weight: before.displayWeight, reps: before.reps)
                }
            }
            if !stored.isEmpty { undo = CarryUndo(stored: stored) }
        }
        let line = SameWeightCarry.announcement(changed: changed.sorted(), weight: newWeight)
        carryByExercise[exercise.id] = SessionCarryState(
            rows: snapped.sets,
            changed: changed,
            undo: undo,
            line: changed.isEmpty ? nil : line
        )
        setMutationEpoch &+= 1
    }

    func markCarryRowLogged(exercise: Exercise, setNumber: Int) {
        guard var state = carryByExercise[exercise.id] else { return }
        if let index = state.rows.firstIndex(where: { $0.setNumber == setNumber }) {
            state.rows[index].isLogged = true
            state.changed.remove(setNumber)
        }
        if state.changed.isEmpty {
            state.line = nil
            state.undo = nil
        }
        carryByExercise[exercise.id] = state
    }

    private func rebuiltRows(for exercise: Exercise) -> [CarrySet] {
        if let existing = carryByExercise[exercise.id]?.rows, !existing.isEmpty {
            return existing
        }
        let record = currentRecord(for: exercise)
        let planned = record?.plannedSetsArray ?? []
        let logged = Set((record?.loggedSetsArray ?? []).map(\.setNumber))
        let last = exercise.lastCompletedRecord(mode: selectedMode, excludingSessionID: activeSession?.id)
        let historical = last?.loggedSetsArray.sorted { $0.setNumber < $1.setNumber } ?? []
        var numbers = Set(planned.map(\.setNumber) + historical.map(\.setNumber) + logged)
        if let maxLogged = logged.max() { numbers.insert(maxLogged + 1) }
        if numbers.isEmpty { numbers.insert(1) }
        return numbers.sorted().map { number in
            let plan = planned.first { $0.setNumber == number }
            let history = historical.first { $0.setNumber == number }
            let weight = plan?.weightLbs ?? history?.weightLbs ?? 0
            let reps = plan?.reps ?? history?.reps ?? 10
            let warmup = plan?.isWarmup ?? false
            return CarrySet(
                setNumber: number,
                planWeight: weight,
                reps: reps,
                isWarmup: warmup,
                isLogged: logged.contains(number),
                displayWeight: weight
            )
        }
    }

    // MARK: - Order

    /// Drag order for this workout. The day plan stays until he saves it.
    func reorderToday(_ orderedIDs: [UUID], exercises: [Exercise]) {
        guard let session = activeSession, !session.isDeleted else { return }
        let byID = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
        for id in orderedIDs {
            if let exercise = byID[id] {
                _ = findOrCreateRecordPublic(for: exercise)
            }
        }
        let orders = SessionOrder.sortOrders(orderedIDs: orderedIDs)
        for record in session.exerciseRecordsArray {
            if let id = record.exercise?.id, let order = orders[id] {
                record.sortOrder = order
            }
        }
        session.followsSessionRoster = true
        try? modelContext.save()
        setMutationEpoch &+= 1
    }

    func saveTodayOrderToThisDay(exercises: [Exercise]) {
        guard let session = activeSession else { return }
        let ordered = orderedExercises(exercises, session: session)
        Exercise.applyOrder(ordered, for: session.day)
        try? modelContext.save()
    }

    func saveTodayOrderToRemainingPlanned(exercises: [Exercise]) {
        guard let session = activeSession else { return }
        let orderedIDs = orderedExercises(exercises, session: session).map(\.id)
        let dayName = session.day.rawValue
        let descriptor = FetchDescriptor<WorkoutSession>()
        let all = (try? modelContext.fetch(descriptor)) ?? []
        for planned in all where planned.id != session.id && !planned.isCompleted && planned.planStatus == .planned && planned.day.rawValue == dayName {
            var position = 0
            let records = planned.exerciseRecordsArray.sorted { $0.sortOrder < $1.sortOrder }
            var remaining = records
            for id in orderedIDs {
                if let index = remaining.firstIndex(where: { $0.exercise?.id == id }) {
                    remaining[index].sortOrder = position
                    position += 1
                    remaining.remove(at: index)
                }
            }
            for record in remaining {
                record.sortOrder = position
                position += 1
            }
            planned.followsSessionRoster = true
        }
        try? modelContext.save()
    }

    private func orderedExercises(_ exercises: [Exercise], session: WorkoutSession) -> [Exercise] {
        let roster = SessionRosterLogic.exercises(in: session)
        return roster.isEmpty ? exercises : roster
    }

    // MARK: - Circuits

    func createCircuit(exerciseIDs: [UUID]) {
        guard CircuitAdvance.canCreate(count: exerciseIDs.count), let session = activeSession else { return }
        let group = UUID()
        for (offset, id) in exerciseIDs.enumerated() {
            guard let record = session.exerciseRecordsArray.first(where: { $0.exercise?.id == id }) else { continue }
            record.groupID = group
            record.groupPosition = offset + 1
        }
        try? modelContext.save()
        setMutationEpoch &+= 1
    }

    /// Working sets advance inside the group. Warm-ups stay on this lift.
    func circuitNext(after exercise: Exercise, wasWarmup: Bool) -> UUID? {
        guard !wasWarmup, let session = activeSession else { return nil }
        guard let record = currentRecord(for: exercise), let group = record.groupID else { return nil }
        let members: [CircuitMember] = session.exerciseRecordsArray.compactMap { other in
            guard other.groupID == group, let id = other.exercise?.id else { return nil }
            let plannedWorking = other.plannedSetsArray.filter { !$0.isWarmup }.count
            return CircuitMember(
                exerciseID: id,
                position: other.groupPosition,
                isDone: other.isCompleted,
                loggedWorkingSets: other.loggedSetsArray.filter { !$0.isWarmup }.count,
                plannedWorkingCount: plannedWorking > 0 ? plannedWorking : nil
            )
        }
        return CircuitAdvance.next(after: exercise.id, members: members)
    }

    // MARK: - Stack learning

    func learnStacks(from session: WorkoutSession) {
        guard GymLibrary.storeHasGyms(modelContext),
              modelContext.container.schema.entities.contains(where: { $0.name == "MachineStackProfile" })
        else { return }
        let gymID = GymLibrary.activeID(in: modelContext)
        for record in session.exerciseRecordsArray {
            guard let exercise = record.exercise else { continue }
            let corrected = record.loggedSetsArray
                .filter { !$0.isWarmup && $0.offeredWeightLbs != nil }
                .map(\.weightLbs)
            guard !corrected.isEmpty else { continue }
            let profile = StackProfileStore.findOrCreate(gymID: gymID, exerciseID: exercise.id, in: modelContext)
            let definition = profile.definition
            var samples = priorStackSamples(exerciseID: exercise.id, excluding: session.id)
            samples.append(StackSessionSample(id: session.id, date: session.date, correctedPounds: corrected))
            guard let learned = StackLearning.learnedStep(
                sessions: samples,
                clearedAt: definition.clearedAt,
                currentStep: definition.step,
                origin: definition.origin,
                learningEnabled: definition.learningEnabled
            ) else { continue }
            var next = definition
            next.step = learned.step
            next.pins = []
            next.origin = .learned
            next.policy = .nearest
            next.pinUnit = .pounds
            next.learnedSessionIDs = learned.sessionIDs
            next.rangeMin = learned.step
            next.rangeMax = max(learned.step * 40, 200)
            // The profile is the only row this writes. History and plan files stay put.
            profile.definition = next
            profile.updatedAt = Date()
        }
        try? modelContext.save()
    }

    func applyTypedStack(exercise: Exercise, step: Double?, pins: [Double]) {
        let gymID = GymLibrary.activeID(in: modelContext)
        let profile = StackProfileStore.findOrCreate(gymID: gymID, exerciseID: exercise.id, in: modelContext)
        profile.applyTyped(step: step, pins: pins, unit: MassUnitPreferences.unit)
        try? modelContext.save()
        setMutationEpoch &+= 1
    }

    func clearLearnedStack(exercise: Exercise) {
        let gymID = GymLibrary.activeID(in: modelContext)
        guard let profile = StackProfileStore.profile(gymID: gymID, exerciseID: exercise.id, in: modelContext) else { return }
        profile.clearLearned()
        try? modelContext.save()
        setMutationEpoch &+= 1
    }

    private func priorStackSamples(exerciseID: UUID, excluding sessionID: UUID) -> [StackSessionSample] {
        let descriptor = FetchDescriptor<WorkoutSession>()
        let sessions = (try? modelContext.fetch(descriptor)) ?? []
        return sessions.compactMap { session in
            guard session.id != sessionID, session.isCompleted else { return nil }
            let weights = session.exerciseRecordsArray
                .filter { $0.exercise?.id == exerciseID }
                .flatMap(\.loggedSetsArray)
                .filter { !$0.isWarmup && $0.offeredWeightLbs != nil }
                .map(\.weightLbs)
            guard !weights.isEmpty else { return nil }
            return StackSessionSample(id: session.id, date: session.date, correctedPounds: weights)
        }
    }

    /// Visible to the reorder path. The private finder stays the one addSet uses.
    func findOrCreateRecordPublic(for exercise: Exercise) -> ExerciseRecord? {
        if let existing = currentRecord(for: exercise) { return existing }
        return ensureRecord(for: exercise)
    }

    private func ensureRecord(for exercise: Exercise) -> ExerciseRecord? {
        guard let session = activeSession, !session.isDeleted else { return nil }
        let record = ExerciseRecord(trainingMode: selectedMode, sortOrder: session.exerciseRecordsArray.count)
        record.exercise = exercise
        record.session = session
        if session.exerciseRecords == nil { session.exerciseRecords = [] }
        session.exerciseRecords?.append(record)
        modelContext.insert(record)
        return record
    }
}
