//
//  RestActivityAttributes.swift
//  Compiled into the app and the widget extension. Same source, both targets.
//

import Foundation

#if canImport(ActivityKit)
import ActivityKit

nonisolated struct RestActivityAttributes: ActivityAttributes {
    nonisolated struct ContentState: Codable, Hashable {
        var rangeStart: Date
        var endDate: Date

        var interval: ClosedRange<Date> {
            let start = min(rangeStart, endDate)
            return start...endDate
        }
    }

    var exerciseName: String
}
#endif
