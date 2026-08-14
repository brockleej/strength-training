//
//  FirstRunView.swift
//  strength-training
//
//  First-launch (and Settings replay) walkthrough.
//

import SwiftUI

struct FirstRunView: View {
    var onFinished: () -> Void

    @State private var page = 0

    private let pages = FirstRunPage.all

    var body: some View {
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
                    pageContent(item)
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
        .background(Color.uplift.bgElev.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    private func pageContent(_ item: FirstRunPage) -> some View {
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
                    Text(item.lede)
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
            lede: "Log the session. Own the data. See the trend.",
            symbol: "dumbbell.fill",
            rows: [
                .init(symbol: "dumbbell", title: "Workout", detail: "Today (Home) until you start. Then the day’s lift list."),
                .init(symbol: "clock", title: "History", detail: "Finished workouts. Reopen one to fix a set."),
                .init(symbol: "chart.line.uptrend.xyaxis", title: "Progress", detail: "Strength score, frequency, body, PRs."),
                .init(symbol: "list.bullet", title: "Exercises", detail: "Library, days, A/B week, notes."),
                .init(symbol: "gearshape", title: "Settings", detail: "Do this once: split, body weight, how the next set fills, rest."),
            ]
        ),
        FirstRunPage(
            eyebrow: "Home",
            title: "Today",
            lede: "Pick the day you’re training, then start. Your session waits if you leave.",
            symbol: "sun.max.fill",
            rows: [
                .init(symbol: "barcode.viewfinder", title: "Gym pass", detail: "Barcode at check-in. Set the number in Settings."),
                .init(symbol: "bolt.fill", title: "Start / Resume", detail: "Opens the workout list. Home parks the session so you can resume."),
                .init(symbol: "calendar", title: "Your split", detail: "Days and order live in Settings → Edit training split."),
            ]
        ),
        FirstRunPage(
            eyebrow: "In the gym",
            title: "Logging a lift",
            lede: "Tap a lift. Log sets. Mark Done when that movement is finished.",
            symbol: "checkmark.circle.fill",
            rows: [
                .init(symbol: "plusminus", title: "Weight step", detail: "Tap ±5 under Weight to switch 5 → 1 → 0.5 lb plates."),
                .init(symbol: "figure.strengthtraining.traditional", title: "Assist", detail: "Machine help, not bar weight. Save body weight in Settings for the math."),
                .init(symbol: "arrow.left.arrow.right", title: "Sides", detail: "Reps each side (lunges, rows). Volume counts both."),
                .init(symbol: "flame.fill", title: "Warm", detail: "Tags a warm-up. Left out of PRs and progression."),
                .init(symbol: "pencil", title: "Edit or delete a set", detail: "Tap a logged set to update it. Swipe left to delete."),
                .init(symbol: "checkmark.circle", title: "Done", detail: "Finishes this lift (any set count). Last lift asks to finish the workout."),
                .init(symbol: "slider.horizontal.3", title: "Auto-fill", detail: "Settings → Logging: Last session (ramps) or Last set (straight sets)."),
            ]
        ),
        FirstRunPage(
            eyebrow: "After",
            title: "History & Progress",
            lede: "Finish a workout so it counts. Incomplete sessions stay off History.",
            symbol: "chart.xyaxis.line",
            rows: [
                .init(symbol: "clock.arrow.circlepath", title: "History", detail: "Open a session → Edit to fix yesterday’s weights."),
                .init(symbol: "chart.line.uptrend.xyaxis", title: "Progress", detail: "Strength score (best e1RMs), workouts, body, lift charts."),
                .init(symbol: "list.bullet", title: "Exercises", detail: "Assign lifts to days, A/B week, and the note you see next time."),
                .init(symbol: "book", title: "Welcome again", detail: "Settings → Welcome guide replays these pages."),
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
