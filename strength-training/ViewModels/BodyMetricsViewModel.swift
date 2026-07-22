//
//  BodyMetricsViewModel.swift
//  strength-training
//

import Foundation
import SwiftData

@Observable
@MainActor
final class BodyMetricsViewModel {
    private let modelContext: ModelContext

    private(set) var entries: [BodyMetricEntry] = []
    private(set) var composition: BodyCompositionMath.Result?
    private(set) var missingForIndex: [String] = []

    /// Trend window for deltas (days).
    var trendDays: Int = 30

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        reload()
    }

    func reload() {
        let descriptor = FetchDescriptor<BodyMetricEntry>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        entries = (try? modelContext.fetch(descriptor)) ?? []
        recomputeComposition()
    }

    func latest(_ kind: BodyMetricKind) -> BodyMetricEntry? {
        BodyCompositionMath.latest(kind: kind, in: entries)
    }

    func delta(_ kind: BodyMetricKind) -> Double? {
        BodyCompositionMath.delta(kind: kind, in: entries, days: trendDays)
    }

    func history(for kind: BodyMetricKind, limit: Int = 40) -> [BodyMetricEntry] {
        entries.filter { $0.kind == kind }.prefix(limit).map { $0 }
    }

    /// Chart points oldest → newest for a kind.
    func chartPoints(for kind: BodyMetricKind, limit: Int = 60) -> [(date: Date, value: Double)] {
        history(for: kind, limit: limit)
            .reversed()
            .map { ($0.date, $0.value) }
    }

    @discardableResult
    func log(kind: BodyMetricKind, value: Double, date: Date = .now, note: String = "") -> BodyMetricEntry? {
        guard value > 0 else { return nil }
        let entry = BodyMetricEntry(kind: kind, value: value, date: date, note: note)
        modelContext.insert(entry)
        // Keep assisted-lift body weight in sync.
        if kind == .weight {
            BodyWeightPreferences.pounds = value
        }
        try? modelContext.save()
        reload()
        return entry
    }

    /// Log several metrics for one check-in date.
    func logCheckIn(_ values: [BodyMetricKind: Double], date: Date = .now) {
        for (kind, value) in values where value > 0 {
            let entry = BodyMetricEntry(kind: kind, value: value, date: date)
            modelContext.insert(entry)
            if kind == .weight {
                BodyWeightPreferences.pounds = value
            }
        }
        try? modelContext.save()
        reload()
    }

    func delete(_ entry: BodyMetricEntry) {
        modelContext.delete(entry)
        try? modelContext.save()
        reload()
    }

    /// Weight for composition: latest log, else Settings body weight.
    var effectiveWeightLbs: Double? {
        if let w = latest(.weight)?.value, w > 0 { return w }
        let prefs = BodyWeightPreferences.pounds
        return prefs > 0 ? prefs : nil
    }

    private func recomputeComposition() {
        let height = BodyProfilePreferences.heightInches
        let sex = BodyProfilePreferences.sex
        missingForIndex = missingRequirements(height: height, sex: sex)

        guard let inputs = compositionInputs(height: height, sex: sex) else {
            composition = nil
            return
        }
        composition = BodyCompositionMath.compose(inputs)
    }

    private func compositionInputs(height: Double, sex: BiologicalSex) -> BodyCompositionMath.Inputs? {
        guard height > 0,
              let weight = effectiveWeightLbs,
              let waist = latest(.waist)?.value,
              let neck = latest(.neck)?.value
        else { return nil }

        let hips = latest(.hips)?.value
        if sex == .female && (hips == nil || (hips ?? 0) <= 0) {
            return nil
        }

        return BodyCompositionMath.Inputs(
            weightLbs: weight,
            heightInches: height,
            waistInches: waist,
            neckInches: neck,
            hipsInches: hips,
            sex: sex
        )
    }

    private func missingRequirements(height: Double, sex: BiologicalSex) -> [String] {
        var missing: [String] = []
        if height <= 0 { missing.append("Height (Settings)") }
        if effectiveWeightLbs == nil { missing.append("Weight") }
        if latest(.waist) == nil { missing.append(BodyMetricKind.waist.title(for: sex)) }
        if latest(.neck) == nil { missing.append("Neck") }
        if sex == .female && latest(.hips) == nil {
            missing.append(BodyMetricKind.hips.title(for: sex))
        }
        return missing
    }
}
