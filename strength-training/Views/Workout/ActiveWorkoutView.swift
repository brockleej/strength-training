//
//  ActiveWorkoutView.swift
//  strength-training
//
//  Created by Daniel Kuhlwein on 2026-02-21.
//

import SwiftUI
import SwiftData

struct ActiveWorkoutView: View {
    @Bindable var viewModel: WorkoutViewModel
    // Fetch all exercises reactively — filter in Swift to avoid #Predicate enum issues
    @Query(sort: \Exercise.sortOrder) private var allExercises: [Exercise]
    @State private var expandedExerciseID: UUID?
    @State private var showFinishConfirmation = false
    @State private var showAddExercise = false
    @State private var addExercisePreselectedType: DayType = .arms

    private var dayType: DayType {
        viewModel.activeSession?.dayType ?? .arms
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TrainingModePickerView(selectedMode: $viewModel.selectedMode)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

                if dayType == .fullBody {
                    exerciseSection(for: .arms)
                    exerciseSection(for: .legs)
                } else {
                    exerciseSection(for: dayType)
                }
            }
            .navigationTitle("\(dayType.rawValue) Day")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showFinishConfirmation = true
                    } label: {
                        Text("Finish")
                            .fontWeight(.semibold)
                    }
                }
            }
            .confirmationDialog(
                "Finish Workout?",
                isPresented: $showFinishConfirmation,
                titleVisibility: .visible
            ) {
                Button("Finish Workout") {
                    viewModel.finishSession()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                let completedCount = completedExerciseCount
                Text("You completed \(completedCount) exercise\(completedCount == 1 ? "" : "s") this session.")
            }
            .sheet(isPresented: $showAddExercise) {
                AddExerciseView(preselectedDayType: addExercisePreselectedType)
            }
        }
    }

    @ViewBuilder
    private func exerciseSection(for sectionDayType: DayType) -> some View {
        Section {
            ForEach(allExercises.filter { $0.dayType == sectionDayType }) { exercise in
                ExerciseRowView(
                    exercise: exercise,
                    viewModel: viewModel,
                    isExpanded: Binding(
                        get: { expandedExerciseID == exercise.id },
                        set: { newValue in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                expandedExerciseID = newValue ? exercise.id : nil
                            }
                        }
                    )
                )
            }

            Button {
                addExercisePreselectedType = sectionDayType
                showAddExercise = true
            } label: {
                Label("Add Exercise", systemImage: "plus.circle")
                    .foregroundStyle(.tint)
            }
        } header: {
            Text("\(sectionDayType.rawValue) Exercises")
        }
    }

    private var completedExerciseCount: Int {
        guard let session = viewModel.activeSession else { return 0 }
        return session.exerciseRecords.filter(\.isCompleted).count
    }
}
