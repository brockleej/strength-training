//
//  ReplayTable.swift
//  ProgressionLab
//

import SwiftUI

struct ReplayTable: View {
    let sessions: [SessionReplay]   // chronological; reversed for display
    let configAName: String
    let configBName: String

    private var rows: [SessionReplay] { sessions.reversed() }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(rows) { row in
                        rowView(row)
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Date").frame(width: 110, alignment: .leading)
            Text("Actual").frame(width: 100, alignment: .leading)
            Text(configAName).frame(width: 130, alignment: .leading).foregroundStyle(.blue)
            Text("A basis").frame(width: 110, alignment: .leading).foregroundStyle(.secondary)
            Text(configBName).frame(width: 130, alignment: .leading).foregroundStyle(.orange)
            Text("B basis").frame(width: 110, alignment: .leading).foregroundStyle(.secondary)
            Text("Agreed?").frame(width: 80, alignment: .leading)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.secondary.opacity(0.1))
    }

    private func rowView(_ row: SessionReplay) -> some View {
        HStack(spacing: 8) {
            Text(row.sessionDate.formatted(date: .abbreviated, time: .omitted))
                .frame(width: 110, alignment: .leading)
                .monospacedDigit()
            Text("\(Int(row.actualBestSet.weightLbs)) × \(row.actualBestSet.reps)")
                .frame(width: 100, alignment: .leading)
                .monospacedDigit()
            suggestionCell(row.suggestionA)
                .frame(width: 130, alignment: .leading)
            basisCell(row.suggestionA?.basis)
                .frame(width: 110, alignment: .leading)
            suggestionCell(row.suggestionB)
                .frame(width: 130, alignment: .leading)
            basisCell(row.suggestionB?.basis)
                .frame(width: 110, alignment: .leading)
            agreedCell(row)
                .frame(width: 80, alignment: .leading)
        }
        .font(.callout)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(row.isDisagreement ? Color.red.opacity(0.06) : Color.clear)
    }

    @ViewBuilder
    private func suggestionCell(_ suggestion: ProgressionSuggestion?) -> some View {
        if let s = suggestion {
            Text("\(Int(s.targetWeight)) × \(s.targetReps)").monospacedDigit()
        } else {
            Text("—").foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func basisCell(_ basis: ProgressionSuggestion.Basis?) -> some View {
        if let b = basis {
            Text(label(for: b)).foregroundStyle(.secondary).font(.caption)
        } else {
            Text("—").foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func agreedCell(_ row: SessionReplay) -> some View {
        if !row.isEligibleForComparison {
            Text("—").foregroundStyle(.secondary)
        } else if row.isDisagreement {
            Text("✗").foregroundStyle(.red)
        } else {
            Text("✓").foregroundStyle(.green)
        }
    }

    private func label(for basis: ProgressionSuggestion.Basis) -> String {
        switch basis {
        case .consistent: return "consistent"
        case .improving: return "improving"
        case .notEnoughData: return "not enough data"
        }
    }
}
