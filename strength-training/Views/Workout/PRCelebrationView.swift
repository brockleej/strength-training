//
//  PRCelebrationView.swift
//  strength-training
//
//  Full-screen takeover when a logged set breaks the exercise's all-time
//  estimated-1RM record. Fireworks variant (design's `celebration: fireworks`
//  default), Share button dropped per spec.
//

import SwiftUI

struct PRCelebrationView: View {
    let context: PRCelebrationContext
    let onDismiss: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            // Amber radial backdrop over the elevated background
            Color.uplift.bgElev.ignoresSafeArea()
            RadialGradient(
                colors: [Color.uplift.pr.opacity(0.42), .clear],
                center: UnitPoint(x: 0.5, y: 0.3),
                startRadius: 0, endRadius: 360
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    CircleButton(icon: "xmark", accessibilityLabel: "Dismiss celebration") {
                        onDismiss()
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)

                Spacer(minLength: 12)

                ZStack {
                    FireworkRays()
                        .frame(width: 320, height: 320)
                        .opacity(appeared ? 1 : 0)
                    // trophy halo
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.uplift.pr.opacity(0.5), .clear],
                                center: .center, startRadius: 0, endRadius: 60
                            )
                        )
                        .frame(width: 120, height: 120)
                        .scaleEffect(appeared ? 1 : 0.4)
                    ZStack {
                        Circle().fill(Color.uplift.pr.opacity(0.18))
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(Color.uplift.pr)
                    }
                    .frame(width: 64, height: 64)
                    .scaleEffect(appeared ? 1 : 0.6)
                }
                .frame(height: 200)
                .accessibilityHidden(true)

                Text("Personal record")
                    .textCase(.uppercase)
                    .font(.uplift.text(12, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(Color.uplift.pr)
                    .padding(.top, 8)

                Num(StepperLogic.format(context.weight), size: 120)
                    .scaleEffect(appeared ? 1 : 0.85)
                    .padding(.top, 2)

                Text("pounds × \(context.reps) rep\(context.reps == 1 ? "" : "s")")
                    .font(.uplift.text(18, weight: .medium))
                    .kerning(-0.2)
                    .foregroundStyle(Color.uplift.fgMuted)

                Text(context.exerciseName)
                    .font(.uplift.display(24, weight: .semibold))
                    .kerning(-0.4)
                    .foregroundStyle(Color.uplift.fg)
                    .padding(.top, 18)

                (
                    Text("1RM est. ").font(.uplift.text(13, weight: .medium))
                    + Text("\(Int(context.e1RM.rounded())) lb").font(.uplift.mono(13, weight: .semibold))
                )
                .foregroundStyle(Color.uplift.fgMuted)
                .padding(.top, 4)

                deltaCard
                    .padding(.horizontal, 24)
                    .padding(.top, 24)

                Spacer()

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
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            "Personal record. \(context.exerciseName), \(StepperLogic.format(context.weight)) pounds for \(context.reps) reps."
        )
        .onAppear {
            HapticService.workoutCompleted()
            withAnimation(.spring(duration: 0.6)) { appeared = true }
        }
    }

    /// Weight delta when the bar got heavier; est-1RM delta otherwise
    /// (a rep-driven PR at equal/lower weight has no meaningful weight gain).
    private var deltaPillText: String {
        if context.weightDelta > 0 {
            return "+\(StepperLogic.format(context.weightDelta)) lb"
        }
        let e1rmDelta = context.e1RM - E1RM.estimate(
            weightLbs: context.previousWeight, reps: context.previousReps
        )
        return "+\(StepperLogic.format(e1rmDelta)) lb est. 1RM"
    }

    private var deltaCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Previous best")
                    .textCase(.uppercase)
                    .font(.uplift.text(11, weight: .semibold))
                    .tracking(0.4)
                    .foregroundStyle(Color.uplift.fgMuted)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    PairText.pair(weight: context.previousWeight, reps: context.previousReps, font: .uplift.display(22, weight: .semibold))
                    Text(context.previousDateLabel)
                        .font(.uplift.text(12, weight: .medium))
                        .foregroundStyle(Color.uplift.fgDim)
                }
            }
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 12, weight: .bold))
                Text(deltaPillText)
                    .font(.uplift.mono(13, weight: .semibold))
            }
            .foregroundStyle(Color.uplift.up)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.uplift.up.opacity(0.16)))
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.uplift.surface1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Previous best \(StepperLogic.format(context.previousWeight)) pounds for \(context.previousReps) reps, \(context.previousDateLabel). Up \(deltaPillText)."
        )
    }
}

/// 16 radial rays + 8 sparkle dots alternating amber/ice, per the design.
private struct FireworkRays: View {
    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            for i in 0..<16 {
                let angle = Double(i) / 16 * 2 * .pi
                let r1 = 60.0
                let r2 = 90.0 + Double(i % 3) * 14
                var path = Path()
                path.move(to: CGPoint(x: center.x + cos(angle) * r1, y: center.y + sin(angle) * r1))
                path.addLine(to: CGPoint(x: center.x + cos(angle) * r2, y: center.y + sin(angle) * r2))
                let color = (i % 2 == 0 ? Color.uplift.pr : Color.uplift.accent).opacity(0.55)
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            }
            for i in 0..<8 {
                let angle = Double(i) / 8 * 2 * .pi + 0.2
                let r = 130.0
                let rect = CGRect(
                    x: center.x + cos(angle) * r - 2.5,
                    y: center.y + sin(angle) * r - 2.5,
                    width: 5, height: 5
                )
                let color = (i % 2 == 0 ? Color.uplift.pr : Color.uplift.accent).opacity(0.7)
                context.fill(Path(ellipseIn: rect), with: .color(color))
            }
        }
    }
}

#Preview("PRCelebrationView") {
    PRCelebrationView(
        context: PRCelebrationContext(
            exerciseName: "Back Squat",
            weight: 235,
            reps: 5,
            e1RM: 274.2,
            previousWeight: 225,
            previousReps: 5,
            previousDateLabel: "3 wk ago",
            weightDelta: 10
        ),
        onDismiss: {}
    )
    .preferredColorScheme(.dark)
}
