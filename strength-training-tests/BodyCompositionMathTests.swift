//
//  BodyCompositionMathTests.swift
//  strength-training-tests
//

import XCTest
@testable import strength_training

final class BodyCompositionMathTests: XCTestCase {

    // MARK: - Navy body fat

    func test_navyMale_typicalLifter() {
        // ~5'10", 180 lb, 34" waist, 15.5" neck — roughly athletic male mid-teens BF
        let input = BodyCompositionMath.Inputs(
            weightLbs: 180,
            heightInches: 70,
            waistInches: 34,
            neckInches: 15.5,
            hipsInches: nil,
            sex: .male
        )
        let bf = BodyCompositionMath.navyBodyFatPercent(input)
        XCTAssertNotNil(bf)
        guard let bf else { return }
        XCTAssertGreaterThan(bf, 10)
        XCTAssertLessThan(bf, 22)
    }

    func test_navyFemale_requiresHips() {
        let noHips = BodyCompositionMath.Inputs(
            weightLbs: 140,
            heightInches: 65,
            waistInches: 28,
            neckInches: 13,
            hipsInches: nil,
            sex: .female
        )
        XCTAssertNil(BodyCompositionMath.navyBodyFatPercent(noHips))

        let withHips = BodyCompositionMath.Inputs(
            weightLbs: 140,
            heightInches: 65,
            waistInches: 28,
            neckInches: 13,
            hipsInches: 38,
            sex: .female
        )
        let bf = BodyCompositionMath.navyBodyFatPercent(withHips)
        XCTAssertNotNil(bf)
        guard let bf else { return }
        XCTAssertGreaterThan(bf, 12)
        XCTAssertLessThan(bf, 35)
    }

    func test_navyMale_invalidWhenWaistNotLargerThanNeck() {
        let input = BodyCompositionMath.Inputs(
            weightLbs: 180,
            heightInches: 70,
            waistInches: 14,
            neckInches: 15,
            hipsInches: nil,
            sex: .male
        )
        XCTAssertNil(BodyCompositionMath.navyBodyFatPercent(input))
    }

    // MARK: - FFMI / compose

    func test_ffmi_andCompose() {
        let input = BodyCompositionMath.Inputs(
            weightLbs: 180,
            heightInches: 70,
            waistInches: 32,
            neckInches: 16,
            hipsInches: nil,
            sex: .male
        )
        let result = BodyCompositionMath.compose(input)
        XCTAssertNotNil(result)
        guard let result else { return }

        XCTAssertEqual(
            result.leanMassLbs + result.fatMassLbs,
            input.weightLbs,
            accuracy: 0.01
        )
        // FFMI for a lean-ish 180 lb man at 5'10" should land in a plausible band
        XCTAssertGreaterThan(result.ffmi, 18)
        XCTAssertLessThan(result.ffmi, 26)
        XCTAssertFalse(result.muscularityLabel.isEmpty)
    }

    func test_muscularityLabels_male() {
        XCTAssertEqual(BodyCompositionMath.muscularityLabel(ffmi: 16, sex: .male), "Light")
        XCTAssertEqual(BodyCompositionMath.muscularityLabel(ffmi: 18, sex: .male), "Average")
        XCTAssertEqual(BodyCompositionMath.muscularityLabel(ffmi: 20, sex: .male), "Athletic")
        XCTAssertEqual(BodyCompositionMath.muscularityLabel(ffmi: 22, sex: .male), "Muscular")
        XCTAssertEqual(BodyCompositionMath.muscularityLabel(ffmi: 24, sex: .male), "Very muscular")
        XCTAssertEqual(BodyCompositionMath.muscularityLabel(ffmi: 26, sex: .male), "Elite")
    }

    func test_muscularityLabels_femaleShifted() {
        // Female bands shift +2.5 on the adjusted scale
        XCTAssertEqual(BodyCompositionMath.muscularityLabel(ffmi: 16, sex: .female), "Average")
        XCTAssertEqual(BodyCompositionMath.muscularityLabel(ffmi: 18, sex: .female), "Athletic")
    }

    // MARK: - Latest / delta / inputs from entries

    @MainActor
    func test_latestAndDelta() {
        let calendar = Calendar(identifier: .gregorian)
        let asOf = calendar.date(from: DateComponents(year: 2026, month: 6, day: 15))!
        let older = calendar.date(byAdding: .day, value: -40, to: asOf)!
        let mid = calendar.date(byAdding: .day, value: -10, to: asOf)!

        let e1 = BodyMetricEntry(kind: .waist, value: 36, date: older)
        let e2 = BodyMetricEntry(kind: .waist, value: 34, date: mid)
        let e3 = BodyMetricEntry(kind: .waist, value: 33, date: asOf)
        let entries = [e1, e2, e3]

        let latest = BodyCompositionMath.latest(kind: .waist, in: entries, asOf: asOf)
        XCTAssertEqual(latest?.value, 33)

        let delta = BodyCompositionMath.delta(
            kind: .waist,
            in: entries,
            days: 30,
            asOf: asOf,
            calendar: calendar
        )
        // 30d window: past as-of is ~May 16. Only e1 (40d ago) is on/before that. Delta = 33 − 36 = −3.
        XCTAssertNotNil(delta)
        XCTAssertEqual(delta ?? 0, -3, accuracy: 0.001)
    }

    @MainActor
    func test_inputsFromEntries_male() {
        let entries = [
            BodyMetricEntry(kind: .weight, value: 185, date: .now),
            BodyMetricEntry(kind: .waist, value: 33, date: .now),
            BodyMetricEntry(kind: .neck, value: 15.5, date: .now),
            BodyMetricEntry(kind: .chest, value: 42, date: .now),
        ]
        let inputs = BodyCompositionMath.inputs(
            from: entries,
            heightInches: 71,
            sex: .male
        )
        XCTAssertNotNil(inputs)
        XCTAssertEqual(inputs?.weightLbs, 185)
        XCTAssertNil(BodyCompositionMath.inputs(from: entries, heightInches: 0, sex: .male))
    }

    func test_primaryMetrics_hidesHipsForMale() {
        let male = BodyMetricKind.primary(for: .male)
        XCTAssertFalse(male.contains(.hips))
        XCTAssertTrue(male.contains(.waist))
        XCTAssertTrue(male.contains(.neck))

        let female = BodyMetricKind.primary(for: .female)
        XCTAssertTrue(female.contains(.hips))
        XCTAssertTrue(female.contains(.waist))
        XCTAssertEqual(BodyMetricKind.waist.title(for: .male), "Waist (male)")
        XCTAssertEqual(BodyMetricKind.waist.title(for: .female), "Waist (female)")
        XCTAssertEqual(BodyMetricKind.hips.title(for: .female), "Hips (female)")
    }

    @MainActor
    func test_inputsFromEntries_femaleNeedsHips() {
        let withoutHips = [
            BodyMetricEntry(kind: .weight, value: 140, date: .now),
            BodyMetricEntry(kind: .waist, value: 28, date: .now),
            BodyMetricEntry(kind: .neck, value: 13, date: .now),
        ]
        XCTAssertNil(BodyCompositionMath.inputs(from: withoutHips, heightInches: 65, sex: .female))

        let withHips = withoutHips + [BodyMetricEntry(kind: .hips, value: 38, date: .now)]
        XCTAssertNotNil(BodyCompositionMath.inputs(from: withHips, heightInches: 65, sex: .female))
    }
}
