//
//  BodyCompositionMath.swift
//  strength-training
//
//  Home anthropometrics → body fat (US Navy) → FFMI muscularity index.
//  All girths/height in inches; weight in pounds (converted for FFMI).
//

import Foundation

enum BodyCompositionMath {

    struct Inputs: Equatable {
        var weightLbs: Double
        var heightInches: Double
        var waistInches: Double
        var neckInches: Double
        var hipsInches: Double?   // required for female Navy formula
        var sex: BiologicalSex
    }

    struct Result: Equatable {
        /// Estimated body fat % (Navy).
        var bodyFatPercent: Double
        /// Fat-free mass index (kg/m²) — primary muscularity index.
        var ffmi: Double
        /// Fat-free mass in pounds.
        var leanMassLbs: Double
        /// Fat mass in pounds.
        var fatMassLbs: Double
        /// Short label for FFMI band.
        var muscularityLabel: String
    }

    // MARK: - Navy body fat (circumference method)

    /// US Navy method. Returns nil if measurements are incomplete or invalid.
    static func navyBodyFatPercent(_ input: Inputs) -> Double? {
        guard input.weightLbs > 0, input.heightInches > 0,
              input.waistInches > 0, input.neckInches > 0
        else { return nil }

        switch input.sex {
        case .male:
            // abdomen ≈ waist at navel
            let diff = input.waistInches - input.neckInches
            guard diff > 0 else { return nil }
            let bf = 86.010 * log10(diff) - 70.041 * log10(input.heightInches) + 36.76
            return clampBF(bf)
        case .female:
            guard let hips = input.hipsInches, hips > 0 else { return nil }
            let sum = input.waistInches + hips - input.neckInches
            guard sum > 0 else { return nil }
            let bf = 163.205 * log10(sum) - 97.684 * log10(input.heightInches) - 78.387
            return clampBF(bf)
        }
    }

    // MARK: - FFMI

    /// Fat-free mass index from weight and body-fat %.
    static func ffmi(weightLbs: Double, bodyFatPercent: Double, heightInches: Double) -> Double? {
        guard weightLbs > 0, heightInches > 0,
              bodyFatPercent >= 0, bodyFatPercent < 60
        else { return nil }
        let weightKg = weightLbs * 0.45359237
        let heightM = heightInches * 0.0254
        guard heightM > 0 else { return nil }
        let ffmKg = weightKg * (1 - bodyFatPercent / 100)
        return ffmKg / (heightM * heightM)
    }

    static func compose(_ input: Inputs) -> Result? {
        guard let bf = navyBodyFatPercent(input),
              let index = ffmi(
                weightLbs: input.weightLbs,
                bodyFatPercent: bf,
                heightInches: input.heightInches
              )
        else { return nil }

        let lean = input.weightLbs * (1 - bf / 100)
        let fat = input.weightLbs - lean
        return Result(
            bodyFatPercent: bf,
            ffmi: index,
            leanMassLbs: lean,
            fatMassLbs: fat,
            muscularityLabel: muscularityLabel(ffmi: index, sex: input.sex)
        )
    }

    /// Practical FFMI bands for hobby lifters (not medical diagnosis).
    static func muscularityLabel(ffmi: Double, sex: BiologicalSex) -> String {
        // Female bands are shifted down ~ a few points vs male norms.
        let adjusted = sex == .female ? ffmi + 2.5 : ffmi
        switch adjusted {
        case ..<17: return "Light"
        case 17..<19: return "Average"
        case 19..<21: return "Athletic"
        case 21..<23: return "Muscular"
        case 23..<25: return "Very muscular"
        default: return "Elite"
        }
    }

    // MARK: - Trends

    /// Latest value on or before `asOf` for a kind.
    static func latest(
        kind: BodyMetricKind,
        in entries: [BodyMetricEntry],
        asOf: Date = .now
    ) -> BodyMetricEntry? {
        entries
            .filter { $0.kind == kind && $0.date <= asOf }
            .max(by: { $0.date < $1.date })
    }

    /// Delta: latest − value from ~`days` ago (nearest entry on or before that date).
    static func delta(
        kind: BodyMetricKind,
        in entries: [BodyMetricEntry],
        days: Int,
        asOf: Date = .now,
        calendar: Calendar = .current
    ) -> Double? {
        guard let current = latest(kind: kind, in: entries, asOf: asOf),
              let pastDate = calendar.date(byAdding: .day, value: -days, to: asOf),
              let past = latest(kind: kind, in: entries, asOf: pastDate)
        else { return nil }
        // If past entry is the same as current (only one data point), no trend yet.
        guard past.id != current.id else { return nil }
        return current.value - past.value
    }

    /// Build Navy/FFMI inputs from a flat list of metric entries + profile.
    static func inputs(
        from entries: [BodyMetricEntry],
        heightInches: Double,
        sex: BiologicalSex,
        asOf: Date = .now
    ) -> Inputs? {
        guard heightInches > 0,
              let w = latest(kind: .weight, in: entries, asOf: asOf)?.value,
              let waist = latest(kind: .waist, in: entries, asOf: asOf)?.value,
              let neck = latest(kind: .neck, in: entries, asOf: asOf)?.value
        else { return nil }

        let hips = latest(kind: .hips, in: entries, asOf: asOf)?.value
        if sex == .female && (hips == nil || (hips ?? 0) <= 0) {
            return nil
        }

        return Inputs(
            weightLbs: w,
            heightInches: heightInches,
            waistInches: waist,
            neckInches: neck,
            hipsInches: hips,
            sex: sex
        )
    }

    private static func clampBF(_ value: Double) -> Double? {
        guard value.isFinite else { return nil }
        // Navy can blow up on bad girths; keep in a sane display range.
        guard value > 2, value < 60 else { return nil }
        return value
    }

    private static func log10(_ x: Double) -> Double {
        Foundation.log10(x)
    }
}
