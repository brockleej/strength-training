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
            lede: "Five tabs at the bottom are the whole app. After this welcome, open the Settings tab once before you train — set your split, how the next set fills, body weight, and gym pass. You can change any of it later.",
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
                    detail: "Start here. Edit training split and Rolling/Weekly first, then Next set default, Progression, Timer, Body profile, and Gym pass."
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
                    detail: "The day cards are your training split, in the order you set. Change days and order in Settings → Edit training split. Rolling vs weekly is the control right under that."
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
                    detail: "Strength score is the sum of your best estimated 1-rep max on each lift. Below that: workout count, working sets, how often you trained, body log, PRs this month, sets by muscle, and a spreadsheet of recent sessions for each split day."
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
