import SwiftUI

/// Pure-function stepper math — separated from the SwiftUI view so it's unit-testable.
/// Used by `UpliftStepper` to compute new values on +/- press.
struct StepperLogic {
    let value: Double
    let step: Double
    let min: Double
    let max: Double

    func incremented() -> Double { Swift.min(value + step, max) }
    func decremented() -> Double { Swift.max(value - step, min) }
}

/// +/- stepper for weight or reps inputs. Two visual states:
/// - **neutral** (default) — `surface1` card, white text, gray "± step" hint
/// - **bumped** (when `targetDelta != nil`) — accent-tinted card, blue text, "↑ +5 LB TARGET" overline
///
/// The bumped state surfaces system-suggested progressive-overload targets. Editing either stepper
/// (calling +/-) externally clears the target — this is enforced by the parent view, not here.
///
/// `value` is `Binding<Double>` so the stepper can drive a single source of truth in the parent.
/// `step` controls increment/decrement size. `range` enforces clamping.
///
/// Hold-to-repeat: pressing and holding +/- continues to fire at 80ms intervals after a 400ms delay.
///
/// ```swift
/// @State private var weight: Double = 235
/// // neutral
/// UpliftStepper(label: "Weight", unit: "lb", value: $weight, step: 5, range: 0...1000)
/// // bumped (system suggests +5 lb target)
/// UpliftStepper(label: "Weight", unit: "lb", value: $weight, step: 5, range: 0...1000,
///               targetDelta: .weight(plus: 5))
/// ```
struct UpliftStepper: View {
    enum TargetDelta: Equatable {
        case weight(plus: Double)
        case reps(plus: Int)

        var overlineText: String {
            switch self {
            case .weight(let p): "↑ +\(formatWeight(p)) LB TARGET"
            case .reps(let p):   "↑ +\(p) REPS TARGET"
            }
        }

        private func formatWeight(_ v: Double) -> String {
            v.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(v)) : String(format: "%.1f", v)
        }
    }

    let label: String
    var unit: String? = nil
    @Binding var value: Double
    let step: Double
    let range: ClosedRange<Double>
    var targetDelta: TargetDelta? = nil

    /// Called when the user manually adjusts via +/-. Parent uses this to clear `targetDelta`.
    var onUserEdit: (() -> Void)? = nil

    @State private var holdTask: Task<Void, Never>? = nil

    var body: some View {
        VStack(spacing: 10) {
            label_
            stepperRow
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(cardBg)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(cardBorder, lineWidth: 0.5)
        }
        .animation(.easeInOut(duration: 0.2), value: targetDelta)
        .onDisappear { stopHold() }
    }

    private var label_: some View {
        let labelText = unit.map { "\(label) (\($0))" } ?? label
        return HStack(spacing: 4) {
            if let target = targetDelta {
                Text(target.overlineText)
                    .font(.uplift.text(11, weight: .semibold))
                    .tracking(0.4)
                    .foregroundStyle(Color.uplift.accent)
            } else {
                Text(labelText.uppercased())
                    .font(.uplift.text(11, weight: .semibold))
                    .tracking(0.4)
                    .foregroundStyle(Color.uplift.fgMuted)
            }
        }
    }

    private var stepperRow: some View {
        HStack(spacing: 4) {
            roundButton(symbol: "−", isAccentFilled: false) { decrement() }

            VStack(spacing: 4) {
                Num(formatValue(value), size: 40, weight: .bold, color: tintColor)
                Text("± \(formatStep(step))")
                    .font(.uplift.text(10, weight: .medium))
                    .tracking(0.3)
                    .foregroundStyle(Color.uplift.fgDim)
            }
            .frame(maxWidth: .infinity)

            roundButton(symbol: "+", isAccentFilled: targetDelta != nil) { increment() }
        }
    }

    private func roundButton(symbol: String, isAccentFilled: Bool, action: @escaping () -> Void) -> some View {
        // Custom press handling so a quick tap fires once + a long hold repeats.
        // Using DragGesture(minimumDistance: 0) instead of Button so the press-state machine
        // is fully under our control (avoids Button's gesture interfering with hold detection).
        Text(symbol)
            .font(.system(size: 22, weight: .medium))
            .foregroundStyle(isAccentFilled ? Color.uplift.onAccent : Color.uplift.fg)
            .frame(width: 44, height: 44)
            .background {
                Circle().fill(isAccentFilled ? Color.uplift.accent : Color.uplift.surface2)
            }
            .contentShape(Circle())
            .accessibilityLabel(symbol == "+" ? "Increase" : "Decrease")
            .accessibilityAddTraits(.isButton)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if holdTask == nil { startHold(action: action) }
                    }
                    .onEnded { _ in stopHold() }
            )
    }

    // ─── Hold-to-repeat ────────────────────────────────────────
    private func startHold(action: @escaping () -> Void) {
        action()  // fire once immediately
        holdTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)  // 400ms warm-up
            while !Task.isCancelled {
                action()
                try? await Task.sleep(nanoseconds: 80_000_000)  // 80ms repeat
            }
        }
    }

    private func stopHold() {
        holdTask?.cancel()
        holdTask = nil
    }

    // ─── Adjustments ───────────────────────────────────────────
    private func increment() {
        let logic = StepperLogic(value: value, step: step, min: range.lowerBound, max: range.upperBound)
        value = logic.incremented()
        onUserEdit?()
    }

    private func decrement() {
        let logic = StepperLogic(value: value, step: step, min: range.lowerBound, max: range.upperBound)
        value = logic.decremented()
        onUserEdit?()
    }

    // ─── Styling ───────────────────────────────────────────────
    private var tintColor: Color { targetDelta != nil ? .uplift.accent : .uplift.fg }
    private var cardBg: Color { targetDelta != nil ? Color.uplift.accent.opacity(0.10) : Color.uplift.surface1 }
    private var cardBorder: Color { targetDelta != nil ? Color.uplift.accent.opacity(0.55) : .clear }

    private func formatValue(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(v)) : String(format: "%.1f", v)
    }

    private func formatStep(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(v)) : String(format: "%.1f", v)
    }
}

#Preview("UpliftStepper — neutral + bumped") {
    @Previewable @State var weight: Double = 235
    @Previewable @State var reps: Double = 5

    return VStack(spacing: 20) {
        // Neutral pair
        HStack(spacing: 10) {
            UpliftStepper(label: "Weight", unit: "lb", value: $weight, step: 5, range: 0...1000)
            UpliftStepper(label: "Reps", value: $reps, step: 1, range: 1...100)
        }

        // Bumped pair (system-suggested target +5 lb / +1 rep)
        HStack(spacing: 10) {
            UpliftStepper(label: "Weight", unit: "lb", value: .constant(235), step: 5, range: 0...1000,
                          targetDelta: .weight(plus: 5))
            UpliftStepper(label: "Reps", value: .constant(5), step: 1, range: 1...100,
                          targetDelta: .reps(plus: 1))
        }

        // Half-pound steps
        HStack(spacing: 10) {
            UpliftStepper(label: "Weight", unit: "lb", value: .constant(47.5), step: 2.5, range: 0...1000)
            UpliftStepper(label: "Reps", value: .constant(8), step: 1, range: 1...100)
        }
    }
    .padding(20)
    .background(Color.uplift.bgElev)
}
