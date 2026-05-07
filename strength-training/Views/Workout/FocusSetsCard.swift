// strength-training/Views/Workout/FocusSetsCard.swift
import SwiftUI

/// Card showing logged sets for the current exercise in the active session.
/// Long-press a row → "Delete set" context menu. No active-row preview — the
/// active inputs live in the FocusStepperFooter below.
struct FocusSetsCard: View {
    /// Sets in display order (1, 2, 3...).
    let sets: [SetRecord]
    /// Called when the user long-presses a set and confirms deletion.
    let onDelete: (SetRecord) -> Void

    var body: some View {
        VStack(spacing: 0) {
            headerRow
            if sets.isEmpty {
                emptyState
            } else {
                ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
                    setRow(set, isLast: index == sets.count - 1)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.uplift.surface1)
        }
    }

    private var headerRow: some View {
        HStack {
            Text("SET")
                .font(.uplift.text(11, weight: .bold))
                .tracking(0.4)
                .foregroundStyle(Color.uplift.fgMuted)
            Spacer()
            HStack(spacing: 32) {
                Text("WEIGHT")
                    .font(.uplift.text(11, weight: .bold))
                    .tracking(0.4)
                    .foregroundStyle(Color.uplift.fgMuted)
                    .frame(width: 48, alignment: .trailing)
                Text("REPS")
                    .font(.uplift.text(11, weight: .bold))
                    .tracking(0.4)
                    .foregroundStyle(Color.uplift.fgMuted)
                    .frame(width: 36, alignment: .trailing)
                Color.clear.frame(width: 16)
            }
        }
        .padding(.bottom, 8)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.uplift.hairline)
                .frame(height: 0.5)
        }
    }

    private func setRow(_ set: SetRecord, isLast: Bool) -> some View {
        HStack {
            HStack(spacing: 8) {
                ZStack {
                    Circle().fill(Color.uplift.up.opacity(0.16))
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.uplift.up)
                }
                .frame(width: 22, height: 22)
                Num(set.setNumber, size: 14, color: .uplift.fg)
            }
            Spacer()
            HStack(spacing: 32) {
                Num(formatWeight(set.weightLbs), size: 14, color: .uplift.fg)
                    .frame(width: 48, alignment: .trailing)
                Num(set.reps, size: 14, color: .uplift.fg)
                    .frame(width: 36, alignment: .trailing)
                Image(systemName: "ellipsis")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.uplift.fgDim)
                    .frame(width: 16, alignment: .trailing)
            }
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .fill(Color.uplift.hairline)
                    .frame(height: 0.5)
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                onDelete(set)
            } label: {
                Label("Delete Set", systemImage: "trash")
            }
        }
    }

    private var emptyState: some View {
        Text("No sets logged yet")
            .font(.uplift.text(13, weight: .medium))
            .foregroundStyle(Color.uplift.fgDim)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
    }

    private func formatWeight(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(v)) : String(format: "%.1f", v)
    }
}

// Preview omitted — SetRecord requires a SwiftData container; verified visually by FocusView preview.
