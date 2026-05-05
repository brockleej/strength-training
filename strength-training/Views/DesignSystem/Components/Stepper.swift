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
