//
//  ExerciseLibraryView.swift
//  strength-training
//
//  Created by Daniel Kuhlwein on 2026-02-21.
//

import SwiftUI
import SwiftData

struct ExerciseLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Exercise.sortOrder) private var allExercises: [Exercise]
    @State private var showAddSheet = false
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                NavBar(
                    title: "Exercises",
                    style: .large(size: 38),
                    leading: { EmptyView() },
                    trailing: { CircleButton(icon: "plus", size: .large) { showAddSheet = true } }
                )

                searchField
                    .padding(.horizontal, 20)

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(filteredSections, id: \.0) { dayType, exercises in
                            dayTypeSection(dayType, exercises: exercises)
                        }
                        if filteredSections.isEmpty {
                            emptyState
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 100)
                }
                .scrollIndicators(.hidden)
            }
            .background(Color.uplift.bgElev)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Exercise.self) { exercise in
                ExerciseDrillDownView(exercise: exercise, modelContext: modelContext)
            }
            .sheet(isPresented: $showAddSheet) {
                AddExerciseView()
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.uplift.fgDim)
            TextField("", text: $searchText, prompt:
                Text("Search exercises").foregroundStyle(Color.uplift.fgDim)
            )
            .font(.uplift.text(14, weight: .medium))
            .foregroundStyle(Color.uplift.fg)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.uplift.fgDim)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 12)
        .background(Color.uplift.surface1, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var filteredSections: [(DayType, [Exercise])] {
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        let matching: (Exercise) -> Bool = { ex in
            guard !q.isEmpty else { return true }
            return ex.name.lowercased().contains(q) || ex.muscleGroup.lowercased().contains(q)
        }
        return [DayType.arms, DayType.legs].compactMap { dt in
            let inDay = allExercises.filter { $0.dayType == dt && matching($0) }
            return inDay.isEmpty ? nil : (dt, inDay)
        }
    }

    private func dayTypeSection(_ dayType: DayType, exercises: [Exercise]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            librarySectionHeader(dayType: dayType, count: exercises.count)
            VStack(spacing: 0) {
                ForEach(Array(exercises.enumerated()), id: \.element.id) { idx, exercise in
                    NavigationLink(value: exercise) {
                        libraryRow(exercise: exercise, isLast: idx == exercises.count - 1)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Color.uplift.surface1, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding(.bottom, 22)
    }

    private func librarySectionHeader(dayType: DayType, count: Int) -> some View {
        HStack {
            HStack(spacing: 8) {
                Circle().fill(dayInk(dayType)).frame(width: 8, height: 8)
                Text(dayType.rawValue.uppercased())
                    .font(.uplift.text(11, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(Color.uplift.fg)
            }
            Spacer()
            Text("\(count)")
                .font(.uplift.mono(12, weight: .semibold))
                .foregroundStyle(Color.uplift.fgDim)
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 8)
    }

    private func dayInk(_ dayType: DayType) -> Color {
        switch dayType {
        case .arms: .uplift.armsInk
        case .legs: .uplift.legsInk
        case .fullBody: .uplift.fullInk
        }
    }

    private func libraryRow(exercise: Exercise, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 8) {
                        Text(exercise.name)
                            .font(.uplift.text(15, weight: .semibold))
                            .kerning(-0.2)
                            .foregroundStyle(Color.uplift.fg)
                        if exercise.isCustom {
                            customBadge
                        }
                    }
                    if !exercise.muscleGroup.isEmpty {
                        Text(exercise.muscleGroup)
                            .font(.uplift.text(12, weight: .medium))
                            .foregroundStyle(Color.uplift.fgMuted)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.uplift.fgDim)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contextMenu {
                if exercise.isCustom {
                    Button(role: .destructive) {
                        modelContext.delete(exercise)
                        try? modelContext.save()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            if !isLast {
                Rectangle()
                    .fill(Color.uplift.hairline)
                    .frame(height: 0.5)
                    .padding(.leading, 14)
            }
        }
    }

    private var customBadge: some View {
        Text("CUSTOM")
            .font(.uplift.text(9, weight: .bold))
            .tracking(0.4)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.uplift.ahkitOrange.opacity(0.16), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            .foregroundStyle(Color.uplift.ahkitOrange)
    }

    private var emptyState: some View {
        ContentUnavailableView(
            searchText.isEmpty ? "No exercises yet" : "No matches",
            systemImage: searchText.isEmpty ? "dumbbell" : "magnifyingglass",
            description: Text(searchText.isEmpty ? "Tap + to add a custom exercise." : "Try a different search term.")
        )
        .padding(.vertical, 40)
    }
}
