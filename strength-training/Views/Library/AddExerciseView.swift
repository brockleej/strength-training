//
//  AddExerciseView.swift
//  strength-training
//

import SwiftUI
import SwiftData

struct AddExerciseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    // Fetch all exercises to compute sort order — avoids #Predicate enum issues
    @Query(sort: \Exercise.sortOrder, order: .reverse) private var allExercises: [Exercise]

    var preselectedDayType: DayType = .arms

    @State private var name = ""
    @State private var dayType: DayType = .arms
    @State private var muscleGroup = ""

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespaces)
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
                    .foregroundStyle(trimmedName.isEmpty ? Color.uplift.fgDim : Color.uplift.accent)
                    .disabled(trimmedName.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 18)

            VStack(alignment: .leading, spacing: 18) {
                field(label: "Name") {
                    TextField("e.g. Hammer Curl", text: $name)
                        .font(.uplift.text(16, weight: .medium))
                        .foregroundStyle(Color.uplift.fg)
                        .autocorrectionDisabled()
                }

                VStack(alignment: .leading, spacing: 8) {
                    formLabel("Day type")
                    UpliftSegmentedControl(
                        segments: [
                            UpliftSegment(id: DayType.arms.rawValue, label: "Arms", ink: .uplift.armsInk),
                            UpliftSegment(id: DayType.legs.rawValue, label: "Legs", ink: .uplift.legsInk),
                        ],
                        selection: Binding(
                            get: { dayType.rawValue },
                            set: { dayType = DayType(rawValue: $0) ?? .arms }
                        )
                    )
                }

                field(label: "Muscle group", optional: true) {
                    TextField("e.g. Biceps", text: $muscleGroup)
                        .font(.uplift.text(16, weight: .medium))
                        .foregroundStyle(Color.uplift.fg)
                        .autocorrectionDisabled()
                }

                Text("New exercises appear at the bottom of their day type's section.")
                    .font(.uplift.text(12, weight: .medium))
                    .foregroundStyle(Color.uplift.fgDim)
                    .padding(.horizontal, 4)
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .background(Color.uplift.bgElev)
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
        .onAppear {
            dayType = preselectedDayType == .fullBody ? .arms : preselectedDayType
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
        // Compute max sortOrder for this dayType in Swift (avoids #Predicate enum issue)
        let maxOrder = allExercises
            .filter { $0.dayType == dayType }
            .first?.sortOrder ?? -1

        let exercise = Exercise(
            name: trimmedName,
            dayType: dayType,
            muscleGroup: muscleGroup.trimmingCharacters(in: .whitespaces),
            sortOrder: maxOrder + 1,
            isCustom: true
        )
        modelContext.insert(exercise)
        try? modelContext.save()
        dismiss()
    }
}
