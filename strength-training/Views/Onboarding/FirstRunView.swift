//
//  FirstRunView.swift
//  strength-training
//
//  First-launch (and Settings replay) walkthrough.
//

import SwiftUI
import SwiftData
internal import UniformTypeIdentifiers

struct FirstRunView: View {
    var onFinished: () -> Void
    /// First install only — pick a split, then starters vs empty days.
    var showsSplitSetup: Bool = false

    @Environment(\.modelContext) private var modelContext
    @State private var page = 0
    @State private var setupStep: SetupStep
    @State private var selectedPreset: SplitPreset?
    @State private var includeStarters: Bool?
    @State private var isImportingBackup = false
    @State private var pendingRestoreData: Data?
    @State private var pendingRestorePrompt = RestorePrompt(
        title: "Restore backup?",
        message: "Load this backup onto this phone?",
        confirmTitle: "Restore",
        cancelTitle: "Cancel"
    )
    @State private var showRestoreConfirmation = false
    @State private var restoreErrorMessage = ""
    @State private var showRestoreError = false

    private let pages = FirstRunPage.all

    private enum SetupStep {
        case pickSplit
        case pickStarters
        case welcome
    }

    init(showsSplitSetup: Bool = false, onFinished: @escaping () -> Void) {
        self.onFinished = onFinished
        self.showsSplitSetup = showsSplitSetup
        _setupStep = State(initialValue: showsSplitSetup ? .pickSplit : .welcome)
    }

