//
//  PRCelebrationView.swift
//  strength-training
//
//  Full-screen PR celebration. Presented via `.fullScreenCover(item:)` on FocusView
//  when WorkoutViewModel.addSet detects a new all-time e1RM PR.
//

import SwiftUI

/// Full-screen PR celebration. Presented via `.fullScreenCover(item:)` on FocusView
/// when WorkoutViewModel.addSet detects a new all-time e1RM PR.
///
/// Layout: full-bleed amber radial gradient backdrop, fireworks Canvas, trophy halo,
/// big weight number, exercise name, e1RM subtitle, optional delta card, "Continue
/// workout" button.
struct PRCelebrationView: View {
    let context: PRCelebrationContext
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            backdrop
            fireworks
            VStack(spacing: 0) {
                Spacer().frame(height: 80)
                trophy
                Spacer().frame(height: 26)
                eyebrow
                Spacer().frame(height: 12)
                bigNumber
                Spacer().frame(height: 8)
                subtitle
                Spacer().frame(height: 28)
                exerciseLine
                Spacer().frame(height: 8)
                e1RMLine
                Spacer().frame(height: 30)
                if context.previousBest != nil {
                    deltaCard
                        .padding(.horizontal, 24)
                }
                Spacer()
                continueButton
                    .padding(.horizontal, 20)
                    .padding(.bottom, 44)
            }

