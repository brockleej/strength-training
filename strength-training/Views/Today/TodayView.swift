import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var workoutVM: WorkoutViewModel

    @State private var todayVM: TodayViewModel?
    /// User's explicit card tap, if any. Nil → fall back to `initialDayType` which
    /// reflects suspended-session state. This pattern means the picker auto-syncs
    /// to the suspended day on every appear, while still respecting manual overrides.
    @State private var manualSelection: DayType?
    @State private var confirmingDayType: DayType?

    private var selectedDayType: DayType {
        manualSelection
            ?? todayVM?.initialDayType(suspendedDayType: workoutVM.suspendedSession?.dayType)
            ?? .arms
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    pickerSection
                    primaryActions
                    if let yd = todayVM?.yesterdayData() {
                        yesterdaySection(yd)
                    }
                    thisWeekSection
                }
                .padding(.bottom, 120)  // breathing room above the floating tab bar
            }
            .background(Color.uplift.bgElev)
            .scrollIndicators(.hidden)
            .navigationBarHidden(true)
            .confirmationDialog(
                "Cancel Workout?",
                isPresented: $workoutVM.showCancelConfirmation,
                titleVisibility: .visible
            ) {
                Button("Cancel Workout", role: .destructive) {
                    workoutVM.cancelSuspendedSession()
                }
                Button("Keep Training", role: .cancel) {}
            } message: {
                let dayName = workoutVM.suspendedSession?.dayType.rawValue ?? "current"
                Text("Your \(dayName) Day workout will be discarded. This can't be undone.")
            }
            .confirmationDialog(
                "Apple Health Workout",
                isPresented: $workoutVM.showHealthKitKeepPrompt,
                titleVisibility: .visible
            ) {
                Button("Delete from Apple Health", role: .destructive) {
                    workoutVM.deleteHealthKitWorkout()
                }
                Button("Keep in Apple Health") {
                    workoutVM.keepHealthKitWorkout()
                }
            } message: {
                Text("This workout has been running for over 5 minutes. Would you also like to delete it from Apple Health?")
            }
            .onChange(of: workoutVM.showHealthKitKeepPrompt) { _, newValue in
                if !newValue { workoutVM.handleHealthKitPromptDismissed() }
            }
            .confirmationDialog(
                "Replace Current Workout?",
                isPresented: Binding(
                    get: { confirmingDayType != nil },
                    set: { if !$0 { confirmingDayType = nil } }
                ),
                titleVisibility: .visible
            ) {
                if let dayType = confirmingDayType {
                    Button("Start \(dayType.rawValue) Day", role: .destructive) {
                        workoutVM.abandonSuspendedAndStart(dayType: dayType)
                        confirmingDayType = nil
                    }
                }
                Button("Cancel", role: .cancel) { confirmingDayType = nil }
            } message: {
                let count = workoutVM.suspendedInProgressExerciseCount
                let dayName = workoutVM.suspendedSession?.dayType.rawValue ?? "current"
                Text("Your \(dayName) Day workout has \(count) exercise\(count == 1 ? "" : "s") in progress. Starting a new workout will discard it.")
            }
        }
        .onAppear {
            if todayVM == nil {
                todayVM = TodayViewModel(modelContext: modelContext)
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(formattedDate())
                .font(.uplift.text(13, weight: .medium))
                .foregroundStyle(Color.uplift.fgMuted)
            Text("Today")
                .font(.uplift.display(34, weight: .bold))
                .kerning(-0.8)
                .foregroundStyle(Color.uplift.fg)
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
        .padding(.bottom, 20)
    }

    private var pickerSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("What are you training?")
            VStack(spacing: 8) {
                ForEach(DayType.allCases) { dayType in
                    Button {
                        manualSelection = dayType
                    } label: {
                        DayPickerCard(
                            dayType: dayType,
                            subtitle: todayVM?.cardSubtitle(for: dayType) ?? "—",
                            isSelected: dayType == selectedDayType
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private var primaryActions: some View {
        VStack(spacing: 12) {
            Button {
                handleStart()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: workoutVM.suspendedSession?.dayType == selectedDayType
                          ? "arrow.right" : "bolt.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text(workoutVM.suspendedSession?.dayType == selectedDayType
                         ? "Resume workout" : "Start workout")
                        .font(.uplift.text(16, weight: .semibold))
                        .kerning(-0.2)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.uplift.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .foregroundStyle(Color.uplift.onAccent)
            }
            .buttonStyle(.plain)

            if workoutVM.suspendedSession != nil {
                Button {
                    workoutVM.showCancelConfirmation = true
                } label: {
                    Text("Cancel workout")
                        .font(.uplift.text(13, weight: .medium))
                        .foregroundStyle(Color.uplift.fgMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
    }

    @ViewBuilder
    private func yesterdaySection(_ yd: TodayViewModel.YesterdayData) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(yd.label)
            NavigationLink {
                SessionDetailView(session: yd.session)
            } label: {
                YesterdayCard(
                    dayType: yd.dayType,
                    durationLabel: yd.durationLabel,
                    totalVolume: yd.totalVolume,
                    totalSets: yd.totalSets,
                    prCount: yd.prCount
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }

    private var thisWeekSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("This week")
            if let vm = todayVM {
                let stats = vm.thisWeekStats()
                ThisWeekCard(
                    sessionCount: stats.sessionCount,
                    totalVolume: stats.totalVolume,
                    totalSets: stats.totalSets,
                    dayTypes: vm.weekDayTypes(),
                    todayIndex: todayWeekdayIndex(),
                    weeklyDelta: vm.weeklyVolumeDelta()
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }

    /// 0 (Mon) – 6 (Sun) for today's date.
    private func todayWeekdayIndex() -> Int {
        let cal = Calendar(identifier: .iso8601)
        let weekday = cal.component(.weekday, from: .now)
        return (weekday + 5) % 7
    }

    // MARK: - Helpers

    private func handleStart() {
        if workoutVM.suspendedHasSets,
           workoutVM.suspendedSession?.dayType != selectedDayType {
            confirmingDayType = selectedDayType
        } else {
            workoutVM.startSession(dayType: selectedDayType)
        }
    }

    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: .now)
    }
}

#Preview {
    TodayView(workoutVM: WorkoutViewModel(
        modelContext: previewContainer.mainContext,
        healthKitService: HealthKitWorkoutService()
    ))
    .modelContainer(previewContainer)
}
