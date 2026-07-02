//
//  AddExercisePicker.swift
//  strength-training
//
//  Sheet for pulling an exercise from the OTHER day type into this session
//  (Arms day → Legs exercises and vice versa), plus a "New exercise" escape
//  hatch. Full Body days bypass this picker entirely (everything's already
//  in the list) — the caller opens AddExerciseView directly.
//

import SwiftUI
import SwiftData

struct AddExercisePicker: View {
    let currentDayType: DayType
    /// Exercise ids already in the session (hidden from the picker).
    let excludedIDs: Set<UUID>
    let onPick: (Exercise) -> Void
    let onCreateNew: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    @Query(sort: \Exercise.sortOrder) private var allExercises: [Exercise]

    private var otherDayType: DayType {
        currentDayType == .arms ? .legs : .arms
    }

    private var candidates: [Exercise] {
        allExercises.filter { exercise in
            exercise.dayType == otherDayType
                && !excludedIDs.contains(exercise.id)
                && (searchText.isEmpty
                    || exercise.name.localizedCaseInsensitiveContains(searchText))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(Color.uplift.fgFaint)
                .frame(width: 36, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
                .padding(.bottom, 14)

            Text("Add exercise")
                .font(.uplift.display(20, weight: .bold))
                .kerning(-0.4)
                .foregroundStyle(Color.uplift.fg)
                .padding(.horizontal, 20)

            SearchField(placeholder: "Search \(otherDayType.rawValue) exercises", text: $searchText)
                .padding(.horizontal, 20)
                .padding(.top, 12)

            Button {
                dismiss()
                onCreateNew()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                    Text("New exercise")
                        .font(.uplift.text(14, weight: .semibold))
                }
                .foregroundStyle(Color.uplift.accent)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(candidates.enumerated()), id: \.element.id) { index, exercise in
                        Button {
                            dismiss()
                            onPick(exercise)
                        } label: {
                            HStack(spacing: 10) {
                                DayChip(dayType: exercise.dayType, size: .sm)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(exercise.name)
                                        .font(.uplift.text(15, weight: .semibold))
                                        .foregroundStyle(Color.uplift.fg)
                                    if !exercise.muscleGroup.isEmpty {
                                        Text(exercise.muscleGroup)
                                            .font(.uplift.text(12, weight: .medium))
                                            .foregroundStyle(Color.uplift.fgMuted)
                                    }
                                }
                                Spacer()
                                Image(systemName: "plus.circle")
                                    .font(.system(size: 18))
                                    .foregroundStyle(Color.uplift.accent)
                                    .accessibilityHidden(true)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if index < candidates.count - 1 {
                            Rectangle()
                                .fill(Color.uplift.hairline)
                                .frame(height: 0.5)
                                .padding(.leading, 66)
                        }
                    }
                    if candidates.isEmpty {
                        Text(searchText.isEmpty
                             ? "Every \(otherDayType.rawValue) exercise is already in this workout"
                             : "No matches")
                            .font(.uplift.text(13, weight: .medium))
                            .foregroundStyle(Color.uplift.fgDim)
                            .padding(20)
                    }
                }
                .padding(.top, 4)
            }
        }
        .background(Color.uplift.bgElev)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }
}

#Preview("AddExercisePicker") {
    AddExercisePicker(currentDayType: .legs, excludedIDs: [], onPick: { _ in }, onCreateNew: {})
        .modelContainer(previewContainer)
        .preferredColorScheme(.dark)
}
