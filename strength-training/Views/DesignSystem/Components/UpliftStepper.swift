//
//  UpliftStepper.swift
//  strength-training
//

import SwiftUI

/// +/- stepper for weight and reps inputs.
///
/// Two visual states:
/// - **neutral** — surface1 card, white value, "± step" hint
/// - **target dress** (`targetDelta != nil`) — accent-washed card + border,
///   "↑ TARGET <LABEL>" overline (green arrow, accent text), accent value,
///   green delta line ("+5 lb") replacing the hint.
///
/// The −/+ buttons are never accent-filled (deliberate design decision).
/// Hold-to-repeat: fires once on press, then repeats every 80ms after a
/// 400ms warm-up. Each fire ticks `HapticService.stepperTick()` and calls
/// `onUserEdit` — the parent clears `targetDelta` there.
struct UpliftStepper: View {
    let label: String                  // "Weight" / "Reps"
    var unit: String? = nil            // "lb"
    @Binding var value: Double
    let step: Double
    let range: ClosedRange<Double>
    var targetDelta: String? = nil     // "+5 lb" / "+1" — non-nil = target dress
    var onUserEdit: (() -> Void)? = nil

    @State private var holdTask: Task<Void, Never>?

    private var isTarget: Bool { targetDelta != nil }

    var body: some View {
        VStack(spacing: 10) {
            labelRow
            HStack(spacing: 4) {
                holdButton(symbol: "minus") { adjust(by: -1) }
                VStack(spacing: 4) {
                    Num(StepperLogic.format(value), size: 40,
                        color: isTarget ? .uplift.accent : .uplift.fg)
                    hintLine
                }
                .frame(maxWidth: .infinity)
                holdButton(symbol: "plus") { adjust(by: +1) }
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isTarget ? Color.uplift.accent.opacity(0.10) : Color.uplift.surface1)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(isTarget ? Color.uplift.accent.opacity(0.55) : .clear, lineWidth: 1)
        }
        .animation(.easeInOut(duration: 0.2), value: isTarget)
        .onDisappear { stopHold() }
    }

    private var labelRow: some View {
        HStack(spacing: 4) {
            if isTarget {
                Image(systemName: "arrow.up")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.uplift.up)
            }
            Text(fullLabel)
                .font(.uplift.text(11, weight: .semibold))
                .tracking(0.4)
                .foregroundStyle(isTarget ? Color.uplift.accent : Color.uplift.fgMuted)
        }
    }

    private var fullLabel: String {
        let base = unit.map { "\(label) (\($0))" } ?? label
        return (isTarget ? "Target \(base)" : base).uppercased()
    }

    @ViewBuilder
    private var hintLine: some View {
        if let targetDelta {
            Text(targetDelta)
                .font(.uplift.mono(11, weight: .semibold))
                .foregroundStyle(Color.uplift.up)
        } else {
            Text("± \(StepperLogic.format(step))")
                .font(.uplift.text(10, weight: .medium))
                .tracking(0.3)
                .foregroundStyle(Color.uplift.fgDim)
        }
    }

    private func holdButton(symbol: String, action: @escaping () -> Void) -> some View {
        // DragGesture(minimumDistance: 0) instead of Button so the press
        // state machine fully drives tap-once + hold-to-repeat.
        Image(systemName: symbol)
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(Color.uplift.fg)
            .frame(width: 44, height: 44)
            .background { Circle().fill(Color.uplift.surface2) }
            .contentShape(Circle())
            .accessibilityLabel(symbol == "plus" ? "Increase \(label)" : "Decrease \(label)")
            .accessibilityValue(StepperLogic.format(value))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { action() }   // VoiceOver double-tap: one discrete step
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if holdTask == nil { startHold(action) }
                    }
                    .onEnded { _ in stopHold() }
            )
    }

    private func adjust(by direction: Double) {
        let newValue = direction > 0
            ? StepperLogic.increment(value, step: step, max: range.upperBound)
            : StepperLogic.decrement(value, step: step, min: range.lowerBound)
        guard newValue != value else { return }   // pinned at a bound — stay silent
        value = newValue
        HapticService.stepperTick()
        onUserEdit?()
    }

    private func startHold(_ action: @escaping () -> Void) {
        action()   // fire once immediately
        holdTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            while !Task.isCancelled {
                action()
                try? await Task.sleep(for: .milliseconds(80))
            }
        }
    }

    private func stopHold() {
        holdTask?.cancel()
        holdTask = nil
    }
}

#Preview("UpliftStepper") {
    @Previewable @State var weight: Double = 235
    @Previewable @State var reps: Double = 5

    VStack(spacing: 20) {
        // Neutral pair (interactive)
        HStack(spacing: 10) {
            UpliftStepper(label: "Weight", unit: "lb", value: $weight, step: 5, range: 0...1000)
            UpliftStepper(label: "Reps", value: $reps, step: 1, range: 1...100)
        }
        // Weight-bump target dress
        HStack(spacing: 10) {
            UpliftStepper(label: "Weight", unit: "lb", value: .constant(230), step: 5,
                          range: 0...1000, targetDelta: "+5 lb")
            UpliftStepper(label: "Reps", value: .constant(5), step: 1, range: 1...100)
        }
        // Rep-bump target dress
        HStack(spacing: 10) {
            UpliftStepper(label: "Weight", unit: "lb", value: .constant(47.5), step: 2.5, range: 0...1000)
            UpliftStepper(label: "Reps", value: .constant(11), step: 1, range: 1...100,
                          targetDelta: "+1")
        }
    }
    .padding(20)
    .background(Color.uplift.bgElev)
    .preferredColorScheme(.dark)
}