    var body: some View {
        VStack(spacing: 0) {
            switch setupStep {
            case .pickSplit:
                splitPicker
            case .pickStarters:
                starterPicker
            case .welcome:
                welcomePager
            }
        }
        .background(Color.uplift.bgElev.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(showsSplitSetup && setupStep != .welcome)
        .fileImporter(
            isPresented: $isImportingBackup,
            allowedContentTypes: [.json, .rockLogProgram],
            allowsMultipleSelection: false
        ) { result in
            handleRestorePick(result)
        }
        .alert(
            pendingRestorePrompt.title,
            isPresented: $showRestoreConfirmation
        ) {
            Button(pendingRestorePrompt.cancelTitle) {
                pendingRestoreData = nil
            }
            Button(pendingRestorePrompt.confirmTitle, role: .destructive) {
                confirmRestore()
            }
        } message: {
            Text(pendingRestorePrompt.message)
        }
        .alert("Couldn’t restore", isPresented: $showRestoreError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(restoreErrorMessage)
        }
    }

    // MARK: - Pick a split

    private var splitPicker: some View {
        VStack(spacing: 0) {
            setupHeader(
                eyebrow: "First setup",
                title: "Pick a split or restore",
                lede: "Start a new split, or restore a RockLog backup with your days, exercises, and history."
            )
            ScrollView {
                VStack(spacing: 8) {
                    setupChoice(
                        title: "Restore from backup",
                        detail: "Use a RockLog JSON export. Replaces this empty setup with that split and log.",
                        selected: false
                    ) {
                        selectedPreset = nil
                        isImportingBackup = true
                    }

                    ForEach(SplitPreset.allCases) { preset in
                        setupChoice(
                            title: preset.rawValue,
                            detail: preset.detail,
                            selected: selectedPreset == preset
                        ) {
                            selectedPreset = preset
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)
            setupContinue("Continue", enabled: selectedPreset != nil) {
                withAnimation(.easeInOut(duration: 0.25)) { setupStep = .pickStarters }
            }
        }
    }

    // MARK: - Starters vs empty

    private var starterPicker: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) { setupStep = .pickSplit }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .bold))
                        Text("Split")
                            .font(.uplift.text(15, weight: .semibold))
                    }
                    .foregroundStyle(Color.uplift.fgMuted)
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            setupHeader(
                eyebrow: "Your days",
                title: "Starter exercises?",
                lede: "Would you like us to add starter exercises, or leave the days empty for custom exercises?"
            )
            VStack(spacing: 8) {
                setupChoice(
                    title: "Add starter exercises",
                    detail: "Pins 3–5 common lifts on each day. Swap or remove them anytime.",
                    selected: includeStarters == true
                ) {
                    includeStarters = true
                }
                setupChoice(
                    title: "Leave empty",
                    detail: "Days start blank. Add your own from Exercises or when you train.",
                    selected: includeStarters == false
                ) {
                    includeStarters = false
                }
            }
            .padding(.horizontal, 24)
            Spacer(minLength: 12)
            setupContinue("Continue", enabled: includeStarters != nil) {
                applySetupAndShowWelcome()
            }
        }
    }

    private func applySetupAndShowWelcome() {
        guard let preset = selectedPreset, let includeStarters else { return }
        DayTypeRegistry.shared.applyPreset(
            preset,
            context: modelContext,
            includeStarters: includeStarters
        )
        withAnimation(.easeInOut(duration: 0.25)) { setupStep = .welcome }
    }

    private func handleRestorePick(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else {
                restoreErrorMessage = "Could not access the selected file."
                showRestoreError = true
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            do {
                let data = try Data(contentsOf: url)
                switch try IncomingRockLogFile.parse(data) {
                case .program:
                    restoreErrorMessage = "This file adds planned workouts. Finish setup first, then use Settings → Add planned workouts. It will not replace your history."
                    showRestoreError = true
                case .backup(let backupData):
                    let backup = try BackupService.decode(backupData)
                    let current = BackupService.summarizeStore(context: modelContext)
                    let incoming = BackupService.summarize(backup: backup)
                    pendingRestoreData = backupData
                    pendingRestorePrompt = BackupService.restorePrompt(current: current, incoming: incoming)
                    showRestoreConfirmation = true
                }
            } catch {
                restoreErrorMessage = error.localizedDescription
                showRestoreError = true
            }
        case .failure(let error):
            restoreErrorMessage = error.localizedDescription
            showRestoreError = true
        }
    }

    private func confirmRestore() {
        guard let data = pendingRestoreData else { return }
        pendingRestoreData = nil
        Task { @MainActor in
            do {
                try await BackupService.restoreAfterTearingDownUI(from: data, context: modelContext)
                withAnimation(.easeInOut(duration: 0.25)) { setupStep = .welcome }
            } catch {
                restoreErrorMessage = error.localizedDescription
                showRestoreError = true
            }
        }
    }

    // MARK: - Welcome pages

    private var welcomePager: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                if page < pages.count - 1 {
                    Button("Skip") { onFinished() }
                        .font(.uplift.text(15, weight: .semibold))
                        .foregroundStyle(Color.uplift.fgMuted)
                        .padding(.horizontal, 4)
                        .frame(minHeight: 44)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, item in
                    pageContent(item, mentionsSplitSetup: showsSplitSetup)
                        .tag(index)
                        .padding(.horizontal, 24)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: 6) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Capsule()
                        .fill(index == page ? Color.uplift.accent : Color.uplift.fgFaint)
                        .frame(width: index == page ? 18 : 6, height: 6)
                }
            }
            .padding(.bottom, 16)
            .accessibilityHidden(true)

            Button {
                if page < pages.count - 1 {
                    withAnimation(.easeInOut(duration: 0.25)) { page += 1 }
                } else {
                    onFinished()
                }
            } label: {
                Text(page < pages.count - 1 ? "Continue" : "Get started")
                    .font(.uplift.text(16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        Color.uplift.accent,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                    .foregroundStyle(Color.uplift.onAccent)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
    }

    private func setupHeader(eyebrow: String, title: String, lede: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow)
                .textCase(.uppercase)
                .font(.uplift.text(11, weight: .semibold))
                .tracking(0.4)
                .foregroundStyle(Color.uplift.fgMuted)
            Text(title)
                .font(.uplift.display(30, weight: .bold))
                .kerning(-0.6)
                .foregroundStyle(Color.uplift.fg)
            Text(lede)
                .font(.uplift.text(16, weight: .medium))
                .foregroundStyle(Color.uplift.fgMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 18)
    }

    private func setupChoice(
        title: String,
        detail: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.uplift.text(15, weight: .semibold))
                        .foregroundStyle(Color.uplift.fg)
                    Text(detail)
                        .font(.uplift.text(13, weight: .medium))
                        .foregroundStyle(Color.uplift.fgMuted)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(selected ? Color.uplift.accent : Color.uplift.fgDim)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(selected ? Color.uplift.accent.opacity(0.10) : Color.uplift.surface1)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(selected ? Color.uplift.accent.opacity(0.45) : Color.clear, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func setupContinue(_ title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.uplift.text(16, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    (enabled ? Color.uplift.accent : Color.uplift.fgFaint),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .foregroundStyle(enabled ? Color.uplift.onAccent : Color.uplift.fgDim)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .padding(.horizontal, 24)
        .padding(.bottom, 28)
    }

    private func pageContent(_ item: FirstRunPage, mentionsSplitSetup: Bool) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Image(systemName: item.symbol)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color.uplift.accent)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(Color.uplift.accent.opacity(0.16)))
                    .padding(.top, 12)

                VStack(alignment: .leading, spacing: 8) {
                    Text(item.eyebrow)
                        .textCase(.uppercase)
                        .font(.uplift.text(11, weight: .semibold))
                        .tracking(0.4)
                        .foregroundStyle(Color.uplift.fgMuted)
                    Text(item.title)
                        .font(.uplift.display(30, weight: .bold))
                        .kerning(-0.6)
                        .foregroundStyle(Color.uplift.fg)
                    Text(mentionsSplitSetup && item.eyebrow == "Welcome"
                     ? "Five tabs at the bottom are the whole app. Your split is already set. Open Settings once before you train for next-set fill, body weight, and gym pass."
                     : item.lede)
                        .font(.uplift.text(16, weight: .medium))
                        .foregroundStyle(Color.uplift.fgMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(item.rows) { row in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: row.symbol)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.uplift.accent)
                                .frame(width: 22)
                                .padding(.top, 2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.title)
                                    .font(.uplift.text(15, weight: .semibold))
                                    .foregroundStyle(Color.uplift.fg)
                                Text(row.detail)
                                    .font(.uplift.text(13, weight: .medium))
                                    .foregroundStyle(Color.uplift.fgMuted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.uplift.surface1)
                        }
                    }
                }
            }
            .padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
    }
}

