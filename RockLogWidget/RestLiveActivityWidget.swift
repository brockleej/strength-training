//
//  RestLiveActivityWidget.swift
//  RockLogWidget
//
//  Lock-screen countdown. It shows the end time, so it does not tick a banner
//  once a second. The app updates it only when that end time changes.
//

import ActivityKit
import SwiftUI
import WidgetKit

struct RestActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var rangeStart: Date
        var endDate: Date

        var interval: ClosedRange<Date> {
            let start = min(rangeStart, endDate)
            return start...endDate
        }
    }

    var exerciseName: String
}

struct RestLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 4) {
                Text(context.attributes.exerciseName)
                    .font(.headline)
                Text(timerInterval: context.state.interval, countsDown: true)
                    .font(.title.monospacedDigit())
                    .multilineTextAlignment(.leading)
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    Text(timerInterval: context.state.interval, countsDown: true)
                        .font(.title2.monospacedDigit())
                }
            } compactLeading: {
                Text("Rest")
            } compactTrailing: {
                Text(timerInterval: context.state.interval, countsDown: true)
                    .monospacedDigit()
                    .frame(maxWidth: 48)
            } minimal: {
                Text("R")
            }
        }
    }
}

@main
struct RockLogWidgetBundle: WidgetBundle {
    var body: some Widget {
        RestLiveActivityWidget()
    }
}
