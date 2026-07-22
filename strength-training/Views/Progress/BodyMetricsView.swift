//
//  BodyMetricsView.swift
//  strength-training
//
//  Home body measurements, trends, and muscularity index (Navy BF% → FFMI).
//

import SwiftUI
import SwiftData
import Charts

// MARK: - Progress dashboard card

struct BodyMetricsCard: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: BodyMetricsViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                NavigationLink {
                    BodyMetricsView(viewModel: vm)
                } label: {
                    BodyMetricsCardContent(viewModel: vm)
                }
                .buttonStyle(.plain)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.uplift.surface1)
                    }
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = BodyMetricsViewModel(modelContext: modelContext)
            } else {
                viewModel?.reload()
            }
        }
    }
}

private struct BodyMetricsCardContent: View {
    @Bindable var viewModel: BodyMetricsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Body")
                    .textCase(.uppercase)
                    .font(.uplift.text(11, weight: .semibold))
                    .tracking(0.4)
                    .foregroundStyle(Color.uplift.fgMuted)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.uplift.fgDim)
            }

            if let result = viewModel.composition {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Muscularity")
                            .font(.uplift.text(11, weight: .medium))
                            .foregroundStyle(Color.uplift.fgDim)
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Num(String(format: "%.1f", result.ffmi), size: 28, weight: .bold, color: .uplift.accent)
                            Text("FFMI")
                                .font(.uplift.text(12, weight: .medium))
                                .foregroundStyle(Color.uplift.fgMuted)
                        }
                        Text(result.muscularityLabel)
                            .font(.uplift.text(13, weight: .semibold))
                            .foregroundStyle(Color.uplift.fg)
                    }
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 8) {
                        miniStat(label: "Body fat", value: String(format: "%.1f%%", result.bodyFatPercent))
                        miniStat(label: "Lean", value: String(format: "%.0f lb", result.leanMassLbs))
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Log measurements for a muscularity index")
                        .font(.uplift.text(14, weight: .medium))
                        .foregroundStyle(Color.uplift.fg)
                    if !viewModel.missingForIndex.isEmpty {
                        Text("Need: \(viewModel.missingForIndex.joined(separator: ", "))")
                            .font(.uplift.text(12, weight: .medium))
                            .foregroundStyle(Color.uplift.fgDim)
                    }
                }
            }

            // Quick latest strip
            HStack(spacing: 0) {
                ForEach(Array(quickKinds.enumerated()), id: \.element.id) { index, kind in
                    if index > 0 {
                        Rectangle()
                            .fill(Color.uplift.hairline)
                            .frame(width: 1, height: 28)
                    }
                    quickMetric(kind)
                }
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.uplift.surface1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(cardAccessibility)
        .accessibilityHint("Opens body measurements")
    }

    private var quickKinds: [BodyMetricKind] { [.weight, .waist, .chest, .arm] }

    private func quickMetric(_ kind: BodyMetricKind) -> some View {
        let value = viewModel.latest(kind)?.value
        return VStack(alignment: .leading, spacing: 2) {
            Text(kind.title)
                .font(.uplift.text(10, weight: .semibold))
                .foregroundStyle(Color.uplift.fgDim)
            Text(value.map { formatMetric($0, kind: kind) } ?? "—")
                .font(.uplift.mono(13, weight: .semibold))
                .foregroundStyle(Color.uplift.fg)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    private func miniStat(label: String, value: String) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(label)
                .font(.uplift.text(10, weight: .medium))
                .foregroundStyle(Color.uplift.fgDim)
            Text(value)
                .font(.uplift.mono(13, weight: .semibold))
                .foregroundStyle(Color.uplift.fg)
        }
    }

    private var cardAccessibility: String {
        if let r = viewModel.composition {
            return "Body muscularity \(String(format: "%.1f", r.ffmi)) FFMI, \(r.muscularityLabel), body fat \(String(format: "%.1f", r.bodyFatPercent)) percent"
        }
        return "Body measurements. Need \(viewModel.missingForIndex.joined(separator: ", ")) for muscularity index"
    }
}

// MARK: - Full body metrics screen

struct BodyMetricsView: View {
    @Bindable var viewModel: BodyMetricsViewModel
    @AppStorage(BodyProfilePreferences.sexKey)
    private var sexRaw: String = BiologicalSex.male.rawValue
    @State private var showCheckIn = false
    @State private var chartKind: BodyMetricKind = .weight

