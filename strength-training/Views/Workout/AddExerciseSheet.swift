//
//  AddExerciseSheet.swift
//  strength-training
//
//  Single sheet to add a lift: Library (existing) or New (create).
//

import SwiftUI
import SwiftData

struct AddExerciseSheet: View {
    enum Tab: String, CaseIterable, Identifiable {
        case library = "Library"
        case create = "New"
        var id: String { rawValue }
    }

    let currentDayType: DayType
    let excludedIDs: Set<UUID>
    /// Called when picking an existing library exercise.
    let onPick: (Exercise, Bool) -> Void
    /// Called after creating a brand-new exercise (already saved to the store).
    var onCreated: ((Exercise) -> Void)? = nil
    /// When true (day plan editor), pin picks always assign to the day and
    /// hide the “also add to day” toggle (assignment is the whole point).
    var assignAlways: Bool = false
    var initialTab: Tab = .library

    @Environment(\.dismiss) private var dismiss
    @State private var tab: Tab = .library

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(Color.uplift.fgFaint)
                .frame(width: 36, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
                .padding(.bottom, 12)

            Text("Add exercise")
                .font(.uplift.display(20, weight: .bold))
                .kerning(-0.4)
                .foregroundStyle(Color.uplift.fg)
                .padding(.horizontal, 20)

            UpliftSegmentedControl(
                segments: Tab.allCases.map {
                    UpliftSegment(id: $0.rawValue, label: $0.rawValue)
                },
                selection: Binding(
                    get: { tab.rawValue },
                    set: { tab = Tab(rawValue: $0) ?? .library }
                )
            )
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 4)

            Group {
                switch tab {
                case .library:
                    AddExercisePicker(
                        currentDayType: currentDayType,
                        excludedIDs: excludedIDs,
                        onPick: { exercise, assign in
                            onPick(exercise, assignAlways || assign)
                        },
                        embedded: true,
                        forceAssignToDay: assignAlways
                    )
                case .create:
                    AddExerciseView(
                        preselectedDayType: currentDayType,
                        embedded: true,
                        onCreated: { exercise in
                            onCreated?(exercise)
                            dismiss()
                        }
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(Color.uplift.bgElev)
        .presentationDetents([.large, .medium])
        .presentationDragIndicator(.hidden)
        .presentationContentInteraction(.scrolls)
        .onAppear { tab = initialTab }
    }
}

#Preview("AddExerciseSheet") {
    AddExerciseSheet(
        currentDayType: .push,
        excludedIDs: [],
        onPick: { _, _ in },
        onCreated: { _ in }
    )
    .modelContainer(previewContainer)
    .preferredColorScheme(.dark)
}
