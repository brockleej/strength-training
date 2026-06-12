//
//  StepperLogic.swift
//  strength-training
//
//  Pure stepper math, separated from UpliftStepper so it's unit-testable.
//

import Foundation

enum StepperLogic {
    static func increment(_ value: Double, step: Double, max: Double) -> Double {
        Swift.min(value + step, max)
    }

    static func decrement(_ value: Double, step: Double, min: Double) -> Double {
        Swift.max(value - step, min)
    }

    /// "235" for whole numbers, "47.5" otherwise.
    static func format(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(value))
            : String(format: "%.1f", value)
    }
}
