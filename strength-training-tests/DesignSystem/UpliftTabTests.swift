import XCTest
@testable import strength_training

final class UpliftTabTests: XCTestCase {
    func testEveryTabHasLabelAndIcon() {
        for tab in UpliftTab.allCases {
            XCTAssertFalse(tab.label.isEmpty, "tab \(tab) has empty label")
            XCTAssertFalse(tab.icon.isEmpty, "tab \(tab) has empty icon name")
        }
    }

    func testTabCount() {
        // If a tab is added or removed, this catches it — design currently locks 5 tabs.
        XCTAssertEqual(UpliftTab.allCases.count, 5)
    }
}