    private var sex: BiologicalSex {
        BiologicalSex(rawValue: sexRaw) ?? .male
    }

    private var primaryMetrics: [BodyMetricKind] {
        BodyMetricKind.primary(for: sex)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                indexCard
                    .padding(.top, 8)
                SectionHeader("Measurements") {
                    Button {
                        showCheckIn = true
                    } label: {
                        Text("Log check-in")
                            .font(.uplift.text(13, weight: .semibold))
                            .foregroundStyle(Color.uplift.accent)
                    }
                }
                measurementsGrid
                SectionHeader("Trend")
                trendSection
                SectionHeader("Recent")
                recentHistory
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(Color.uplift.bgElev)
        .scrollIndicators(.hidden)
        .navigationTitle("Body")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showCheckIn) {
            BodyCheckInSheet(viewModel: viewModel)
        }
        .onAppear {
            viewModel.reload()
            clampChartKind()
        }
        .onChange(of: sexRaw) { _, _ in
            viewModel.reload()
            clampChartKind()
        }
    }

    private func clampChartKind() {
        if !primaryMetrics.contains(chartKind) {
            chartKind = primaryMetrics.first ?? .weight
        }
    }

    // MARK: Index

    private var indexCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Muscularity index")
                .textCase(.uppercase)
                .font(.uplift.text(11, weight: .semibold))
                .tracking(0.4)
                .foregroundStyle(Color.uplift.fgMuted)

            if let result = viewModel.composition {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Num(String(format: "%.1f", result.ffmi), size: 42, weight: .bold, color: .uplift.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("FFMI")
                            .font(.uplift.text(14, weight: .semibold))
                            .foregroundStyle(Color.uplift.fg)
                        Text(result.muscularityLabel)
                            .font(.uplift.text(13, weight: .medium))
                            .foregroundStyle(Color.uplift.fgMuted)
                    }
                    Spacer()
                }

                HStack(spacing: 12) {
                    Stat(label: "Body fat", value: String(format: "%.1f", result.bodyFatPercent), unit: "%")
                    Stat(label: "Lean mass", value: String(format: "%.0f", result.leanMassLbs), unit: "lb")
                    Stat(label: "Fat mass", value: String(format: "%.0f", result.fatMassLbs), unit: "lb")
                }

                Text(BodyMetricKind.accuracyDisclaimer)
                    .font(.uplift.text(11, weight: .medium))
                    .foregroundStyle(Color.uplift.fgDim)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                let needs = sex == .female
                    ? "waist (female), hips (female), and neck"
                    : "waist (male) and neck"
                Text("Add height in Settings and log \(needs) to unlock FFMI.")
                    .font(.uplift.text(14, weight: .medium))
                    .foregroundStyle(Color.uplift.fg)
                if !viewModel.missingForIndex.isEmpty {
                    Text("Still need: \(viewModel.missingForIndex.joined(separator: ", "))")
                        .font(.uplift.text(12, weight: .medium))
                        .foregroundStyle(Color.uplift.fgDim)
                }
                Text(BodyMetricKind.accuracyDisclaimer)
                    .font(.uplift.text(11, weight: .medium))
                    .foregroundStyle(Color.uplift.fgDim)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.uplift.surface1)
        }
    }

    // MARK: Measurements grid

    private var measurementsGrid: some View {
        VStack(spacing: 8) {
            ForEach(primaryMetrics) { kind in
                metricRow(kind)
            }
        }
    }

    private func metricRow(_ kind: BodyMetricKind) -> some View {
        let entry = viewModel.latest(kind)
        let delta = viewModel.delta(kind)
        let howTo = kind.howTo(for: sex)
        return Button {
            chartKind = kind
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: kind.systemImage)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(chartKind == kind ? Color.uplift.accent : Color.uplift.fgMuted)
                        .frame(width: 28)
                        .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(kind.title(for: sex))
                                .font(.uplift.text(15, weight: .semibold))
                                .foregroundStyle(Color.uplift.fg)
                            if let badge = kind.sexLabel(for: sex) {
                                sexBadge(badge)
                            }
                            if kind.isRequiredForIndex(sex: sex) {
                                Text("Index")
                                    .font(.uplift.text(10, weight: .bold))
                                    .foregroundStyle(Color.uplift.accent)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.uplift.accent.opacity(0.16)))
                            }
                        }
                        if let entry {
                            Text(entry.date, format: .dateTime.month(.abbreviated).day().year())
                                .font(.uplift.text(11, weight: .medium))
                                .foregroundStyle(Color.uplift.fgDim)
                        } else {
                            Text("Not logged")
                                .font(.uplift.text(11, weight: .medium))
                                .foregroundStyle(Color.uplift.fgDim)
                        }
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 2) {
                        if let entry {
                            HStack(alignment: .firstTextBaseline, spacing: 3) {
                                Text(formatMetric(entry.value, kind: kind))
                                    .font(.uplift.mono(17, weight: .semibold))
                                    .foregroundStyle(Color.uplift.fg)
                                Text(kind.unitLabel)
                                    .font(.uplift.text(12, weight: .medium))
                                    .foregroundStyle(Color.uplift.fgMuted)
                            }
                            if let delta {
                                Text(deltaText(delta, kind: kind))
                                    .font(.uplift.mono(11, weight: .semibold))
                                    .foregroundStyle(deltaColor(delta, kind: kind))
                            }
                        } else {
                            Text("—")
                                .font(.uplift.mono(17, weight: .semibold))
                                .foregroundStyle(Color.uplift.fgDim)
                        }
                    }
                }

                Text(howTo)
                    .font(.uplift.text(12, weight: .medium))
                    .foregroundStyle(Color.uplift.fgDim)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 40)
            }
            .padding(14)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.uplift.surface1)
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(
                                chartKind == kind ? Color.uplift.accent.opacity(0.45) : Color.clear,
                                lineWidth: 1
                            )
                    }
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint(howTo)
        .accessibilityLabel(kind.title(for: sex))
    }

    private func sexBadge(_ text: String) -> some View {
        Text(text)
            .font(.uplift.text(10, weight: .bold))
            .foregroundStyle(Color.uplift.fgMuted)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(Color.uplift.surface2))
    }

    // MARK: Trend

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(primaryMetrics) { kind in
                        FilterChip(label: kind.title(for: sex), isSelected: chartKind == kind) {
                            chartKind = kind
                        }
                    }
                }
            }

            let points = viewModel.chartPoints(for: chartKind)
            let chartTitle = chartKind.title(for: sex)
            Group {
                if points.count < 2 {
                    Text("Log at least two \(chartTitle.lowercased()) values to see a trend")
                        .font(.uplift.text(13, weight: .medium))
                        .foregroundStyle(Color.uplift.fgDim)
                        .frame(maxWidth: .infinity)
                        .frame(height: 160)
                } else {
                    Chart {
                        ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                            LineMark(
                                x: .value("Date", point.date),
                                y: .value(chartTitle, point.value)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Color.uplift.accent)

                            PointMark(
                                x: .value("Date", point.date),
                                y: .value(chartTitle, point.value)
                            )
                            .symbolSize(36)
                            .foregroundStyle(Color.uplift.accent)
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 4)) {
                            AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                                .font(.uplift.text(11, weight: .medium))
                                .foregroundStyle(Color.uplift.fgDim)
                        }
                    }
                    .chartYAxis {
                        AxisMarks {
                            AxisValueLabel()
                                .font(.uplift.text(11, weight: .medium))
                                .foregroundStyle(Color.uplift.fgDim)
                        }
                    }
                    .frame(height: 160)
                }
            }
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.uplift.surface1)
            }
        }
    }

    // MARK: History

    private var recentHistory: some View {
        let rows = viewModel.history(for: chartKind, limit: 12)
        return VStack(spacing: 0) {
            if rows.isEmpty {
                Text("No \(chartKind.title(for: sex).lowercased()) history yet")
                    .font(.uplift.text(13, weight: .medium))
                    .foregroundStyle(Color.uplift.fgDim)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            } else {
                ForEach(rows, id: \.id) { entry in
                    HStack {
                        Text(entry.date, format: .dateTime.month(.abbreviated).day().year())
                            .font(.uplift.text(14, weight: .medium))
                            .foregroundStyle(Color.uplift.fg)
                        Spacer()
                        Text("\(formatMetric(entry.value, kind: entry.kind)) \(entry.kind.unitLabel)")
                            .font(.uplift.mono(14, weight: .semibold))
                            .foregroundStyle(Color.uplift.fgMuted)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    if entry.id != rows.last?.id {
                        Divider().overlay(Color.uplift.hairline).padding(.leading, 16)
                    }
                }
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.uplift.surface1)
        }
    }

    // MARK: Formatting

    private func deltaText(_ delta: Double, kind: BodyMetricKind) -> String {
        let sign = delta > 0 ? "+" : ""
        return "\(sign)\(formatMetric(delta, kind: kind)) \(kind.unitLabel) · 30d"
    }

    private func deltaColor(_ delta: Double, kind: BodyMetricKind) -> Color {
        // For girths and weight, "down" is often desirable during a cut; keep neutral trend coloring by magnitude direction only.
        if abs(delta) < 0.05 { return Color.uplift.flat }
        return delta > 0 ? Color.uplift.up : Color.uplift.down
    }
}

