//
//  ReorderTodaySheet.swift
//  RockLog
//
//  "Reorder Today" (mockups reorder-redesign / circuits-multi). Standard edit-mode
//  grab handles are live right away, no long-press. A circuit (A/B/C) is one row
//  that drags as a block; "…" edits or ungroups it. Primary: Save for today.
//  Secondary: Save for all upcoming <Day> days.
//

import SwiftUI

enum CircuitColors {
    static let all: [Color] = [Color(hex: 0x5AB8F5), Color(hex: 0xFF9F0A), Color(hex: 0x34D399)]
    static func color(for letter: String) -> Color {
        switch letter {
        case "B": all[1]
        case "C": all[2]
        default: all[0]
        }
    }
}

struct ReorderTodaySheet: View {
    let dayName: String
    let name: (UUID) -> String
    let detail: (UUID) -> String
    let onSaveToday: (CircuitPlan) -> Void
    let onSaveUpcoming: (CircuitPlan) -> Void
    let onCancel: () -> Void

    @State private var plan: CircuitPlan
    @State private var circuitEditor: CircuitEditorTarget?

    init(
        dayName: String,
        name: @escaping (UUID) -> String,
        detail: @escaping (UUID) -> String,
        onSaveToday: @escaping (CircuitPlan) -> Void,
        onSaveUpcoming: @escaping (CircuitPlan) -> Void,
        onCancel: @escaping () -> Void,
        plan: CircuitPlan
    ) {
        self.dayName = dayName
        self.name = name
        self.detail = detail
        self.onSaveToday = onSaveToday
        self.onSaveUpcoming = onSaveUpcoming
        self.onCancel = onCancel
        _plan = State(initialValue: plan)
    }

    struct CircuitEditorTarget: Identifiable {
        var editing: UUID?
        var id: String { editing?.uuidString ?? "new" }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(plan.blocks) { block in
                        row(for: block)
                    }
                    .onMove { source, destination in
                        plan.move(fromOffsets: source, toOffset: destination)
                    }
                } header: {
                    Text(plan.circuits.isEmpty ? "Drag ≡ to reorder" : "Drag ≡ to reorder. A circuit moves as one block.")
                        .textCase(nil)
                }

