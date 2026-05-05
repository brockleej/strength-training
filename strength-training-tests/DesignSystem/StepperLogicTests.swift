import XCTest
@testable import strength_training

final class StepperLogicTests: XCTestCase {

    // ─── Increment ─────────────────────────────────────────────
    func testIncrementByStep() {
        let logic = StepperLogic(value: 100, step: 5, min: 0, max: 1000)
        XCTAssertEqual(logic.incremented(), 105)
    }

    func testIncrementClampedToMax() {
        let logic = StepperLogic(value: 998, step: 5, min: 0, max: 1000)
        XCTAssertEqual(logic.incremented(), 1000, "increment should clamp at max")
    }

    func testIncrementAtMaxStays() {
        let logic = StepperLogic(value: 1000, step: 5, min: 0, max: 1000)
        XCTAssertEqual(logic.incremented(), 1000)
    }

    // ─── Decrement ─────────────────────────────────────────────
    func testDecrementByStep() {
        let logic = StepperLogic(value: 100, step: 5, min: 0, max: 1000)
        XCTAssertEqual(logic.decremented(), 95)
    }

    func testDecrementClampedToMin() {
        let logic = StepperLogic(value: 2, step: 5, min: 0, max: 1000)
        XCTAssertEqual(logic.decremented(), 0, "decrement should clamp at min")
    }

    func testDecrementAtMinStays() {
        let logic = StepperLogic(value: 0, step: 5, min: 0, max: 1000)
        XCTAssertEqual(logic.decremented(), 0)
    }

    // ─── Half-pound steps for weight ───────────────────────────
    func testFractionalStep() {
        let logic = StepperLogic(value: 47.5, step: 2.5, min: 0, max: 1000)
        XCTAssertEqual(logic.incremented(), 50.0, accuracy: 0.001)
        XCTAssertEqual(logic.decremented(), 45.0, accuracy: 0.001)
    }
}
