//
//  UITestID.swift
//  RockLogUITests
//
//  Mirror of RockLog/Utilities/AccessibilityID.swift. UI tests cannot import
//  the app target, so these strings are copied. Keep them in sync.
//

import Foundation

enum UITestID {
    static let appRoot = "rocklog.root"

    static let firstRunContinue = "firstRun.continue"
    static let firstRunSkip = "firstRun.skip"
    static let firstRunRestore = "firstRun.restore"
    static let firstRunStarters = "firstRun.starters"
    static let firstRunLeaveEmpty = "firstRun.leaveEmpty"

    static func firstRunChoice(_ title: String) -> String { "firstRun.choice.\(title)" }

    static let todayStart = "today.start"
    static let todayEditDay = "today.editDay"
    static let todayGymPass = "today.gymPass"
    static let todayCancel = "today.cancelWorkout"

    static func todayDay(_ name: String) -> String { "today.day.\(name)" }

    static let workoutHome = "workout.home"
    static let workoutFinish = "workout.finish"
    static let workoutReorder = "workout.reorder"
    static let workoutEditDayPlan = "workout.editDayPlan"
    static let workoutCircuit = "workout.circuit"
    static let workoutSaveOrderDay = "workout.saveOrderDay"
    static let workoutSaveOrderRemaining = "workout.saveOrderRemaining"

    static func workoutExercise(_ name: String) -> String { "workout.exercise.\(name)" }

    static let focusBack = "focus.back"
    static let focusPrevious = "focus.previous"
    static let focusNext = "focus.next"
    static let focusDone = "focus.done"
    static let focusWarmup = "focus.warmup"
    static let focusWarmupRamp = "focus.warmupRamp"
    static let focusComparison = "focus.comparison"
    static let focusPlates = "focus.plates"
    static let focusLoadMode = "focus.loadMode"
    static let focusCarryUndo = "focus.carryUndo"
    static let focusLogSet = "focus.logSet"
    static let focusUpdateSet = "focus.updateSet"
    static let focusCancelEdit = "focus.cancelEdit"

    static func focusSet(_ number: Int) -> String { "focus.set.\(number)" }
    /// TEMP: remove before merge. Delivery counts only, no workout data.
    static let focusEditDeliveryTEMP = "focus.editDelivery.TEMP"
    /// TEMP: remove before merge. Control outside swipeToDelete.
    static let focusEditDeliveryProbeTEMP = "focus.editDelivery.probe.TEMP"
    static func focusLoadLast(_ number: Int) -> String { "focus.loadLast.\(number)" }
    static func focusLoadPlan(_ number: Int) -> String { "focus.loadPlan.\(number)" }
    static func stepperIncrease(_ label: String) -> String { "stepper.increase.\(label)" }
    static func stepperDecrease(_ label: String) -> String { "stepper.decrease.\(label)" }

    static func effortRating(_ value: Int) -> String { "effort.rating.\(value)" }
    static let effortSave = "effort.save"
    static let effortSkip = "effort.skip"
    static let effortDismiss = "effort.dismiss"

    static let summaryDone = "summary.done"
    static let summaryDetails = "summary.details"
    static let summaryDuration = "summary.duration"

    static let settingsMassUnit = "settings.massUnit"
    static let settingsStartingWeight = "settings.startingWeight"
    static let settingsTapAtTen = "settings.tapAtTen"
    static let settingsGym = "settings.gym"
    static let restToggle = "rest.toggle"
    static let restSkip = "rest.skip"
    static let restMinus = "rest.minus"
    static let restPlus = "rest.plus"
    static let stackOverride = "stack.override"
    static let progressRelative = "progress.relative"
    static let settingsEditSplit = "settings.editSplit"
    static let settingsRestore = "settings.restore"
    static let settingsExport = "settings.export"
    static let settingsAddPlanned = "settings.addPlanned"
    static let settingsImportSplit = "settings.importSplit"

    static let splitReorder = "split.reorder"
    static func splitDay(_ name: String) -> String { "split.day.\(name)" }
    static func splitDayMoveUp(_ name: String) -> String { "split.day.\(name).moveUp" }
    static func splitDayMoveDown(_ name: String) -> String { "split.day.\(name).moveDown" }
    static let swipeTrash = "swipe.trash"

    static let historyEmpty = "history.empty"

    static func plannedRow(_ day: String) -> String { "planned.row.\(day)" }
    static func dayPlanExercise(_ name: String) -> String { "dayPlan.exercise.\(name)" }
}
