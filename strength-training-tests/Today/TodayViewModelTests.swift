import XCTest
@testable import strength_training

final class TodayViewModelTests: XCTestCase {

    // MARK: - Label rule (yesterday section eyebrow)

    private func cal() -> Calendar { Calendar(identifier: .gregorian) }

    private func date(daysAgo: Int, from reference: Date = .now) -> Date {
        cal().date(byAdding: .day, value: -daysAgo, to: cal().startOfDay(for: reference))!
    }

    func testLabel_today() {
        XCTAssertEqual(TodayViewModel.relativeDayLabel(for: date(daysAgo: 0), now: .now), "TODAY")
    }

    func testLabel_yesterday() {
        XCTAssertEqual(TodayViewModel.relativeDayLabel(for: date(daysAgo: 1), now: .now), "YESTERDAY")
    }

    func testLabel_threeDaysAgo_returnsWeekdayName() {
        let now = cal().date(from: DateComponents(year: 2026, month: 5, day: 7))!  // Thursday
        let threeDaysAgo = cal().date(byAdding: .day, value: -3, to: now)!         // Monday
        XCTAssertEqual(TodayViewModel.relativeDayLabel(for: threeDaysAgo, now: now), "MONDAY")
    }

    func testLabel_sixDaysAgo_returnsWeekdayName() {
        let now = cal().date(from: DateComponents(year: 2026, month: 5, day: 7))!  // Thursday
        let sixDaysAgo = cal().date(byAdding: .day, value: -6, to: now)!           // Friday (prior week)
        XCTAssertEqual(TodayViewModel.relativeDayLabel(for: sixDaysAgo, now: now), "FRIDAY")
    }

    func testLabel_sevenDaysAgo_returnsNDaysAgo() {
        XCTAssertEqual(TodayViewModel.relativeDayLabel(for: date(daysAgo: 7), now: .now), "7 DAYS AGO")
    }

    func testLabel_twelveDaysAgo() {
        XCTAssertEqual(TodayViewModel.relativeDayLabel(for: date(daysAgo: 12), now: .now), "12 DAYS AGO")
    }
}
