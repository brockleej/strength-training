//
//  AccessibilityID.swift
//  RockLog
//
//  Stable identifiers for VoiceOver and XCUITest. UI tests mirror these
//  strings in RockLogUITests/Support/UITestID.swift — keep the two in sync.
//

import Foundation

enum AccessibilityID {
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
    static let programsInstructions = "programs.instructions"
    static let programsClearPlanned = "programs.clearPlanned"
    static func programsDay(_ name: String) -> String { "programs.day.\(name)" }
    static let settingsGymAccess = "settings.gymAccess"
    static let gymAccessAdd = "gymAccess.add"
    static let gymAccessName = "gymAccess.name"
    static let gymAccessSave = "gymAccess.save"
    static let gymAccessDefault = "gymAccess.default"
    static let gymAccessUseLocation = "gymAccess.useLocation"
    static let gymAccessPickMap = "gymAccess.pickMap"
    static let gymAccessClearLocation = "gymAccess.clearLocation"
    static let gymAccessMethod = "gymAccess.method"
    static let gymAccessBarcode = "gymAccess.barcode"
    static let gymAccessScan = "gymAccess.scan"
    static let gymAccessSymbology = "gymAccess.symbology"
    static let gymAccessAppURL = "gymAccess.appURL"
    static let gymAccessAppStore = "gymAccess.appStore"
    static let gymAccessKisi = "gymAccess.kisi"
    static let gymAccessLink = "gymAccess.link"
    static let gymPassClose = "gymPass.close"
    static let gymPassCode = "gymPass.code"
    static func gymAccessRow(_ name: String) -> String { "gymAccess.row.\(name)" }
    static func gymAccessSwitch(_ name: String) -> String { "gymAccess.switch.\(name)" }
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
    static let focusLoadMode = "focus.loadMode"
    static let focusCarryUndo = "focus.carryUndo"
    static let focusLogSet = "focus.logSet"
    static let focusUpdateSet = "focus.updateSet"
    static let focusCancelEdit = "focus.cancelEdit"

    static func focusSet(_ number: Int) -> String { "focus.set.\(number)" }
    /// Button, pan begin, and pan cancel counts. UI tests pass `-RockLogDiag`.
    static let focusHitLog = "focus.hitLog"
    static func diagBody(_ name: String) -> String { "diag.body.\(name)" }
    static let setDelete = "set.delete"
    static let setUndo = "set.undo"
    /// Last-time column. Kept off `focus.set` so a tap on the set does not load it.
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

    static let settingsWorkoutDefaults = "settings.workoutDefaults"
    static let settingsGyms = "settings.gyms"
    static let settingsDataBackup = "settings.dataBackup"
    static let settingsAppearance = "settings.appearance"
    static let settingsAppearanceChoice = "settings.appearanceChoice"
    static let settingsAbout = "settings.about"
    static let settingsWelcome = "settings.welcome"
    static let settingsNewGym = "settings.newGym"
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
