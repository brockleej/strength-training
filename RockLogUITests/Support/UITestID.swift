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
    static let workoutPrograms = "workout.programs"
    static let activeWorkoutBar = "workout.activeBar"
    static let screenClose = "screen.close"
    static let programsSchedule = "programs.schedule"
    static let settingsWorkoutDefaults = "settings.workoutDefaults"
    static let settingsGyms = "settings.gyms"
    static let settingsDataBackup = "settings.dataBackup"
    static let settingsAppearance = "settings.appearance"
    static let settingsAbout = "settings.about"
    static let settingsGymAccess = "settings.gymAccess"
    static let gymAccessAdd = "gymAccess.add"
    static func gymAccessRow(_ name: String) -> String { "gymAccess.row.\(name)" }
    static let gymAccessName = "gymAccess.name"
    static let gymAccessSave = "gymAccess.save"
    static let gymAccessBarcode = "gymAccess.barcode"
    static let gymPassClose = "gymPass.close"
    static let gymPassCode = "gymPass.code"
    static let todayCancel = "today.cancelWorkout"

    static func todayDay(_ name: String) -> String { "today.day.\(name)" }

    static let workoutHome = "workout.home"
    static let workoutFinish = "workout.finish"
    static let workoutReorder = "workout.reorder"
    static let workoutEditDayPlan = "workout.editDayPlan"
    static let workoutCircuit = "workout.circuit"
    static let workoutSaveOrderDay = "workout.saveOrderDay"
    static let workoutSaveOrderRemaining = "workout.saveOrderRemaining"
    static let workoutSaveToday = "workout.saveToday"
    static let workoutReorderCancel = "workout.reorderCancel"
    static let circuitCreate = "circuit.create"
    static let circuitRest = "circuit.rest"
    static func circuitPick(_ name: String) -> String { "circuit.pick.\(name)" }
    static func reorderRow(_ name: String) -> String { "reorder.row.\(name)" }
    static func reorderCircuit(_ letter: String) -> String { "reorder.circuit.\(letter)" }
    static func reorderCircuitMenu(_ letter: String) -> String { "reorder.circuit.menu.\(letter)" }

    static func workoutExercise(_ name: String) -> String { "workout.exercise.\(name)" }
    static let workoutSecondaryToggle = "workout.secondaryToggle"
    static let storeRetry = "store.retry"

    static let focusBack = "focus.back"
    static let focusPrevious = "focus.previous"
    static let focusNext = "focus.next"
    static let focusDone = "focus.done"
    static let focusWarmup = "focus.warmup"
    static let focusWarmupRamp = "focus.warmupRamp"
    static let focusComparison = "focus.comparison"
    static let focusPlates = "focus.plates"
    static let focusSetProgress = "focus.setProgress"
    static let focusCircuitRound = "focus.circuit.round"
    static func focusCircuitLift(_ name: String) -> String { "focus.circuit.lift.\(name)" }
    static let focusCircuitBreak = "focus.circuit.break"
    static let focusCircuitUpNext = "focus.circuit.upNext"
    static let focusCircuitEndEarly = "focus.circuit.endEarly"
    static let focusCircuitEndEarlyMenu = "focus.circuit.endEarlyMenu"
    static func workoutCircuitStart(_ letter: String) -> String { "workout.circuitStart.\(letter)" }
    static let focusLoadMode = "focus.loadMode"
    static let focusCarryUndo = "focus.carryUndo"
    static let focusLogSet = "focus.logSet"
    static let focusUpdateSet = "focus.updateSet"
    static let focusCancelEdit = "focus.cancelEdit"

    static func focusSet(_ number: Int) -> String { "focus.set.\(number)" }
    static let focusHitLog = "focus.hitLog"
    static let setDelete = "set.delete"
    static let setUndo = "set.undo"
    static let diagControlArgument = "-RockLogDiag"
    static func diagBody(_ name: String) -> String { "diag.body.\(name)" }
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

    static let settingsUnits = "settings.units"
    static let settingsMassUnit = "settings.massUnit"
    static let settingsStartingWeight = "settings.startingWeight"
    static let settingsTapAtTen = "settings.tapAtTen"
    static let settingsEndAlert = "settings.endAlert"
    static let settingsUnitsFooter = "settings.units.footer"
    static let settingsGym = "settings.gym"
    static let restToggle = "rest.toggle"
    static let restSkip = "rest.skip"
    static let restMinus = "rest.minus"
    static let restPlus = "rest.plus"
    static let stackOverride = "stack.override"
    static let progressRelative = "progress.relative"
    static let settingsEditSplit = "settings.editSplit"
    static let settingsRestore = "settings.restore"
    static let restoreNoticeMessage = "restore.notice.message"
    static let settingsExport = "settings.export"
    static let settingsAddPlanned = "settings.addPlanned"
    static let settingsImportSplit = "settings.importSplit"

    static let splitReorder = "split.reorder"
    static func splitDay(_ name: String) -> String { "split.day.\(name)" }
    static func splitDayMoveUp(_ name: String) -> String { "split.day.\(name).moveUp" }
    static func splitDayMoveDown(_ name: String) -> String { "split.day.\(name).moveDown" }
    static let splitDelete = "split.delete"

    static let historyEmpty = "history.empty"

    static func plannedRow(_ day: String) -> String { "planned.row.\(day)" }
    static func dayPlanExercise(_ name: String) -> String { "dayPlan.exercise.\(name)" }
}
