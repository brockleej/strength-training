// strength-training/Views/Workout/AddExercisePicker.swift
import SwiftUI
import SwiftData

/// Sheet for adding an exercise to the current session, drawn from the OPPOSITE
/// day type's exercises (per spec §6.6). Full Body sessions bypass this picker
/// and go straight to AddExerciseView (since FB already includes both day types).
struct AddExercisePicker: View {
    /// The current session's day type. Determines which exercises to show.
    let currentDayType: DayType
    /// Called when the user taps an existing exercise. Caller adds it to the session.
    let onPick: (Exercise) -> Void
    /// Called when the user taps "+ New exercise".
    let onCreateNew: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.sortOrder) private var allExercises: [Exercise]
    @State private var searchText = ""

    /// Day type whose exercises we show. Per spec: opposite of currentDayType.
    private var oppositeDayType: DayType {
        switch currentDayType {
        case .arms:     .legs
        case .legs:     .arms
        case .fullBody: .arms  // not used — Full Body bypasses this picker
        }
    }

    private var filteredExercises: [Exercise] {
        let candidates = allExercises.filter { $0.dayType == oppositeDayType }
        guard !searchText.isEmpty else { return candidates }
        return candidates.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchField
                listContent
            }
            .background(Color.uplift.bgElev)
            .navigationTitle("Add exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.uplift.fgMuted)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                        // Defer to next runloop so the sheet has time to dismiss
                        // before the parent presents AddExerciseView.
                        DispatchQueue.main.async { onCreateNew() }
                    } label: {
                        Label("New", systemImage: "plus")
                            .foregroundStyle(Color.uplift.accent)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.uplift.fgDim)
            TextField("Search \(oppositeDayType.rawValue) exercises", text: $searchText)
                .font(.uplift.text(15, weight: .medium))
                .foregroundStyle(Color.uplift.fg)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.uplift.surface1)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 16)
    }

    @ViewBuilder
    private var listContent: some View {
        if filteredExercises.isEmpty {
            VStack(spacing: 8) {
                Spacer()
                Text(searchText.isEmpty ? "No \(oppositeDayType.rawValue) exercises yet" : "No matches")
                    .font(.uplift.text(15, weight: .medium))
                    .foregroundStyle(Color.uplift.fgMuted)
                Text("Tap + to create a new one.")
                    .font(.uplift.text(13, weight: .regular))
                    .foregroundStyle(Color.uplift.fgDim)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(filteredExercises) { exercise in
                        Button {
                            onPick(exercise)
                            dismiss()
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
                            }
                            .padding(12)
                            .background {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.uplift.surface1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
    }
}
