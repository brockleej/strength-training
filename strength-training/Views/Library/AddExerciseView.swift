//
//  AddExerciseView.swift
//  strength-training
//

import SwiftUI
import SwiftData

struct AddExerciseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.sortOrder, order: .reverse) private var allExercises: [Exercise]

    var preselectedDayType: DayType = .arms

    @State private var name = ""
    @State private var selectedDayNames: Set<String> = []
    @State private var muscleGroup = ""
    @State private var rotationTrack: RotationTrack = .every
    @State private var dayCatalog = DayTypeRegistry.shared

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespaces)
    }

    private var homeDays: [DayType] {
        let homes = dayCatalog.exerciseHomeDays
        return homes.isEmpty ? [.arms, .legs] : homes
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
                Text("New exercise")
                    .font(.uplift.text(16, weight: .semibold))
                    .foregroundStyle(Color.uplift.fg)
                Spacer()
                Button("Add") { addExercise() }
                    .font(.uplift.text(16, weight: .semibold))
                    .foregroundStyle(
                        (trimmedName.isEmpty || selectedDayNames.isEmpty)
                            ? Color.uplift.fgDim : Color.uplift.accent
                    )
                    .disabled(trimmedName.isEmpty || selectedDayNames.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 18)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    field(label: "Name") {
                        TextField("e.g. Hammer Curl", text: $name)
                            .font(.uplift.text(16, weight: .medium))
                            .foregroundStyle(Color.uplift.fg)
                            .autocorrectionDisabled()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        formLabel("Home days")
                        VStack(spacing: 8) {
                            ForEach(homeDays) { day in
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
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        Text("Pick one or more days this lift should show on.")
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
                    }

                    field(label: "Muscle group", optional: true) {
                        TextField("e.g. Biceps", text: $muscleGroup)
                            .font(.uplift.text(16, weight: .medium))
                            .foregroundStyle(Color.uplift.fg)
                            .autocorrectionDisabled()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .background(Color.uplift.bgElev)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .onAppear {
            let seed: DayType
            if preselectedDayType.includesAllExercises {
                seed = homeDays.first ?? .arms
            } else if homeDays.contains(preselectedDayType) {
                seed = preselectedDayType
            } else {
                seed = homeDays.first ?? .arms
            }
            selectedDayNames = [seed.rawValue]
        }
    }

    private func toggleDay(_ day: DayType) {
        if selectedDayNames.contains(day.rawValue) {
            if selectedDayNames.count > 1 {
                selectedDayNames.remove(day.rawValue)
            }
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

    private func addExercise() {
        guard !trimmedName.isEmpty, !selectedDayNames.isEmpty else { return }
        let ordered = homeDays.filter { selectedDayNames.contains($0.rawValue) }
        guard let primary = ordered.first else { return }
        let extras = Array(ordered.dropFirst())

        let maxOrder = allExercises
            .filter { $0.belongs(to: primary) }
            .map(\.sortOrder)
            .max() ?? -1

        let exercise = Exercise(
            name: trimmedName,
            dayType: primary,
            muscleGroup: muscleGroup.trimmingCharacters(in: .whitespaces),
            sortOrder: maxOrder + 1,
            isCustom: true,
            rotationTrack: rotationTrack,
            additionalDayTypes: extras
        )
        modelContext.insert(exercise)
        try? modelContext.save()
        dismiss()
    }
}
