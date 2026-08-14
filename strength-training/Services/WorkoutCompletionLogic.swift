//
//  WorkoutCompletionLogic.swift
//  strength-training
//
//  When to offer “Finish this workout?” after the last lift is marked done.
//

import Foundation

enum WorkoutCompletionLogic {
    /// Offer finish when every visible lift is marked done and at least one set exists.
    static func shouldOfferFinish(liftCount: Int, doneCount: Int, hasAnySets: Bool) -> Bool {
        hasAnySets && liftCount > 0 && doneCount == liftCount
    }
}
