//
//  ExerciseLibraryView.swift
//  strength-training
//

import SwiftUI
import SwiftData

struct ExerciseLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Exercise.sortOrder) private var allExercises: [Exercise]
    @State private var showAddSheet = false
    @State private var searchText = ""

    private func exercises(for dayType: DayType) -> [Exercise] {
        allExercises.filter { exercise in
            exercise.dayType == dayType
                && (searchText.isEmpty
                    || exercise.name.localizedCaseInsensitiveContains(searchText))
        }
    }

    var body: some View {
        NavigationStack {
            List {
                SearchField(placeholder: "Search exercises", text: $searchText)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))

                ForEach(DayType.allCases.filter { $0 != .fullBody }) { dayType in
                    let matching = exercises(for: dayType)
                    if !matching.isEmpty {
                        Section {
                            ForEach(matching) { exercise in
                                LibraryRow(exercise: exercise)
                                    .listRowBackground(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(Color.uplift.surface1)
                                            .padding(.vertical, 2)
                                            .padding(.horizontal, 20)
                                    )
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 12, leading: 34, bottom: 12, trailing: 34))
                            }
                            .onDelete { indexSet in
                                for index in indexSet {
                                    let exercise = matching[index]
                                    if exercise.isCustom {
                                        modelContext.delete(exercise)
                                    }
                                }
                                try? modelContext.save()
                            }
                        } header: {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(dayType.upliftInk)
                                    .frame(width: 8, height: 8)
                                Text(dayType.rawValue)
                                    .textCase(.uppercase)
                                    .font(.uplift.text(11, weight: .bold))
                                    .tracking(0.6)
                                    .foregroundStyle(Color.uplift.fg)
                                Spacer()
                                Text("\(matching.count)")
                                    .font(.uplift.mono(12, weight: .semibold))
                                    .foregroundStyle(Color.uplift.fgDim)
                            }
                        }
                    }
                }

                if !searchText.isEmpty,
                   DayType.allCases.filter({ $0 != .fullBody }).allSatisfy({ exercises(for: $0).isEmpty }) {
                    Text("No matches")
                        .font(.uplift.text(13, weight: .medium))
                        .foregroundStyle(Color.uplift.fgDim)
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.uplift.bgElev)
            .navigationTitle("Exercises")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.uplift.fg)
                    }
                    .accessibilityLabel("Add exercise")
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddExerciseView()
            }
        }
    }
}

private struct LibraryRow: View {
    let exercise: Exercise

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Text(exercise.name)
                    .font(.uplift.text(15, weight: .semibold))
                    .kerning(-0.2)
                    .foregroundStyle(Color.uplift.fg)
                if exercise.isCustom {
                    Text("Custom")
                        .textCase(.uppercase)
                        .font(.uplift.text(9, weight: .bold))
                        .tracking(0.4)
                        .foregroundStyle(Color.uplift.customBadge)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.uplift.customBadge.opacity(0.16)))
                }
            }
            if !exercise.muscleGroup.isEmpty {
                Text(exercise.muscleGroup)
                    .font(.uplift.text(12, weight: .medium))
                    .foregroundStyle(Color.uplift.fgMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .deleteDisabled(!exercise.isCustom)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(exercise.name)\(exercise.isCustom ? ", custom" : "")\(exercise.muscleGroup.isEmpty ? "" : ", \(exercise.muscleGroup)")")
    }
}
