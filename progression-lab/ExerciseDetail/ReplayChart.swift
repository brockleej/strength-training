//
//  ReplayChart.swift
//  ProgressionLab
//

import SwiftUI
import Charts

struct ReplayChart: View {
    let replay: ExerciseModeReplay
    let configAName: String
    let configBName: String

    var body: some View {
        Chart {
            ForEach(replay.sessions) { session in
                PointMark(
                    x: .value("Date", session.sessionDate),
                    y: .value("Weight", session.actualBestSet.weightLbs)
                )
                .foregroundStyle(by: .value("Series", "Actual"))
                .symbolSize(by: .value("Reps", session.actualBestSet.reps))
            }

            ForEach(replay.sessions) { session in
                if let s = session.suggestionA, s.basis != .notEnoughData {
                    LineMark(
                        x: .value("Date", session.sessionDate),
                        y: .value("Weight", s.targetWeight),
                        series: .value("Series", "A: \(configAName)")
                    )
                    .foregroundStyle(by: .value("Series", "A: \(configAName)"))
                    PointMark(
                        x: .value("Date", session.sessionDate),
                        y: .value("Weight", s.targetWeight)
                    )
                    .foregroundStyle(by: .value("Series", "A: \(configAName)"))
                    .symbolSize(40)
                }
            }

            ForEach(replay.sessions) { session in
                if let s = session.suggestionB, s.basis != .notEnoughData {
                    LineMark(
                        x: .value("Date", session.sessionDate),
                        y: .value("Weight", s.targetWeight),
                        series: .value("Series", "B: \(configBName)")
                    )
                    .foregroundStyle(by: .value("Series", "B: \(configBName)"))
                    PointMark(
                        x: .value("Date", session.sessionDate),
                        y: .value("Weight", s.targetWeight)
                    )
                    .foregroundStyle(by: .value("Series", "B: \(configBName)"))
                    .symbolSize(40)
                }
            }
        }
        .chartForegroundStyleScale([
            "Actual": Color.gray,
            "A: \(configAName)": Color.blue,
            "B: \(configBName)": Color.orange,
        ])
        .chartLegend(position: .top, alignment: .leading)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
        .chartYAxisLabel("Weight (lbs)", position: .leading)
        .frame(minHeight: 320)
    }
}