                Section {
                    Button {
                        circuitEditor = CircuitEditorTarget(editing: nil)
                    } label: {
                        Label(plan.circuits.isEmpty ? "Make a circuit…" : "Make another circuit", systemImage: "plus.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(!plan.canMakeAnotherCircuit)
                    .accessibilityIdentifier(AccessibilityID.workoutCircuit)
                } footer: {
                    if !plan.canMakeAnotherCircuit && plan.circuits.count >= CircuitPlan.maximumCircuits {
                        Text("Up to \(CircuitPlan.maximumCircuits) circuits a workout.")
                    }
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Reorder Today")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .accessibilityIdentifier(AccessibilityID.workoutReorderCancel)
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    Button {
                        onSaveToday(plan)
                    } label: {
                        Text("Save for today")
                            .font(.uplift.text(16, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.uplift.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .foregroundStyle(Color.uplift.onAccent)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(AccessibilityID.workoutSaveToday)
                    Button {
                        onSaveUpcoming(plan)
                    } label: {
                        Text("Save for all upcoming \(dayName) days")
                            .font(.uplift.text(15, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.uplift.fgDim))
                            .foregroundStyle(Color.uplift.fg)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(AccessibilityID.workoutSaveOrderRemaining)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.uplift.bgElev)
            }
            .sheet(item: $circuitEditor) { target in
                MakeCircuitView(
                    plan: plan,
                    editing: target.editing,
                    name: name,
                    detail: detail,
                    onCreate: { picked, rest in
                        var next = plan
                        if let group = next.makeCircuit(picked, editing: target.editing) {
                            CircuitRestStore.set(rest, for: group)
                            plan = next
                        }
                        circuitEditor = nil
                    },
                    onCancel: { circuitEditor = nil }
                )
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func row(for block: ReorderBlock) -> some View {
        switch block {
        case .lift(let id):
            VStack(alignment: .leading, spacing: 2) {
                Text(name(id))
                Text(detail(id)).font(.uplift.text(12)).foregroundStyle(Color.uplift.fgMuted)
            }
            .accessibilityIdentifier(AccessibilityID.reorderRow(name(id)))
        case .circuit(let group, let lifts):
            let letter = plan.letter(for: group) ?? "A"
            let tint = CircuitColors.color(for: letter)
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 2).fill(tint).frame(width: 4)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(letter)
                            .font(.uplift.text(12, weight: .bold))
                            .foregroundStyle(Color.uplift.onAccent)
                            .frame(width: 20, height: 20)
                            .background(tint, in: RoundedRectangle(cornerRadius: 5))
                        Text("CIRCUIT \(letter) · \(CircuitRestStore.seconds(for: group)) s rest")
                            .font(.uplift.text(12, weight: .semibold))
                            .foregroundStyle(tint)
                        Spacer(minLength: 0)
                        Menu {
                            Button("Edit circuit") { circuitEditor = CircuitEditorTarget(editing: group) }
                            Button("Ungroup", role: .destructive) { plan.ungroup(group) }
                        } label: {
                            Image(systemName: "ellipsis")
                                .frame(width: 32, height: 24)
                        }
                        .accessibilityLabel("Circuit \(letter) options")
                        .accessibilityIdentifier(AccessibilityID.reorderCircuitMenu(letter))
                    }
                    ForEach(lifts, id: \.self) { id in
                        VStack(alignment: .leading, spacing: 1) {
                            Text(name(id))
                            Text(detail(id)).font(.uplift.text(12)).foregroundStyle(Color.uplift.fgMuted)
                        }
                    }
                }
            }
            .padding(.vertical, 2)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(AccessibilityID.reorderCircuit(letter))
        }
    }
}

/// "Make a Circuit": check lifts (only ones not already in a circuit), see the preview,
/// set rest after each round, create. Editing starts with that circuit's lifts checked.
struct MakeCircuitView: View {
    let plan: CircuitPlan
    let editing: UUID?
    let name: (UUID) -> String
    let detail: (UUID) -> String
    let onCreate: ([UUID], Int) -> Void
    let onCancel: () -> Void

    @State private var picked: [UUID] = []
    @State private var rest: Int = CircuitRestStore.defaultSeconds

    init(
        plan: CircuitPlan,
        editing: UUID?,
        name: @escaping (UUID) -> String,
        detail: @escaping (UUID) -> String,
        onCreate: @escaping ([UUID], Int) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.plan = plan
        self.editing = editing
        self.name = name
        self.detail = detail
        self.onCreate = onCreate
        self.onCancel = onCancel
    }

    private var editingLifts: [UUID] {
        editing.flatMap { group in plan.circuits.first { $0.group == group }?.lifts } ?? []
    }

    private var choices: [UUID] {
        plan.order.filter { plan.ungroupedLifts.contains($0) || editingLifts.contains($0) }
    }

    private var letter: String {
        if let editing, let l = plan.letter(for: editing) { return l }
        return plan.circuits.count < CircuitPlan.letters.count ? CircuitPlan.letters[plan.circuits.count] : "?"
    }

    var body: some View {
        NavigationStack {
            List {
                let others = plan.circuits.filter { $0.group != editing }
                if !others.isEmpty {
                    Section {
                        ForEach(others, id: \.group) { circuit in
                            let l = plan.letter(for: circuit.group) ?? ""
                            VStack(alignment: .leading, spacing: 2) {
                                Text("CIRCUIT \(l) · DONE").font(.uplift.text(12, weight: .semibold))
                                    .foregroundStyle(CircuitColors.color(for: l))
                                Text(circuit.lifts.map(name).joined(separator: " → ")).font(.uplift.text(14))
                            }
                        }
                    }
                }
                Section {
                    ForEach(choices, id: \.self) { id in
                        let isOn = picked.contains(id)
                        Button {
                            if isOn { picked.removeAll { $0 == id } }
                            else if picked.count < CircuitAdvance.maximumCount { picked.append(id) }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(isOn ? CircuitColors.color(for: letter) : Color.uplift.fgDim)
                                    .font(.system(size: 20))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(name(id)).foregroundStyle(Color.uplift.fg)
                                    Text(detail(id)).font(.uplift.text(12)).foregroundStyle(Color.uplift.fgMuted)
                                }
                            }
                        }
                        .accessibilityIdentifier(AccessibilityID.circuitPick(name(id)))
                        .accessibilityAddTraits(isOn ? .isSelected : [])
                    }
                } header: {
                    Text("Pick \(CircuitAdvance.minimumCount)–\(CircuitAdvance.maximumCount) lifts to do back-to-back for Circuit \(letter).")
                        .textCase(nil)
                }
                if !picked.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("CIRCUIT \(letter)").font(.uplift.text(12, weight: .semibold))
                                .foregroundStyle(CircuitColors.color(for: letter))
                            Text(picked.map(name).joined(separator: " → "))
                        }
                        Stepper(value: $rest, in: CircuitRestStore.range, step: 15) {
                            HStack {
                                Text("Rest after round")
                                Spacer()
                                Text("\(rest) s").foregroundStyle(Color.uplift.fgMuted)
                            }
                        }
                        .accessibilityIdentifier(AccessibilityID.circuitRest)
                    } footer: {
                        Text("No rest between lifts in a round. Rest runs once after each round.")
                    }
                }
            }
            .navigationTitle(editing == nil ? "Make a Circuit" : "Edit Circuit \(letter)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: onCancel) }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    onCreate(picked, rest)
                } label: {
                    Text(editing == nil
                         ? "Create circuit \(letter) (\(picked.count) lifts)"
                         : "Save circuit \(letter) (\(picked.count) lifts)")
                        .font(.uplift.text(16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(CircuitAdvance.canCreate(count: picked.count) ? Color.uplift.accent : Color.uplift.fgFaint,
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .foregroundStyle(Color.uplift.onAccent)
                }
                .buttonStyle(.plain)
                .disabled(!CircuitAdvance.canCreate(count: picked.count))
                .padding(16)
                .accessibilityIdentifier(AccessibilityID.circuitCreate)
            }
            .onAppear {
                picked = editingLifts
                if let editing { rest = CircuitRestStore.seconds(for: editing) }
            }
        }
        .preferredColorScheme(.dark)
    }
}
