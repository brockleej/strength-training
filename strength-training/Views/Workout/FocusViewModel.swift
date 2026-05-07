import SwiftUI

/// Per-FocusView state — current input values, whether the system-suggested target
/// is still applied (drives the blue bumped state on UpliftStepper), and the rest
/// timer that ticks up between sets and resets on log.
@Observable
final class FocusViewModel {
    /// Snapshot of the system's suggested target for this exercise + mode.
    /// `weight` and `reps` are the absolute values to apply; `weightDelta` /
    /// `repsDelta` are the differences from the user's last session (drive the
    /// "↑ +5 LB TARGET" overline). Either delta can be 0.
    struct Target: Equatable {
        let weight: Double
        let weightDelta: Double
        let reps: Int
        let repsDelta: Int
    }

    var weight: Double
    var reps: Int
    private(set) var isTargetActive: Bool
    private(set) var weightDelta: Double
    private(set) var repsDelta: Int

    /// Seconds since the last `setLogged()`. Mutated by FocusActionBar's 1Hz timer.
    var restTimerSeconds: TimeInterval = 0

    init(initialWeight: Double, initialReps: Int, target: Target?) {
        self.weight = initialWeight
        self.reps = initialReps
        if let target {
            self.isTargetActive = true
            self.weightDelta = target.weightDelta
            self.repsDelta = target.repsDelta
        } else {
            self.isTargetActive = false
            self.weightDelta = 0
            self.repsDelta = 0
        }
    }

    /// Called by FocusStepperFooter when the user taps +/- on weight.
    /// Clears the bumped state — once the user adjusts, the value is theirs.
    func userEditedWeight() {
        isTargetActive = false
    }

    /// Called by FocusStepperFooter when the user taps +/- on reps.
    func userEditedReps() {
        isTargetActive = false
    }

    /// Called when a set is successfully persisted. Resets the rest timer.
    /// Note: `isTargetActive` stays as-is — logging a set at the bumped value
    /// keeps the visual "you're on the target" cue. Only manual edits clear it.
    func setLogged() {
        restTimerSeconds = 0
    }

    static func formatRest(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}
