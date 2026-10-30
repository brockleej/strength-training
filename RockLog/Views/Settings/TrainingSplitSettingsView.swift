//
//  TrainingSplitSettingsView.swift
//  RockLog
//
//  Configure the user's training split: presets (bro, PPL, …) plus
//  add / rename / reorder / delete custom day types.
//  One List is the only scroller. Reorder uses the List's own drag
//  (.onMove). Move up / Move down appear only while the Reorder control is
//  on, outside the swipe area. Tapping a row opens the editor (plain Button).
//

import SwiftUI
import SwiftData

struct TrainingSplitSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\SplitDay.sortOrder), SortDescriptor(\SplitDay.name)])
    private var splitDays: [SplitDay]

    @State private var showAddSheet = false
    @State private var editingDay: SplitDay?
    @State private var pendingPreset: SplitPreset?
    @State private var showPresetConfirm = false
    @State private var dayPendingDelete: SplitDay?
    @State private var showKeepLastDay = false
    @State private var orderedIDs: [UUID] = []
    @State private var isReordering = false
    @AppStorage(SplitSchedulePreferences.modeKey)
    private var scheduleModeRaw: String = SplitScheduleMode.rolling.rawValue

    private var displayedDays: [SplitDay] {
        let byID = Dictionary(splitDays.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var seen = Set<UUID>()
        var result: [SplitDay] = []
        for id in orderedIDs {
            if let day = byID[id], seen.insert(id).inserted {
                result.append(day)
            }
        }
        for day in splitDays where seen.insert(day.id).inserted {
            result.append(day)
        }
        return result
    }

    var body: some View {
        let _ = noteBodyChanges()
        List {
            scheduleModeSection
                .splitListRow(top: 12, bottom: 10)
            presetsSection
                .splitListRow(top: 10, bottom: 10)
            daysHeader
                .splitListRow(top: 10, bottom: 6)
            if displayedDays.isEmpty {
                EmptyListState(
                    title: "No days yet",
                    systemImage: "calendar",
                    description: "Add a day or apply a preset above.",
                    actionTitle: ListMutationCopy.addDay,
                    action: { showAddSheet = true }
                )
                .splitListRow(top: 4, bottom: 4)
            } else {
                ForEach(Array(displayedDays.enumerated()), id: \.element.id) { index, day in
                    dayRow(day, weekPosition: index + 1)
                        .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                requestDelete(day)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .accessibilityIdentifier(AccessibilityID.splitDelete)
                        }
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                requestDelete(day)
                            }
                            .accessibilityIdentifier(AccessibilityID.splitDelete)
                        }
                }
                .onMove(perform: moveDays)

                AddItemRow(title: ListMutationCopy.addDay) {
                    showAddSheet = true
                }
                .splitListRow(top: 8, bottom: 4)
            }
            sectionFooter("This order is how days appear on Today — e.g. easier days first, harder days later in the week.")
                .splitListRow(top: 6, bottom: 28)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, 1)
        .background(Color.uplift.bgElev)
        .navigationTitle("Training Split")
        .navigationBarTitleDisplayMode(.inline)
        .diagBody("TrainingSplitSettingsView")
        .onChange(of: splitDays.map(\.id), initial: true) { _, next in
            // Do not assign when the ids already match. A write here rebuilds
            // the view, and an eager parent used to run this again immediately.
            guard next != orderedIDs else { return }
            orderedIDs = next
        }
        .sheet(isPresented: $showAddSheet) {
            SplitDayEditorSheet(existing: nil) { name, image, subtitle, hex, all in
                DayTypeRegistry.shared.upsert(
                    id: nil,
                    name: name,
                    systemImage: image,
                    subtitle: subtitle,
                    colorHex: hex,
                    includesAllExercises: all,
                    context: modelContext
                )
                syncOrderedIDs()
            }
        }
        .sheet(item: $editingDay) { day in
            SplitDayEditorSheet(existing: day) { name, image, subtitle, hex, all in
                DayTypeRegistry.shared.upsert(
                    id: day.id,
                    name: name,
                    systemImage: image,
                    subtitle: subtitle,
                    colorHex: hex,
                    includesAllExercises: all,
                    context: modelContext
                )
                syncOrderedIDs()
            }
        }
        .confirmationDialog(
            "Replace training split?",
            isPresented: $showPresetConfirm,
            titleVisibility: .visible
        ) {
            if let preset = pendingPreset {
                Button("Apply with starter exercises") {
                    applyPreset(preset, includeStarters: true)
                }
                Button("Apply with empty days") {
                    applyPreset(preset, includeStarters: false)
                }
            }
            Button("Cancel", role: .cancel) {
                pendingPreset = nil
            }
        } message: {
            Text("Your day list will be replaced. Starter exercises pin 3–5 common lifts on each new day. Empty days stay blank so you can add your own. Existing lifts keep their day tags.")
        }
        .confirmationDialog(
            "Delete \(dayPendingDelete?.name ?? "day")?",
            isPresented: Binding(
                get: { dayPendingDelete != nil },
                set: { if !$0 { dayPendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(ListMutationCopy.deleteDay, role: .destructive) {
                if let day = dayPendingDelete {
                    DayTypeRegistry.shared.delete(id: day.id, context: modelContext)
                }
                dayPendingDelete = nil
                syncOrderedIDs()
            }
            Button("Cancel", role: .cancel) {
                dayPendingDelete = nil
            }
        } message: {
            Text("Removes this day from your split. Exercises keep their tags and can be reassigned in the library.")
        }
        .confirmationDialog(
            ListMutationCopy.keepLastDayTitle,
            isPresented: $showKeepLastDay,
            titleVisibility: .visible
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(ListMutationCopy.keepLastDayMessage)
        }
    }

    // MARK: - Sections

    private var scheduleModeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Split schedule")
            UpliftSegmentedControl(
                segments: SplitScheduleMode.allCases.map {
                    UpliftSegment(id: $0.rawValue, label: $0.shortTitle)
                },
                selection: $scheduleModeRaw
            )
            sectionFooter(
                (SplitScheduleMode(rawValue: scheduleModeRaw) ?? .rolling).detail
                + " Same control lives under Settings → Training."
            )
        }
    }

    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Presets")
            VStack(spacing: 8) {
                ForEach(SplitPreset.allCases) { preset in
                    Button {
                        pendingPreset = preset
                        showPresetConfirm = true
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(preset.rawValue)
                                .font(.uplift.text(15, weight: .semibold))
                                .foregroundStyle(Color.uplift.fg)
                            Text(preset.detail)
                                .font(.uplift.text(12, weight: .medium))
                                .foregroundStyle(Color.uplift.fgMuted)
                                .multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.uplift.surface1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            sectionFooter("Applying a preset replaces your day list. You choose starter exercises or empty days. Existing lifts keep their tags.")
        }
    }

    private var daysHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                sectionHeader("Your days · weekly order")
                Spacer(minLength: 8)
                Button(isReordering ? "Done" : "Reorder") {
                    isReordering.toggle()
                }
                .font(.uplift.text(13, weight: .semibold))
                .foregroundStyle(Color.uplift.accent)
                .buttonStyle(.plain)
                .accessibilityIdentifier(AccessibilityID.splitReorder)
                .accessibilityAddTraits(isReordering ? AccessibilityTraits.isSelected : AccessibilityTraits())
            }
            Text("Long-press a day and drag to reorder, or tap Reorder. Swipe left to remove. Tap to edit.")
                .font(.uplift.text(13, weight: .medium))
                .foregroundStyle(Color.uplift.fgMuted)
        }
    }

    private func dayRow(_ day: SplitDay, weekPosition: Int) -> some View {
        let isFirst = weekPosition == 1
        let isLast = weekPosition == displayedDays.count
        return HStack(spacing: 8) {
            dayRowSummary(day, weekPosition: weekPosition)
            if isReordering {
                dayMoveButtons(day, moveUpDisabled: isFirst, moveDownDisabled: isLast)
            }
        }
        .accessibilityElement(children: .contain)
        .padding(.leading, 14)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.uplift.surface1)
        }
    }

    /// Tap target for the editor. Move buttons stay outside this view
    /// so XCUITest can tap them. The row (not this Button) owns the menu.
    private func dayRowSummary(_ day: SplitDay, weekPosition: Int) -> some View {
        Button {
            editingDay = day
        } label: {
            HStack(spacing: 12) {
            Text("\(weekPosition)")
                .font(.uplift.mono(13, weight: .bold))
                .foregroundStyle(Color.uplift.fgDim)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())

            DayChip(dayType: day.asDayType, size: .sm)

            VStack(alignment: .leading, spacing: 2) {
                Text(day.name)
                    .font(.uplift.text(15, weight: .semibold))
                    .foregroundStyle(Color.uplift.fg)
                if !day.subtitle.isEmpty {
                    Text(day.subtitle)
                        .font(.uplift.text(12, weight: .medium))
                        .foregroundStyle(Color.uplift.fgMuted)
                        .lineLimit(1)
                } else if day.includesAllExercises {
                    Text("Includes all exercises")
                        .font(.uplift.text(12, weight: .medium))
                        .foregroundStyle(Color.uplift.fgMuted)
                }
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.uplift.fgDim)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // Hit area is the label's shape, so the empty middle of the row
            // must be part of it (on wide phones the center is empty).
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(weekPosition). \(day.name)")
        .accessibilityIdentifier(AccessibilityID.splitDay(day.name))
        .accessibilityHint("Swipe left or long press to delete, tap to edit")
        .accessibilityAction(named: "Move up") { moveDay(day.id, by: -1) }
        .accessibilityAction(named: "Move down") { moveDay(day.id, by: 1) }
    }

    private func requestDelete(_ day: SplitDay) {
        if DayTypeRegistry.shared.canDelete(id: day.id, from: splitDays) {
            dayPendingDelete = day
        } else {
            showKeepLastDay = true
        }
    }

    private func dayMoveButtons(
        _ day: SplitDay,
        moveUpDisabled: Bool,
        moveDownDisabled: Bool
    ) -> some View {
        VStack(spacing: 4) {
            dayMoveButton(
                systemImage: "chevron.up",
                label: "Move up",
                identifier: AccessibilityID.splitDayMoveUp(day.name),
                isDisabled: moveUpDisabled
            ) {
                moveDay(day.id, by: -1)
            }
            dayMoveButton(
                systemImage: "chevron.down",
                label: "Move down",
                identifier: AccessibilityID.splitDayMoveDown(day.name),
                isDisabled: moveDownDisabled
            ) {
                moveDay(day.id, by: 1)
            }
        }
    }

    private func dayMoveButton(
        systemImage: String,
        label: String,
        identifier: String,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.uplift.fg)
                .frame(width: 32, height: 26)
                .background {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.uplift.surface2)
                }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }

    private func moveDays(from source: IndexSet, to destination: Int) {
        var next = displayedDays.map(\.id)
        next.move(fromOffsets: source, toOffset: destination)
        guard next != orderedIDs else { return }
        orderedIDs = next
        persistOrder()
    }

    private func moveDay(_ id: UUID, by delta: Int) {
        let next = SplitOrderLogic.move(ids: orderedIDs, id: id, by: delta)
        guard next != orderedIDs else { return }
        orderedIDs = next
        persistOrder()
    }

    private func applyPreset(_ preset: SplitPreset, includeStarters: Bool) {
        DayTypeRegistry.shared.applyPreset(
            preset,
            context: modelContext,
            includeStarters: includeStarters
        )
        pendingPreset = nil
        syncOrderedIDs()
    }

    private func syncOrderedIDs() {
        let next = splitDays.map(\.id)
        guard next != orderedIDs else { return }
        orderedIDs = next
    }

    private func noteBodyChanges() {
        if UITestLaunch.diagControlEnabled {
            Self._printChanges()
        }
    }

    private func persistOrder() {
        DayTypeRegistry.shared.applyOrder(ids: orderedIDs, context: modelContext)
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .textCase(.uppercase)
            .font(.uplift.text(11, weight: .bold))
            .tracking(0.6)
            .foregroundStyle(Color.uplift.fgMuted)
    }

    private func sectionFooter(_ text: String) -> some View {
        Text(text)
            .font(.uplift.text(12, weight: .medium))
            .foregroundStyle(Color.uplift.fgDim)
    }
}

