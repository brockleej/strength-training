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

enum CircuitStore {
    /// Clear a circuit partner when its lift is removed or deleted.
    @MainActor
    static func detach(exerciseID: UUID, in context: ModelContext) {
        let records = (try? context.fetch(FetchDescriptor<ExerciseRecord>())) ?? []
        let seats = records.compactMap { record -> CircuitSeat? in
            guard let id = record.exercise?.id else { return nil }
            return CircuitSeat(recordID: record.id, exerciseID: id, groupID: record.groupID, position: record.groupPosition)
        }
        let next = CircuitMembership.removing(exerciseID: exerciseID, from: seats)
        let byID = Dictionary(records.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for seat in next {
            guard let record = byID[seat.recordID] else { continue }
            record.groupID = seat.groupID
            record.groupPosition = seat.position
        }
    }
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
        let exercisesByID = Dictionary(exercises.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for id in orderedIDs {
            if let exercise = exercisesByID[id] {
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
        let seats = session.exerciseRecordsArray.compactMap { record -> CircuitSeat? in
            guard let exerciseID = record.exercise?.id else { return nil }
            return CircuitSeat(recordID: record.id, exerciseID: exerciseID, groupID: record.groupID, position: record.groupPosition)
        }
        let fixed = CircuitMembership.afterDrag(orderedExerciseIDs: orderedIDs, seats: seats)
        let recordsByID = Dictionary(session.exerciseRecordsArray.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for seat in fixed {
            recordsByID[seat.recordID]?.groupID = seat.groupID
            recordsByID[seat.recordID]?.groupPosition = seat.position
        }
        ModelSave.logged(modelContext, action: "WorkoutViewModel+SessionTools")
        setMutationEpoch &+= 1
    }

    func saveTodayOrderToThisDay(exercises: [Exercise]) {
        guard let session = activeSession else { return }
        let ordered = orderedExercises(exercises, session: session)
        Exercise.applyOrder(ordered, for: session.day)
        ModelSave.logged(modelContext, action: "WorkoutViewModel+SessionTools")
    }

    func saveTodayOrderToRemainingPlanned(exercises: [Exercise], plan: CircuitPlan? = nil) {
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
            // Circuits go with the order (1.2 gap a). Same group, so the round rest carries over.
            if let plan {
                let seats = plan.upcomingSeats(forDayWith: records.compactMap { $0.exercise?.id })
                for record in records {
                    guard let id = record.exercise?.id else { continue }
                    record.groupID = seats[id]?.group
                    record.groupPosition = seats[id]?.position ?? 0
                }
            }
            planned.followsSessionRoster = true
        }
        ModelSave.logged(modelContext, action: "WorkoutViewModel+SessionTools")
    }

    private func orderedExercises(_ exercises: [Exercise], session: WorkoutSession) -> [Exercise] {
        let roster = SessionRosterLogic.exercises(in: session)
        return roster.isEmpty ? exercises : roster
    }

    // MARK: - Circuits

    /// Partners of a lift that is leaving. A group of one is cleared in this save.
    func detachFromCircuits(_ exercise: Exercise) {
        CircuitStore.detach(exerciseID: exercise.id, in: modelContext)
    }

    func createCircuit(exerciseIDs: [UUID]) {
        guard CircuitAdvance.canCreate(count: exerciseIDs.count), let session = activeSession else { return }
        let group = UUID()
        for (offset, id) in exerciseIDs.enumerated() {
            guard let record = session.exerciseRecordsArray.first(where: { $0.exercise?.id == id }) else { continue }
            record.groupID = group
            record.groupPosition = offset + 1
        }
        ModelSave.logged(modelContext, action: "WorkoutViewModel+SessionTools")
        setMutationEpoch &+= 1
    }

    /// Today's order as blocks (lifts and circuits) for the Reorder sheet.
    func todayCircuitPlan(orderedIDs: [UUID]) -> CircuitPlan {
        var seats: [UUID: (group: UUID, position: Int)] = [:]
        for record in activeSession?.exerciseRecordsArray ?? [] {
            guard let id = record.exercise?.id, let group = record.groupID else { continue }
            seats[id] = (group, record.groupPosition)
        }
        return CircuitPlan(order: orderedIDs, seats: seats)
    }

    /// Save the Reorder sheet: order first, then every lift's circuit seat from the plan.
    func applyTodayPlan(_ plan: CircuitPlan, exercises: [Exercise]) {
        reorderToday(plan.order, exercises: exercises)
        guard let session = activeSession else { return }
        let seats = plan.seats
        for record in session.exerciseRecordsArray {
            guard let id = record.exercise?.id else { continue }
            if let seat = seats[id] {
                record.groupID = seat.group
                record.groupPosition = seat.position
            } else {
                record.groupID = nil
                record.groupPosition = 0
            }
        }
        ModelSave.logged(modelContext, action: "WorkoutViewModel+SessionTools")
        setMutationEpoch &+= 1
    }

    /// Round members for the circuit this lift is in. Nil for a standalone lift.
    func circuitRoundMembers(for exercise: Exercise) -> (group: UUID, members: [CircuitRoundMember])? {
        guard let session = activeSession, let record = currentRecord(for: exercise), let group = record.groupID else { return nil }
        let members: [CircuitRoundMember] = session.exerciseRecordsArray.compactMap { other in
            guard other.groupID == group, let id = other.exercise?.id else { return nil }
            let planned = other.plannedSetsArray.filter { !$0.isWarmup }.count
            return CircuitRoundMember(
                exerciseID: id,
                position: other.groupPosition,
                loggedWorkingSets: other.loggedSetsArray.filter { !$0.isWarmup }.count,
                plannedWorkingSets: planned > 0 ? planned : nil,
                isDone: other.isCompleted
            )
        }
        guard members.count >= CircuitAdvance.minimumCount else { return nil }
        return (group, members.sorted { $0.position < $1.position })
    }

    /// Letter (A/B/C) for a circuit by where it sits in today's list.
    func circuitLetter(for group: UUID) -> String {
        guard let session = activeSession else { return "A" }
        let ordered = session.exerciseRecordsArray.sorted { $0.sortOrder < $1.sortOrder }
        var groups: [UUID] = []
        for record in ordered {
            if let g = record.groupID, !groups.contains(g) { groups.append(g) }
        }
        let index = groups.firstIndex(of: group) ?? 0
        return index < CircuitPlan.letters.count ? CircuitPlan.letters[index] : "\(index + 1)"
    }

    /// What happens after a working set inside a circuit. Nil for warm-ups and standalone lifts.
    func circuitStep(after exercise: Exercise, wasWarmup: Bool) -> (step: CircuitRoundStep, restSeconds: Int)? {
        guard !wasWarmup, let info = circuitRoundMembers(for: exercise) else { return nil }
        return (CircuitRounds.stepAfterLogging(exercise.id, members: info.members), CircuitRestStore.seconds(for: info.group))
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
        assignCurrentGym(to: session)
        let gymID = session.gymID ?? GymLibrary.activeID(in: modelContext)
        let homeID = GymLibrary.ensureHome(in: modelContext).id
        for record in session.exerciseRecordsArray {
            guard let exercise = record.exercise else { continue }
            let corrected = record.loggedSetsArray
                .filter { !$0.isWarmup && $0.offeredWeightLbs != nil }
                .map(\.weightLbs)
            guard !corrected.isEmpty else { continue }
            let profile = StackProfileStore.findOrCreate(gymID: gymID, exerciseID: exercise.id, in: modelContext)
            let definition = profile.definition
            var samples = priorStackSamples(exerciseID: exercise.id, gymID: gymID, homeID: homeID, excluding: session.id)
            samples.append(StackSessionSample(id: session.id, date: session.date, correctedPounds: corrected))
            guard let learned = StackLearning.learnedStep(
                sessions: samples,
                clearedAt: definition.clearedAt,
                currentStep: definition.step,
                currentOffset: definition.offset,
                origin: definition.origin,
                learningEnabled: definition.learningEnabled,
                learnedSessionIDs: definition.learnedSessionIDs
            ) else { continue }
            var next = definition
            next.step = learned.step
            next.offset = learned.offset
            next.pins = []
            next.origin = .learned
            next.policy = .nearest
            next.pinUnit = .pounds
            next.learnedSessionIDs = learned.sessionIDs
            next.rangeMin = learned.offset > 0.001 ? learned.offset : learned.step
            next.rangeMax = max(learned.step * 40, 400)
            // The profile is the only row this writes. History and plan files stay put.
            profile.definition = next
            profile.updatedAt = Date()
        }
        ModelSave.logged(modelContext, action: "WorkoutViewModel+SessionTools")
    }

    /// The workout header and the session agree. Unlogged plan rows snap to the new gym.
    func selectGym(_ gym: Gym) {
        GymLibrary.select(gym)
        guard let session = activeSession else {
            setMutationEpoch &+= 1
            return
        }
        session.gymID = gym.id
        session.gymName = gym.name
        for record in session.exerciseRecordsArray {
            guard let exercise = record.exercise,
                  let stack = stackDefinition(for: exercise) else { continue }
            for set in record.plannedSetsArray {
                let offer = StackMath.snap(weightPounds: set.weightLbs, reps: set.reps, stack: stack)
                set.weightLbs = offer.weightPounds
                set.reps = offer.reps
            }
        }
        ModelSave.logged(modelContext, action: "WorkoutViewModel+SessionTools")
        setMutationEpoch &+= 1
    }

    func assignCurrentGym(to session: WorkoutSession) {
        guard GymLibrary.storeHasGyms(modelContext) else { return }
        let home = GymLibrary.ensureHome(in: modelContext)
        let active = GymLibrary.activeID(in: modelContext)
        let gyms = (try? modelContext.fetch(FetchDescriptor<Gym>())) ?? []
        let gym = gyms.first { $0.id == active } ?? home
        session.gymID = gym.id
        if session.gymName.isEmpty || session.gymID == gym.id {
            session.gymName = gym.name
        }
    }

    /// Last completed session for this lift at the active gym. A first visit to a
    /// travel gym uses Home and says so.
    func historyRecord(for exercise: Exercise, mode: TrainingMode) -> (record: ExerciseRecord?, usedHome: Bool) {
        let records = exercise.completedRecords(mode: mode, excludingSessionID: activeSession?.id)
        guard GymLibrary.storeHasGyms(modelContext), let context = exercise.modelContext else {
            return (records.first, false)
        }
        let home = GymLibrary.ensureHome(in: context)
        let active = GymLibrary.activeID(in: context)
        let selection = GymHistory.select(
            rows: records.map { GymHistory.Row(id: $0.id, gymID: $0.session?.gymID) },
            activeGymID: active,
            homeGymID: home.id
        )
        let record = records.first { selection.ids.contains($0.id) }
        return (record, selection.usedHome && record != nil)
    }

    func applyTypedStack(exercise: Exercise, step: Double?, pins: [Double]) {
        let gymID = GymLibrary.activeID(in: modelContext)
        let profile = StackProfileStore.findOrCreate(gymID: gymID, exerciseID: exercise.id, in: modelContext)
        let storedPins = FeatureFlags.pinListEditor ? pins : []
        profile.applyTyped(step: step, pins: storedPins, unit: MassUnitPreferences.unit)
        ModelSave.logged(modelContext, action: "WorkoutViewModel+SessionTools")
        setMutationEpoch &+= 1
    }

    func clearLearnedStack(exercise: Exercise) {
        let gymID = GymLibrary.activeID(in: modelContext)
        guard let profile = StackProfileStore.profile(gymID: gymID, exerciseID: exercise.id, in: modelContext) else { return }
        profile.clearLearned()
        ModelSave.logged(modelContext, action: "WorkoutViewModel+SessionTools")
        setMutationEpoch &+= 1
    }

    private func priorStackSamples(
        exerciseID: UUID,
        gymID: UUID,
        homeID: UUID,
        excluding sessionID: UUID
    ) -> [StackSessionSample] {
        let descriptor = FetchDescriptor<WorkoutSession>()
        let sessions = (try? modelContext.fetch(descriptor)) ?? []
        return sessions.compactMap { session in
            guard session.id != sessionID, session.isCompleted else { return nil }
            let sessionGym = session.gymID ?? homeID
            guard sessionGym == gymID else { return nil }
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

    // MARK: - Circuit gaps (1.2): round break, end early, start entry

    /// Start a round break: same rest timer and End alert as any lift.
    func beginCircuitBreak(_ found: CircuitBreak, seconds: Double, exercise: Exercise?) {
        startRest(seconds: seconds, exercise: exercise)
        circuitBreak = found
    }

    /// After a relaunch or a long background: bring the round break back if its rest
    /// still has time left, timed from the last set logged in the circuit.
    func resumeCircuitBreakIfNeeded(for exercise: Exercise, now: Date = .now) {
        guard !isResting, circuitBreak == nil,
              let session = activeSession, let info = circuitRoundMembers(for: exercise) else { return }
        let lastSetAt = session.exerciseRecordsArray
            .filter { $0.groupID == info.group }
            .flatMap { $0.loggedSetsArray.filter { !$0.isWarmup } }
            .map(\.completedAt)
            .max()
        guard let resumed = CircuitRounds.resumableBreak(
            group: info.group, members: info.members, lastSetAt: lastSetAt,
            restSeconds: CircuitRestStore.seconds(for: info.group), now: now
        ) else { return }
        beginCircuitBreak(resumed.break, seconds: resumed.remaining, exercise: exercise)
    }

    /// "End circuit early": lifts that still owe sets are marked done; rest stops.
    func endCircuitEarly(group: UUID) {
        guard let session = activeSession else { return }
        let records = session.exerciseRecordsArray.filter { $0.groupID == group }
        if let exercise = records.first?.exercise, let info = circuitRoundMembers(for: exercise) {
            let close = Set(CircuitRounds.liftsToCloseEarly(info.members))
            for record in records where record.exercise.map({ close.contains($0.id) }) == true {
                record.isCompleted = true
            }
        }
        if isResting || circuitBreak != nil { skipRest() }
        circuitBreak = nil
        ModelSave.logged(modelContext, action: "WorkoutViewModel+SessionTools")
        setMutationEpoch &+= 1
    }

    /// "Start Circuit A" sits above the first lift of each circuit on today's list.
    func circuitStart(before exercise: Exercise, in ordered: [Exercise]) -> (letter: String, title: String, liftID: UUID?)? {
        guard let info = circuitRoundMembers(for: exercise) else { return nil }
        let memberIDs = Set(info.members.map(\.exerciseID))
        guard ordered.first(where: { memberIDs.contains($0.id) })?.id == exercise.id else { return nil }
        let letter = circuitLetter(for: info.group)
        return (letter, CircuitRounds.startTitle(letter: letter, members: info.members), CircuitRounds.startLift(info.members))
    }
}
