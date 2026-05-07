import XCTest
@testable import strength_training

@MainActor
final class FocusViewModelTests: XCTestCase {

    // MARK: - Target application + clearing

    func testInit_targetApplied_setsBumpedFlag() {
        let vm = FocusViewModel(
            initialWeight: 235,
            initialReps: 5,
            target: .init(weight: 235, weightDelta: 5, reps: 5, repsDelta: 0)
        )
        XCTAssertEqual(vm.weight, 235)
        XCTAssertEqual(vm.reps, 5)
        XCTAssertTrue(vm.isTargetActive)
        XCTAssertEqual(vm.weightDelta, 5)
        XCTAssertEqual(vm.repsDelta, 0)
    }

    func testInit_noTarget_neutralState() {
        let vm = FocusViewModel(initialWeight: 100, initialReps: 10, target: nil)
        XCTAssertFalse(vm.isTargetActive)
        XCTAssertEqual(vm.weightDelta, 0)
        XCTAssertEqual(vm.repsDelta, 0)
    }

    func testUserEditWeight_clearsTarget() {
        let vm = FocusViewModel(
            initialWeight: 235,
            initialReps: 5,
            target: .init(weight: 235, weightDelta: 5, reps: 5, repsDelta: 0)
        )
        vm.userEditedWeight()
        XCTAssertFalse(vm.isTargetActive, "Editing weight should clear target")
    }

    func testUserEditReps_clearsTarget() {
        let vm = FocusViewModel(
            initialWeight: 235,
            initialReps: 5,
            target: .init(weight: 235, weightDelta: 5, reps: 5, repsDelta: 0)
        )
        vm.userEditedReps()
        XCTAssertFalse(vm.isTargetActive)
    }

    func testUserEdit_neutralStateStaysCleared() {
        let vm = FocusViewModel(initialWeight: 100, initialReps: 10, target: nil)
        vm.userEditedWeight()
        XCTAssertFalse(vm.isTargetActive)
    }

    // MARK: - Rest timer

    func testRestTimer_initiallyZero() {
        let vm = FocusViewModel(initialWeight: 100, initialReps: 10, target: nil)
        XCTAssertEqual(vm.restTimerSeconds, 0)
    }

    func testSetLogged_resetsRestTimer() {
        let vm = FocusViewModel(initialWeight: 100, initialReps: 10, target: nil)
        vm.restTimerSeconds = 47   // simulate 47s elapsed
        vm.setLogged()
        XCTAssertEqual(vm.restTimerSeconds, 0, "Logging a set should reset rest timer")
    }

    func testFormattedRestTimer() {
        XCTAssertEqual(FocusViewModel.formatRest(0), "0:00")
        XCTAssertEqual(FocusViewModel.formatRest(7), "0:07")
        XCTAssertEqual(FocusViewModel.formatRest(120), "2:00")
        XCTAssertEqual(FocusViewModel.formatRest(605), "10:05")
    }
}