// MARK: - Check-in sheet

private struct BodyCheckInSheet: View {
    @Bindable var viewModel: BodyMetricsViewModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage(BodyProfilePreferences.sexKey)
    private var sexRaw: String = BiologicalSex.male.rawValue

    @State private var date: Date = .now
    @State private var values: [BodyMetricKind: Double] = [:]

    private var sex: BiologicalSex {
        BiologicalSex(rawValue: sexRaw) ?? .male
    }

    private var primaryMetrics: [BodyMetricKind] {
        BodyMetricKind.primary(for: sex)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
                .listRowBackground(Color.uplift.surface1)

                Section {
                    ForEach(primaryMetrics) { kind in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .firstTextBaseline) {
                                Label(kind.title(for: sex), systemImage: kind.systemImage)
                                    .font(.uplift.text(15, weight: .medium))
                                    .foregroundStyle(Color.uplift.fg)
                                Spacer()
                                TextField(
                                    kind.unitLabel,
                                    value: binding(for: kind),
                                    format: .number.precision(.fractionLength(0...1))
                                )
                                .font(.uplift.mono(15, weight: .semibold))
                                .foregroundStyle(Color.uplift.accent)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.decimalPad)
                                .frame(width: 72)
                                Text(kind.unitLabel)
                                    .font(.uplift.text(13, weight: .medium))
                                    .foregroundStyle(Color.uplift.fgDim)
                            }
                            Text(kind.howTo(for: sex))
                                .font(.uplift.text(12, weight: .medium))
                                .foregroundStyle(Color.uplift.fgDim)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 2)
                        .accessibilityElement(children: .combine)
                    }
                } header: {
                    Text("Measurements")
                } footer: {
                    Text(checkInFooter)
                }
                .listRowBackground(Color.uplift.surface1)
            }
            .scrollContentBackground(.hidden)
            .background(Color.uplift.bgElev)
            .navigationTitle("Body check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        // Only persist metrics relevant to the selected sex.
                        let allowed = Set(primaryMetrics)
                        let filtered = values.filter { allowed.contains($0.key) && $0.value > 0 }
                        viewModel.logCheckIn(filtered, date: date)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(values.values.allSatisfy { $0 <= 0 })
                }
            }
            .onAppear { seedFromLatest() }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large])
    }

    private var checkInFooter: String {
        let needed: String
        switch sex {
        case .male:
            needed = "Male formula: weight, waist (at navel), and neck. Hips not used. Chest & arm are optional trends."
        case .female:
            needed = "Female formula: weight, waist (narrowest), hips, and neck. Chest & arm are optional trends."
        }
        return "\(needed) \(BodyMetricKind.accuracyDisclaimer)"
    }

    private func binding(for kind: BodyMetricKind) -> Binding<Double> {
        Binding(
            get: { values[kind] ?? 0 },
            set: { values[kind] = $0 }
        )
    }

    private func seedFromLatest() {
        for kind in primaryMetrics {
            if let latest = viewModel.latest(kind) {
                values[kind] = latest.value
            } else if kind == .weight, BodyWeightPreferences.pounds > 0 {
                values[kind] = BodyWeightPreferences.pounds
            }
        }
    }
}

// MARK: - Shared formatting

private func formatMetric(_ value: Double, kind: BodyMetricKind) -> String {
    if kind == .weight {
        return StepperLogic.format(value)
    }
    // Girths: one decimal when needed
    if value.rounded() == value {
        return String(format: "%.0f", value)
    }
    return String(format: "%.1f", value)
}

#Preview("Body metrics") {
    NavigationStack {
        BodyMetricsView(viewModel: BodyMetricsViewModel(modelContext: previewContainer.mainContext))
    }
    .modelContainer(previewContainer)
    .preferredColorScheme(.dark)
}