private struct FirstRunPage: Identifiable {
    let id = UUID()
    let eyebrow: String
    let title: String
    let lede: String
    let symbol: String
    let rows: [FirstRunRow]

    static let all: [FirstRunPage] = [
        FirstRunPage(
            eyebrow: "Welcome",
            title: "RockLog",
            lede: "Five tabs at the bottom are the whole app. After this welcome, open the Settings tab once before you train — next set fill, body weight, and gym pass. You can change any of it later.",
            symbol: "dumbbell.fill",
            rows: [
                .init(
                    symbol: "dumbbell",
                    title: "Workout tab",
                    detail: "This is Today until you start a session: pick a training day and tap Start. After Start, this same tab becomes today’s lift list."
                ),
                .init(
                    symbol: "clock",
                    title: "History tab",
                    detail: "Finished workouts only. Open one to review sets or edit a weight you logged wrong."
                ),
                .init(
                    symbol: "chart.line.uptrend.xyaxis",
                    title: "Progress tab",
                    detail: "Trends across finished sessions: strength score, how often you trained, body log, PRs, and lift-by-lift comparison."
                ),
                .init(
                    symbol: "list.bullet",
                    title: "Exercises tab",
                    detail: "Your lift library. Assign a lift to a day, label A/B week, and add a note that shows up next time."
                ),
                .init(
                    symbol: "gearshape",
                    title: "Settings tab",
                    detail: "Next set default, Progression, Timer, Body profile, and Gym pass. Change your split anytime under Edit training split."
                ),
            ]
        ),
        FirstRunPage(
            eyebrow: "Workout tab",
            title: "Today",
            lede: "When you are not in a session, the Workout tab is Today. Choose the day you are training, then tap Start. Nothing is lost if you leave mid-workout.",
            symbol: "sun.max.fill",
            rows: [
                .init(
                    symbol: "barcode.viewfinder",
                    title: "Gym pass",
                    detail: "The barcode button on Today is your membership card at check-in. Set the number in Settings → Gym pass."
                ),
                .init(
                    symbol: "bolt.fill",
                    title: "Start and Resume",
                    detail: "Start opens today’s lifts on this same tab. If you need to leave, tap Home at the top of that list — you return to Today and the workout stays in progress. Later, tap Resume on that day to continue. Finish Workout is what saves it to History."
                ),
                .init(
                    symbol: "calendar",
                    title: "Your split",
                    detail: "The day cards are the split you picked. Change days and order in Settings → Edit training split. Rolling vs weekly is the control right under that."
                ),
            ]
        ),
        FirstRunPage(
            eyebrow: "In the gym",
            title: "Logging a lift",
            lede: "On the lift list, tap a movement to open it. Each set is a weight and a rep count. When you are done with that movement, mark it Done and go to the next one.",
            symbol: "checkmark.circle.fill",
            rows: [
                .init(
                    symbol: "plusminus",
                    title: "Weight step",
                    detail: "The small ± control under Weight is the plate jump. Tap it to cycle 5 lb → 1 lb → 0.5 lb → 5, then use − / + to change the load."
                ),
                .init(
                    symbol: "figure.strengthtraining.traditional",
                    title: "Assist",
                    detail: "Turn this on for a machine that helps you (assisted pull-up or dip). Enter the assistance shown on the stack, not a bar weight. Save your body weight in Settings → Body profile or the estimated load will be zero."
                ),
                .init(
                    symbol: "arrow.left.arrow.right",
                    title: "Sides",
                    detail: "Turn this on when the reps are each side — lunges, single-arm rows, and similar. RockLog counts both sides toward volume."
                ),
                .init(
                    symbol: "flame.fill",
                    title: "Warm",
                    detail: "Turn Warm on before you log a warm-up set. Those sets stay in the workout but do not count toward PRs or the next-session suggestion."
                ),
                .init(
                    symbol: "pencil",
                    title: "Edit or delete a set",
                    detail: "Tap a set you already logged to load it back into the steppers and change it. Swipe that set left to delete it; the remaining sets renumber."
                ),
                .init(
                    symbol: "checkmark.circle",
                    title: "Done",
                    detail: "Done means this lift is finished for today, even if you logged zero sets (skip). When the last lift is Done, RockLog asks whether to finish the whole workout."
                ),
                .init(
                    symbol: "slider.horizontal.3",
                    title: "Next set default",
                    detail: "After you log a set, the steppers refill from Settings → Next set default. Last session follows last time’s ramp; Last set repeats the set you just did."
                ),
            ]
        ),
        FirstRunPage(
            eyebrow: "After",
            title: "History & Progress",
            lede: "Only a finished workout is saved to History and Progress. If you never tap Finish Workout, that session stays off those tabs.",
            symbol: "chart.xyaxis.line",
            rows: [
                .init(
                    symbol: "clock.arrow.circlepath",
                    title: "History",
                    detail: "A list of finished sessions, grouped by month. Open one to see every lift and set. Use Edit if you need to fix a weight, then Save Changes."
                ),
                .init(
                    symbol: "chart.line.uptrend.xyaxis",
                    title: "Progress",
                    detail: "Strength score is the strongest estimated 1-rep max for each muscle. Sets tagged Side count both limbs. Two bench variations still count as one chest number. Below that: workout count, working sets, how often you trained, body log, PRs this month, sets by muscle, and a spreadsheet of recent sessions for each split day."
                ),
                .init(
                    symbol: "list.bullet",
                    title: "Exercises",
                    detail: "Assign lifts to the days in your split, mark A/B week if you rotate, and add a note that will show the next time you train that lift."
                ),
                .init(
                    symbol: "book",
                    title: "Welcome again",
                    detail: "Replay these pages anytime from Settings → Welcome guide."
                ),
            ]
        ),
    ]
}

private struct FirstRunRow: Identifiable {
    let id = UUID()
    let symbol: String
    let title: String
    let detail: String
}

#Preview {
    FirstRunView(onFinished: {})
        .preferredColorScheme(.dark)
}
