//
//  E1RM.swift
//  strength-training
//
//  Shared Epley estimated-1RM formula. The single source of truth — Today's
//  PR count, SessionDetailView's badges, and the PR celebration all use this.
//

import Foundation

enum E1RM {
    /// Epley: weight × (1 + reps/30).
    static func estimate(weightLbs: Double, reps: Int) -> Double {
        weightLbs * (1 + Double(reps) / 30)
    }
}
