//
//  CompareGridTable.swift
//  Shared spreadsheet for RockCoach and RockLog Progress.
//  Lift names stay put; session columns scroll sideways.
//

import SwiftUI

struct CompareGridPalette {
    var background: Color
    var surface: Color
    var foreground: Color
    var muted: Color
    var dim: Color
    var accent: Color
    var up: Color
    var down: Color
    var hairline: Color
}

struct CompareGridTable: View {
    let grid: CoachProgression.CompareGrid
    var palette: CompareGridPalette
    var onSelectLift: ((String) -> Void)?

    @State private var rowHeights: [String: CGFloat] = [:]
    @State private var headerHeight: CGFloat = 52

    private let nameWidth: CGFloat = 132
    private let columnWidth: CGFloat = 78

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            nameColumn
            ScrollView(.horizontal, showsIndicators: false) {
                dataColumns
            }
        }
        .onPreferenceChange(CompareRowHeightKey.self) { reported in
            rowHeights.merge(reported, uniquingKeysWith: max)
        }
        .onPreferenceChange(CompareHeaderHeightKey.self) { reported in
            if reported > 0 { headerHeight = max(headerHeight, reported) }
        }
        .onChange(of: grid) { _, _ in
            rowHeights = [:]
        }
        .accessibilityElement(children: .contain)
    }

    private var nameColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear
                .frame(width: nameWidth, height: headerHeight)
                .overlay(alignment: .bottom) { hairline }
            ForEach(Array(grid.rows.enumerated()), id: \.element.id) { index, row in
                nameCell(row.name, striped: index.isMultiple(of: 2))
                    .background(measureRow(row.id))
                    .frame(minHeight: rowHeights[row.id], alignment: .topLeading)
            }
        }
        .overlay(alignment: .trailing) {
            Rectangle().fill(palette.hairline).frame(width: 1)
        }
    }

    private var dataColumns: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(grid.columns) { column in
                    header(column)
                }
            }
            .background {
                GeometryReader { geo in
                    Color.clear.preference(key: CompareHeaderHeightKey.self, value: geo.size.height)
                }
            }
            .frame(height: headerHeight)

            ForEach(Array(grid.rows.enumerated()), id: \.element.id) { index, row in
                HStack(alignment: .top, spacing: 0) {
                    ForEach(Array(row.cells.enumerated()), id: \.offset) { _, cell in
                        setCell(cell, striped: index.isMultiple(of: 2))
                    }
                }
                .background(measureRow(row.id))
                .frame(minHeight: rowHeights[row.id], alignment: .topLeading)
            }
        }
    }

    private func header(_ column: CoachProgression.SessionColumn) -> some View {
        VStack(spacing: 2) {
            Text(column.startedAt.formatted(.dateTime.month(.abbreviated).day()))
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.foreground)
            Text(column.startedAt.formatted(.dateTime.weekday(.abbreviated)))
                .font(.caption2)
                .foregroundStyle(palette.dim)
            if let track = column.rotationTrack, !track.isEmpty {
                Text(track)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(palette.accent)
            }
        }
        .frame(width: columnWidth)
        .padding(.bottom, 8)
        .overlay(alignment: .bottom) { hairline }
    }

    private func nameCell(_ name: String, striped: Bool) -> some View {
        Group {
            if let onSelectLift {
                Button {
                    onSelectLift(name)
                } label: {
                    nameLabel(name)
                }
                .buttonStyle(.plain)
            } else {
                nameLabel(name)
            }
        }
        .frame(width: nameWidth, alignment: .topLeading)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .padding(.trailing, 8)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(striped ? palette.surface.opacity(0.55) : palette.background)
        .overlay(alignment: .bottom) { hairline }
    }

    private func nameLabel(_ name: String) -> some View {
        Text(name)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(palette.foreground)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func setCell(_ cell: CoachProgression.CompareCell, striped: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if cell.workingSets.isEmpty {
                Text("—")
                    .foregroundStyle(palette.dim)
            } else {
                ForEach(Array(cell.workingSets.enumerated()), id: \.offset) { _, set in
                    Text(CoachProgression.setLabel(set))
                        .foregroundStyle(color(for: cell.direction))
                }
            }
        }
        .font(.caption.monospacedDigit().weight(.semibold))
        .frame(width: columnWidth, alignment: .topLeading)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(striped ? palette.surface.opacity(0.55) : palette.background)
        .overlay(alignment: .bottom) { hairline }
        .accessibilityLabel(setAccessibility(cell))
    }

    private var hairline: some View {
        Rectangle().fill(palette.hairline).frame(height: 1)
    }

    private func measureRow(_ id: String) -> some View {
        GeometryReader { geo in
            Color.clear.preference(key: CompareRowHeightKey.self, value: [id: geo.size.height])
        }
    }

    private func color(for direction: CoachProgression.Direction) -> Color {
        switch direction {
        case .up: palette.up
        case .down: palette.down
        case .same, .new: palette.foreground
        }
    }

    private func setAccessibility(_ cell: CoachProgression.CompareCell) -> String {
        if cell.workingSets.isEmpty { return "No sets" }
        return cell.workingSets.map(CoachProgression.setLabel).joined(separator: ", ")
    }
}

private struct CompareRowHeightKey: PreferenceKey {
    static var defaultValue: [String: CGFloat] = [:]
    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: max)
    }
}

private struct CompareHeaderHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
