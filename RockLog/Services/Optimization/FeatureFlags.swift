//
//  FeatureFlags.swift
//  RockLog
//
//  Switches for work that is not ready to ship. Each one stays off until
//  that piece is finished. Turning one on is a source change, not a setting.
//

import Foundation

enum FeatureFlags {
    /// The rest Live Activity needs its own widget extension and provisioning
    /// profile. Off means the app does not embed `RockLogWidget.appex` and
    /// does not start an activity, so that signature cannot block an upload.
    static var liveActivity: Bool { false }

    /// Typing a machine's pin list is not finished. Step choices still work.
    static var pinListEditor: Bool { false }

    /// Asking to change a lift's rest from past rests is not finished.
    /// The settings switch stays hidden, and samples are not recorded.
    static var restLearningPrompts: Bool { false }
}