            // Close X — top right
            VStack {
                HStack {
                    Spacer()
                    Button {
                        onDismiss()
                    } label: {
                        ZStack {
                            Circle().fill(Color.uplift.surface1)
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.uplift.fg)
                        }
                        .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 18)
                    .padding(.top, 60)
                }
                Spacer()
            }
        }
        .background(Color.uplift.bgElev.ignoresSafeArea())
    }

    // MARK: - Sections

    private var backdrop: some View {
        // Amber radial gradient at top-30%, fades to bgElev.
        RadialGradient(
            colors: [Color.uplift.pr.opacity(0.42), .clear],
            center: UnitPoint(x: 0.5, y: 0.30),
            startRadius: 0,
            endRadius: 380
        )
        .ignoresSafeArea()
    }

    private var fireworks: some View {
        // Hardcoded RGB tuples to avoid the `Color.cgColor` indirection (which can
        // return nil for dynamic colors). Values match the design tokens in
        // Tokens.swift: pr (#FFB547) and accent (#5AB8F5).
        let prColor = Color(red: 1.0, green: 0.71, blue: 0.28)
        let accentColor = Color(red: 0.353, green: 0.722, blue: 0.961)
        return Canvas { ctx, size in
            let center = CGPoint(x: size.width / 2, y: 200)

            // 16 radial rays
            for i in 0..<16 {
                let angle = Double(i) / 16.0 * 2.0 * .pi
                let inner: Double = 60
                let outer: Double = 90 + Double(i % 3) * 14
                let p1 = CGPoint(x: center.x + CGFloat(cos(angle) * inner),
                                 y: center.y + CGFloat(sin(angle) * inner))
                let p2 = CGPoint(x: center.x + CGFloat(cos(angle) * outer),
                                 y: center.y + CGFloat(sin(angle) * outer))
                var path = Path()
                path.move(to: p1)
                path.addLine(to: p2)
                let strokeColor = (i % 2 == 0 ? prColor : accentColor).opacity(0.55)
                ctx.stroke(path, with: .color(strokeColor), lineWidth: 2)
            }

            // 8 sparkle dots at outer ring
            for i in 0..<8 {
                let angle = Double(i) / 8.0 * 2.0 * .pi + 0.2
                let r: Double = 130
                let p = CGPoint(x: center.x + CGFloat(cos(angle) * r),
                                y: center.y + CGFloat(sin(angle) * r))
                let circle = Path(ellipseIn: CGRect(x: p.x - 2.5, y: p.y - 2.5, width: 5, height: 5))
                let fillColor = (i % 2 == 0 ? prColor : accentColor).opacity(0.7)
                ctx.fill(circle, with: .color(fillColor))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }

    private var trophy: some View {
        ZStack {
            // Halo
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.uplift.pr.opacity(0.5), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 80
                    )
                )
                .frame(width: 160, height: 160)

            // Trophy chip
            ZStack {
                Circle().fill(Color.uplift.pr.opacity(0.18))
                Image(systemName: "trophy.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.uplift.pr)
            }
            .frame(width: 64, height: 64)
        }
    }

    private var eyebrow: some View {
        Text("PERSONAL RECORD")
            .font(.uplift.text(12, weight: .semibold))
            .tracking(1.2)
            .foregroundStyle(Color.uplift.pr)
    }

    private var bigNumber: some View {
        Num(formatWeight(context.weight), size: 120, weight: .bold)
    }

    private var subtitle: some View {
        Text("\(formatWeight(context.weight)) pounds × \(context.reps) reps")
            .font(.uplift.text(18, weight: .medium))
            .kerning(-0.2)
            .foregroundStyle(Color.uplift.fgMuted)
    }

    private var exerciseLine: some View {
        Text(context.exerciseName)
            .font(.uplift.display(24, weight: .semibold))
            .kerning(-0.4)
            .foregroundStyle(Color.uplift.fg)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
    }

    private var e1RMLine: some View {
        HStack(spacing: 4) {
            Text("1RM est.")
                .font(.uplift.text(13, weight: .medium))
                .foregroundStyle(Color.uplift.fgMuted)
            Num(formatWeight(context.newE1RM), size: 13, color: .uplift.fg)
            Text("lb")
                .font(.uplift.text(13, weight: .medium))
                .foregroundStyle(Color.uplift.fgMuted)
        }
    }

    @ViewBuilder
    private var deltaCard: some View {
        if let prev = context.previousBest {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("PREVIOUS BEST")
                        .font(.uplift.text(11, weight: .semibold))
                        .tracking(0.4)
                        .foregroundStyle(Color.uplift.fgMuted)
                    HStack(alignment: .lastTextBaseline, spacing: 6) {
                        Num("\(formatWeight(prev.weight)) × \(prev.reps)", size: 22, weight: .bold)
                        Text("· \(relativeDateLabel(prev.recordedAt))")
                            .font(.uplift.text(12, weight: .medium))
                            .foregroundStyle(Color.uplift.fgDim)
                    }
                }
                Spacer()
                deltaPill(prev: prev)
            }
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.uplift.surface1)
            }
        }
    }

    private func deltaPill(prev: ProgressionService.E1RMBest) -> some View {
        // Show weight delta if positive; else show e1RM delta (PR via reps).
        let weightDelta = context.weight - prev.weight
        let e1RMDelta = context.newE1RM - prev.e1RM
        let displayValue: Int
        let unit: String
        if weightDelta > 0 {
            displayValue = Int(weightDelta.rounded())
            unit = "lb"
        } else {
            displayValue = Int(e1RMDelta.rounded())
            unit = "lb e1RM"
        }
        return HStack(spacing: 4) {
            Image(systemName: "arrow.up")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.uplift.up)
            Num("+\(displayValue) \(unit)", size: 13, weight: .bold, color: .uplift.up)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background {
            Capsule().fill(Color.uplift.up.opacity(0.16))
        }
    }

    private var continueButton: some View {
        Button {
            onDismiss()
        } label: {
            Text("Continue workout")
                .font(.uplift.text(16, weight: .semibold))
                .kerning(-0.2)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Color.uplift.fg, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .foregroundStyle(Color.uplift.bg)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func formatWeight(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(v)) : String(format: "%.1f", v)
    }

    private func relativeDateLabel(_ date: Date) -> String {
        // Reuse the same rules as TodayViewModel for visual consistency,
        // but inline here to avoid cross-feature coupling.
        let cal = Calendar(identifier: .gregorian)
        let days = cal.dateComponents([.day],
                                      from: cal.startOfDay(for: date),
                                      to: cal.startOfDay(for: .now)).day ?? 0
        switch days {
        case 0:    return "today"
        case 1:    return "yesterday"
        case 2..<7: return "\(days) days ago"
        case 7..<14: return "1 wk ago"
        case 14..<28: return "\(days / 7) wks ago"
        default:    return "\(days / 7) wks ago"
        }
    }
}

#Preview("PRCelebrationView — with previous best") {
    PRCelebrationView(
        context: PRCelebrationContext(
            exerciseName: "Back Squat",
            weight: 235,
            reps: 5,
            newE1RM: 274.166,
            previousBest: ProgressionService.E1RMBest(
                weight: 225,
                reps: 5,
                e1RM: 262.5,
                recordedAt: Date(timeIntervalSinceNow: -86400 * 21)
            )
        ),
        onDismiss: {}
    )
}

#Preview("PRCelebrationView — no previous best") {
    PRCelebrationView(
        context: PRCelebrationContext(
            exerciseName: "Hip Thrust",
            weight: 180,
            reps: 8,
            newE1RM: 228,
            previousBest: nil
        ),
        onDismiss: {}
    )
}