// MARK: - Editor sheet

private struct SplitDayEditorSheet: View {
    let existing: SplitDay?
    let onSave: (_ name: String, _ systemImage: String, _ subtitle: String, _ colorHex: UInt32, _ includesAll: Bool) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var subtitle: String = ""
    @State private var systemImage: String = "dumbbell.fill"
    @State private var colorHex: UInt32 = DayTypePalette.inks[0]
    @State private var includesAllExercises = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    TextField("Subtitle (optional)", text: $subtitle)
                    Toggle("Includes all exercises", isOn: $includesAllExercises)
                } footer: {
                    Text("Full Body–style days list every exercise when you train.")
                }

                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                        ForEach(DayTypePalette.inks, id: \.self) { hex in
                            Button {
                                colorHex = hex
                            } label: {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 36, height: 36)
                                    .frame(width: 44, height: 44)
                                    .overlay {
                                        if hex == colorHex {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Day color")
                            .accessibilityAddTraits(hex == colorHex ? [.isSelected] : [])
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                        ForEach(DayTypePalette.iconChoices, id: \.symbol) { choice in
                            let selected = choice.symbol == systemImage
                            Button {
                                systemImage = choice.symbol
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: choice.symbol)
                                        .font(.system(size: 22, weight: .medium))
                                        .foregroundStyle(selected ? Color(hex: colorHex) : Color.uplift.fgMuted)
                                        .frame(width: 48, height: 48)
                                        .background {
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(selected ? Color(hex: colorHex, opacity: 0.16) : Color.uplift.surface2)
                                        }
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .strokeBorder(selected ? Color(hex: colorHex) : Color.clear, lineWidth: 1.5)
                                        }
                                    Text(choice.label)
                                        .font(.uplift.text(9, weight: .medium))
                                        .foregroundStyle(selected ? Color.uplift.fg : Color.uplift.fgDim)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.center)
                                        .frame(minHeight: 22, alignment: .top)
                                }
                                .frame(minWidth: 44, minHeight: 44)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(choice.label)
                            .accessibilityAddTraits(selected ? [.isSelected] : [])
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Icon")
                } footer: {
                    Text("Pick a glyph that matches the movement — press, pull, legs, hinge, etc.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.uplift.bgElev)
            .navigationTitle(existing == nil ? "New day" : "Edit day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(
                            name.trimmingCharacters(in: .whitespacesAndNewlines),
                            systemImage,
                            subtitle.trimmingCharacters(in: .whitespacesAndNewlines),
                            colorHex,
                            includesAllExercises
                        )
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if let existing {
                    name = existing.name
                    subtitle = existing.subtitle
                    systemImage = existing.systemImage
                    colorHex = UInt32(truncatingIfNeeded: existing.colorHex)
                    includesAllExercises = existing.includesAllExercises
                } else {
                    let index = DayTypeRegistry.shared.activeDays.count
                    colorHex = DayTypePalette.ink(at: index)
                    systemImage = DayTypePalette.iconChoices[index % DayTypePalette.iconChoices.count].symbol
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private extension View {
    /// Full-width List row with the screen's 20 pt margins and no chrome.
    func splitListRow(top: CGFloat, bottom: CGFloat) -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .listRowInsets(EdgeInsets(top: top, leading: 20, bottom: bottom, trailing: 20))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}
