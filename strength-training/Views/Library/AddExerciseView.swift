//
//  AddExerciseView.swift
//  strength-training
//
//  Created by Daniel Kuhlwein on 2026-02-21.
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
    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    formLabel("Name")
                    TextField("", text: $name, prompt:
                        Text("Hammer Curl").foregroundStyle(Color.uplift.fgDim)
                    )
                    .focused($nameFocused)
                    .font(.uplift.text(16, weight: .medium))
                    .foregroundStyle(Color.uplift.fg)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .background(Color.uplift.surface1, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.bottom, 18)

                    formLabel("Day type")
                    HStack(spacing: 4) {
                        daySegment(.arms, label: "Arms")
                        daySegment(.legs, label: "Legs")
                    }
                    .padding(3)
                    .background(Color.uplift.surface1, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.bottom, 18)

                    formLabel("Muscle group", hint: "(optional)")
                    TextField("", text: $muscleGroup, prompt:
                        Text("Biceps").foregroundStyle(Color.uplift.fgDim)
                    )
                    .font(.uplift.text(16, weight: .medium))
                    .foregroundStyle(Color.uplift.fg)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .background(Color.uplift.surface1, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.bottom, 14)

                    Text("New exercises appear at the bottom of their day type's section.")
                        .font(.uplift.text(12, weight: .medium))
                        .foregroundStyle(Color.uplift.fgDim)
                        .padding(.horizontal, 4)
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .background(Color.uplift.bgElev)
        .onAppear {
            // Reset all form state on every present so re-presenting the sheet
            // (e.g. via Cancel → tap +) starts clean rather than retaining the
            // previous attempt's name/muscleGroup.
            name = ""
            muscleGroup = ""
            dayType = preselectedDayType == .fullBody ? .arms : preselectedDayType
            // Auto-focus name field on present
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { nameFocused = true }
        }
    }

    private var header: some View {
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
                .foregroundStyle(canAdd ? Color.uplift.accent : Color.uplift.fgDim)
                .disabled(!canAdd)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func formLabel(_ text: String, hint: String? = nil) -> some View {
        HStack(spacing: 6) {
            Text(text.uppercased())
                .font(.uplift.text(11, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(Color.uplift.fgMuted)
            if let hint {
                Text(hint)
                    .font(.uplift.text(11, weight: .medium))
                    .foregroundStyle(Color.uplift.fgDim)
            }
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 8)
    }

    private func daySegment(_ option: DayType, label: String) -> some View {
        let active = (dayType == option)
        let ink: Color = option == .arms ? .uplift.armsInk : .uplift.legsInk
        return Button { dayType = option } label: {
            HStack(spacing: 6) {
                Circle().fill(active ? ink : Color.uplift.fgDim).frame(width: 6, height: 6)
                Text(label)
                    .font(.uplift.text(14, weight: .semibold))
                    .kerning(-0.1)
                    .foregroundStyle(active ? ink : Color.uplift.fgMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(active ? Color.uplift.surface3 : Color.clear,
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var canAdd: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func addExercise() {
        // Compute max sortOrder for this dayType in Swift (avoids #Predicate enum issue)
        let maxOrder = allExercises
            .filter { $0.dayType == dayType }
            .first?.sortOrder ?? -1

        let exercise = Exercise(
            name: name.trimmingCharacters(in: .whitespaces),
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
