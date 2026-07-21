//
//  EditExerciseView.swift
//  strength-training
//
//  Rename, multi-day membership, A/B week, muscle group, delete from library.
//

import SwiftUI
import SwiftData

struct EditExerciseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var exercise: Exercise

    /// When set, "Remove from this day" unassigns that membership only.
    var focusDay: DayType? = nil

    @State private var name: String = ""
    @State private var selectedDayNames: Set<String> = []
    @State private var muscleGroup: String = ""
    @State private var rotationTrack: RotationTrack = .every
    @State private var dayCatalog = DayTypeRegistry.shared
    @State private var showDeleteConfirm = false
    @State private var showRemoveDayConfirm = false

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespaces)
    }

    /// Home days in the active split, plus any orphan tags already on the exercise.
    private var assignableDays: [DayType] {
        var days = dayCatalog.exerciseHomeDays
        if days.isEmpty { days = [.arms, .legs] }
        for name in exercise.dayTypeNames where !days.contains(where: { $0.rawValue == name }) {
            days.append(DayType(rawValue: name))
        }
        return days
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(Color.uplift.fgFaint)
                .frame(width: 36, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
                .padding(.bottom, 14)

            HStack {
                Button("Cancel") { dismiss() }
                    .font(.uplift.text(16, weight: .medium))
                    .foregroundStyle(Color.uplift.fgMuted)
                Spacer()
                Text("Edit exercise")
                    .font(.uplift.text(16, weight: .semibold))
                    .foregroundStyle(Color.uplift.fg)
                Spacer()
                Button("Save") { save() }
                    .font(.uplift.text(16, weight: .semibold))
                    .foregroundStyle(trimmedName.isEmpty ? Color.uplift.fgDim : Color.uplift.accent)
                    .disabled(trimmedName.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 18)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    field(label: "Name") {
                        TextField("Exercise name", text: $name)
                            .font(.uplift.text(16, weight: .medium))
                            .foregroundStyle(Color.uplift.fg)
                            .autocorrectionDisabled()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        formLabel("Home days", optional: true)
                        dayMultiPicker
                        Text(selectedDayNames.isEmpty
                             ? "No days selected — stays in the library only (Unassigned)."
                             : "Selected days show this lift when you train. Leave empty for library-only.")
                            .font(.uplift.text(12, weight: .medium))
                            .foregroundStyle(Color.uplift.fgDim)
                            .padding(.horizontal, 4)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        formLabel("Week rotation")
                        UpliftSegmentedControl(
                            segments: RotationTrack.exerciseLabels.map { track in
                                UpliftSegment(
                                    id: track.storageKey,
                                    label: track == .every ? "Every" : track.rawValue
                                )
                            },
                            selection: Binding(
                                get: { rotationTrack.storageKey },
                                set: { rotationTrack = RotationTrack(storageKey: $0) }
                            )
                        )
                        Text("A weeks / B weeks alternate within each home day. Shared lifts use Every.")
                            .font(.uplift.text(12, weight: .medium))
                            .foregroundStyle(Color.uplift.fgDim)
                            .padding(.horizontal, 4)
                    }

                    field(label: "Muscle group", optional: true) {
                        TextField("e.g. Triceps", text: $muscleGroup)
                            .font(.uplift.text(16, weight: .medium))
                            .foregroundStyle(Color.uplift.fg)
                            .autocorrectionDisabled()
                    }

                    if let focusDay, exercise.belongs(to: focusDay) {
                        Button {
                            showRemoveDayConfirm = true
                        } label: {
                            Text("Remove from \(focusDay.rawValue)")
                                .font(.uplift.text(15, weight: .semibold))
                                .foregroundStyle(Color.uplift.customBadge)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.uplift.customBadge.opacity(0.12))
                                }
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    }

                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Text("Delete from library")
                            .font(.uplift.text(15, weight: .semibold))
                            .foregroundStyle(Color.uplift.down)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.uplift.down.opacity(0.12))
                            }
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .background(Color.uplift.bgElev)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .onAppear {
            name = exercise.name
            selectedDayNames = Set(exercise.dayTypeNames)
            muscleGroup = exercise.muscleGroup
            rotationTrack = exercise.track
        }
        .confirmationDialog(
            "Delete \(exercise.name)?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete from library", role: .destructive) {
                modelContext.delete(exercise)
                try? modelContext.save()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Removes it from all days. Past workout history that referenced it may show a missing exercise.")
        }
        .confirmationDialog(
            "Remove from \(focusDay?.rawValue ?? "day")?",
            isPresented: $showRemoveDayConfirm,
            titleVisibility: .visible
        ) {
            Button("Remove from day", role: .destructive) {
                if let focusDay {
                    selectedDayNames.remove(focusDay.rawValue)
                    save()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(selectedDayNames.count <= 1
                 ? "This lift will stay in your library as Unassigned (not on any day)."
                 : "Keeps the exercise on its other days.")
        }
    }

    private var dayMultiPicker: some View {
        VStack(spacing: 8) {
            ForEach(assignableDays) { day in
                let selected = selectedDayNames.contains(day.rawValue)
                Button {
                    toggleDay(day)
                } label: {
                    HStack(spacing: 12) {
                        DayChip(dayType: day, size: .sm)
                        Text(day.rawValue)
                            .font(.uplift.text(15, weight: .semibold))
                            .foregroundStyle(Color.uplift.fg)
                        Spacer()
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22))
                            .foregroundStyle(selected ? Color.uplift.accent : Color.uplift.fgDim)
                    }
                    .padding(12)
                    .background {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(selected ? Color.uplift.accent.opacity(0.10) : Color.uplift.surface1)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(selected ? Color.uplift.accent.opacity(0.45) : Color.clear, lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func toggleDay(_ day: DayType) {
        if selectedDayNames.contains(day.rawValue) {
            selectedDayNames.remove(day.rawValue)
        } else {
            selectedDayNames.insert(day.rawValue)
        }
    }

    private func formLabel(_ text: String, optional: Bool = false) -> some View {
        (
            Text(text.uppercased())
                .font(.uplift.text(11, weight: .bold))
            + Text(optional ? "  (OPTIONAL)" : "")
                .font(.uplift.text(11, weight: .medium))
                .foregroundColor(Color.uplift.fgDim)
        )
        .tracking(0.6)
        .foregroundStyle(Color.uplift.fgMuted)
        .padding(.horizontal, 4)
    }

    private func field(label: String, optional: Bool = false, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            formLabel(label, optional: optional)
            content()
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.uplift.surface1)
                }
        }
    }

    private func save() {
        guard !trimmedName.isEmpty else { return }
        // Preserve relative order from assignableDays, then any orphans.
        var ordered: [DayType] = []
        for day in assignableDays where selectedDayNames.contains(day.rawValue) {
            ordered.append(day)
        }
        for name in selectedDayNames.sorted() where !ordered.contains(where: { $0.rawValue == name }) {
            ordered.append(DayType(rawValue: name))
        }
        exercise.name = trimmedName
        exercise.setDayTypes(ordered) // empty → unassigned library lift
        exercise.muscleGroup = muscleGroup.trimmingCharacters(in: .whitespaces)
        exercise.track = rotationTrack
        try? modelContext.save()
        dismiss()
    }
}
