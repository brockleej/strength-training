//
//  TrainingSplitSettingsView.swift
//  strength-training
//
//  Configure the user's training split: presets (bro, PPL, …) plus
//  add / rename / reorder / delete custom day types.
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
    @State private var editMode: EditMode = .inactive

    var body: some View {
        List {
            Section {
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
                        }
                    }
                }
            } header: {
                sectionHeader("Presets")
            } footer: {
                sectionFooter("Applying a preset replaces your day list. Exercises keep their current day tags — reassign them in the library if needed.")
            }
            .listRowBackground(Color.uplift.surface1)

            Section {
                ForEach(Array(splitDays.enumerated()), id: \.element.id) { index, day in
                    dayRow(day, weekPosition: index + 1)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            // Don't open editor while reordering.
                            guard editMode == .inactive else { return }
                            editingDay = day
                        }
                }
                .onDelete(perform: delete)
                .onMove(perform: move)

                if editMode == .inactive {
                    Button {
                        showAddSheet = true
                    } label: {
                        Label("Add day", systemImage: "plus")
                            .foregroundStyle(Color.uplift.accent)
                    }
                }
            } header: {
                sectionHeader("Your days · weekly order")
            } footer: {
                sectionFooter(
                    editMode.isEditing
                        ? "Drag the handles on the right to match the order you train (e.g. Push → Pull → Legs → Posterior Chain)."
                        : "This order is how days appear on Today. Tap Edit, then drag to reorder — e.g. easier days first, harder days later in the week."
                )
            }
            .listRowBackground(Color.uplift.surface1)
        }
        .scrollContentBackground(.hidden)
        .background(Color.uplift.bgElev)
        .navigationTitle("Training Split")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(editMode.isEditing ? "Done" : "Edit") {
                    withAnimation {
                        editMode = editMode.isEditing ? .inactive : .active
                    }
                }
                .fontWeight(.semibold)
            }
        }
        .environment(\.editMode, $editMode)
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
            }
        }
        .confirmationDialog(
            "Replace training split?",
            isPresented: $showPresetConfirm,
            titleVisibility: .visible
        ) {
            if let preset = pendingPreset {
                Button("Apply \(preset.rawValue)", role: .destructive) {
                    DayTypeRegistry.shared.applyPreset(preset, context: modelContext)
                    pendingPreset = nil
                }
            }
            Button("Cancel", role: .cancel) {
                pendingPreset = nil
            }
        } message: {
            Text("Your day list will be replaced. Existing exercises keep their day tags. You can reorder afterward.")
        }
    }

    private func dayRow(_ day: SplitDay, weekPosition: Int) -> some View {
        HStack(spacing: 12) {
            // Week position — makes "order I train" obvious
            Text("\(weekPosition)")
                .font(.uplift.mono(13, weight: .bold))
                .foregroundStyle(Color.uplift.fgDim)
                .frame(width: 22, alignment: .center)

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

            if editMode == .inactive {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.uplift.fgDim)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(weekPosition). \(day.name)")
        .accessibilityHint(editMode.isEditing ? "Drag to reorder" : "Double tap to edit")
    }

    private func delete(_ offsets: IndexSet) {
        for index in offsets {
            DayTypeRegistry.shared.delete(id: splitDays[index].id, context: modelContext)
        }
    }

    private func move(_ source: IndexSet, to destination: Int) {
        DayTypeRegistry.shared.move(from: source, to: destination, context: modelContext)
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
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 36, height: 36)
                                .overlay {
                                    if hex == colorHex {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                                .onTapGesture { colorHex = hex }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                        ForEach(DayTypePalette.iconChoices, id: \.symbol) { choice in
                            let selected = choice.symbol == systemImage
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
                            .onTapGesture { systemImage = choice.symbol }
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
                    // Sensible default icon for a new custom day
                    systemImage = DayTypePalette.iconChoices[index % DayTypePalette.iconChoices.count].symbol
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
