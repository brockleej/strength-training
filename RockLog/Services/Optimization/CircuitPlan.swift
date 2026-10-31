//
//  CircuitPlan.swift
//  RockLog
//
//  Today's order as blocks: a lift on its own, or a circuit (A/B/C) that moves
//  as one block. Pure value logic for the Reorder sheet and the in-workout
//  round flow. Circuits keep using ExerciseRecord.groupID / groupPosition, so
//  there is no schema change.
//

import Foundation

nonisolated enum ReorderBlock: Equatable, Hashable, Sendable, Identifiable {
    case lift(UUID)
    case circuit(group: UUID, lifts: [UUID])

    var id: UUID {
        switch self {
        case .lift(let id): id
        case .circuit(let group, _): group
        }
    }

    var liftIDs: [UUID] {
        switch self {
        case .lift(let id): [id]
        case .circuit(_, let lifts): lifts
        }
    }
}

nonisolated struct CircuitPlan: Equatable, Sendable {
    static let maximumCircuits = 3
    static let letters = ["A", "B", "C"]

    var blocks: [ReorderBlock]

    /// Build from today's flat order and each lift's circuit seat.
    /// Members of one group are gathered where the first member sits, in seat order.
    init(order: [UUID], seats: [UUID: (group: UUID, position: Int)]) {
        var blocks: [ReorderBlock] = []
        var placed = Set<UUID>()
        for id in order where !placed.contains(id) {
            if let seat = seats[id] {
                let members = order
                    .filter { seats[$0]?.group == seat.group }
                    .sorted { (seats[$0]?.position ?? 0) < (seats[$1]?.position ?? 0) }
                if members.count >= CircuitAdvance.minimumCount {
                    blocks.append(.circuit(group: seat.group, lifts: members))
                    placed.formUnion(members)
                    continue
                }
            }
            blocks.append(.lift(id))
            placed.insert(id)
        }
        self.blocks = blocks
    }

    init(blocks: [ReorderBlock]) { self.blocks = blocks }

    var order: [UUID] { blocks.flatMap(\.liftIDs) }

    var circuits: [(group: UUID, lifts: [UUID])] {
        blocks.compactMap {
            if case .circuit(let group, let lifts) = $0 { return (group, lifts) }
            return nil
        }
    }

    var ungroupedLifts: [UUID] {
        blocks.compactMap { if case .lift(let id) = $0 { return id } else { return nil } }
    }

    /// "A", "B", "C" by position in today's list.
    func letter(for group: UUID) -> String? {
        guard let index = circuits.firstIndex(where: { $0.group == group }),
              index < Self.letters.count else { return nil }
        return Self.letters[index]
    }

    var canMakeAnotherCircuit: Bool {
        circuits.count < Self.maximumCircuits && ungroupedLifts.count >= CircuitAdvance.minimumCount
    }

    /// Standard List `.onMove`. A circuit moves as one block.
    mutating func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        blocks = Self.moved(blocks, fromOffsets: source, toOffset: destination)
    }

    /// Same result as SwiftUI's `Array.move(fromOffsets:toOffset:)`, without importing SwiftUI.
    static func moved<T>(_ items: [T], fromOffsets source: IndexSet, toOffset destination: Int) -> [T] {
        let moving = source.sorted().filter { $0 >= 0 && $0 < items.count }.map { items[$0] }
        var rest: [T] = []
        var insertAt = 0
        for (index, item) in items.enumerated() where !source.contains(index) {
            if index < destination { insertAt += 1 }
            rest.append(item)
        }
        rest.insert(contentsOf: moving, at: min(insertAt, rest.count))
        return rest
    }

    /// Reorder lifts inside one circuit.
    mutating func moveInside(group: UUID, fromOffsets source: IndexSet, toOffset destination: Int) {
        guard let index = blocks.firstIndex(where: { $0.id == group }),
              case .circuit(_, var lifts) = blocks[index] else { return }
        lifts = Self.moved(lifts, fromOffsets: source, toOffset: destination)
        blocks[index] = .circuit(group: group, lifts: lifts)
    }

    /// Create a circuit, or replace an existing one when `editing` is its group.
    /// Lifts keep the order they were picked in. Returns the group, or nil when not allowed.
    @discardableResult
    mutating func makeCircuit(_ picked: [UUID], editing: UUID? = nil, newGroup: UUID = UUID()) -> UUID? {
        guard CircuitAdvance.canCreate(count: picked.count), Set(picked).count == picked.count else { return nil }
        let editingLifts = editing.flatMap { group in circuits.first { $0.group == group }?.lifts } ?? []
        let allowed = Set(ungroupedLifts).union(editingLifts)
        guard picked.allSatisfy(allowed.contains) else { return nil }
        if editing == nil, circuits.count >= Self.maximumCircuits { return nil }
        let group = editing ?? newGroup
        // The block lands where its first picked lift (or the edited block) was.
        let anchor = blocks.firstIndex { block in
            if let editing, block.id == editing { return true }
            return editing == nil && block.liftIDs.contains(where: picked.contains)
        } ?? blocks.count
        var rebuilt: [ReorderBlock] = []
        for (index, block) in blocks.enumerated() {
            if index == anchor { rebuilt.append(.circuit(group: group, lifts: picked)) }
            switch block {
            case .lift(let id):
                if !picked.contains(id) { rebuilt.append(block) }
            case .circuit(let other, _):
                if other == editing {
                    // Lifts dropped from the edited circuit go back to standalone, in place.
                    for id in editingLifts where !picked.contains(id) { rebuilt.append(.lift(id)) }
                } else {
                    rebuilt.append(block)
                }
            }
        }
        if anchor >= blocks.count { rebuilt.append(.circuit(group: group, lifts: picked)) }
        blocks = rebuilt
        return group
    }

    mutating func ungroup(_ group: UUID) {
        blocks = blocks.flatMap { block -> [ReorderBlock] in
            if case .circuit(let other, let lifts) = block, other == group { return lifts.map { .lift($0) } }
            return [block]
        }
    }

    /// Seat per lift for saving: group and 1-based position. Standalone lifts are absent.
    var seats: [UUID: (group: UUID, position: Int)] {
        var result: [UUID: (group: UUID, position: Int)] = [:]
        for circuit in circuits {
            for (offset, id) in circuit.lifts.enumerated() { result[id] = (circuit.group, offset + 1) }
        }
        return result
    }

    /// Seats for another planned day ("Save for all upcoming days"). Each circuit keeps its
    /// group and lift order; lifts missing that day drop out and a circuit left with one
    /// lift is not made. Lifts not in a circuit are absent (standalone).
    func upcomingSeats(forDayWith exerciseIDs: [UUID]) -> [UUID: (group: UUID, position: Int)] {
        let present = Set(exerciseIDs)
        var result: [UUID: (group: UUID, position: Int)] = [:]
        for circuit in circuits {
            let kept = circuit.lifts.filter(present.contains)
            guard kept.count >= CircuitAdvance.minimumCount else { continue }
            for (offset, id) in kept.enumerated() { result[id] = (circuit.group, offset + 1) }
        }
        return result
    }
}

// MARK: - Rest after round

/// Rest after each round, keyed by circuit group. Phone-only (UserDefaults): the app
/// ships fully on-device with iCloud sync off until Lee approves it, so this never
/// touches NSUbiquitousKeyValueStore.
enum CircuitRestStore {
    static let defaultSeconds = 90
    static let range = 15...600
    static func key(_ group: UUID) -> String { "circuitRest.\(group.uuidString)" }

    static func seconds(for group: UUID, local: UserDefaults = AppDefaults.local) -> Int {
        let value = local.integer(forKey: key(group))
        return value > 0 ? clamp(value) : defaultSeconds
    }

    static func set(_ seconds: Int, for group: UUID, local: UserDefaults = AppDefaults.local) {
        local.set(clamp(seconds), forKey: key(group))
    }

    private static func clamp(_ seconds: Int) -> Int {
        min(max(seconds, range.lowerBound), range.upperBound)
    }
}
