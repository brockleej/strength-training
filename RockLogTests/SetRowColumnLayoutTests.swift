//
//  SetRowColumnLayoutTests.swift
//  RockLogTests
//

import XCTest
@testable import RockLog

final class SetRowColumnLayoutTests: XCTestCase {

    func test_setCenterMissesLastTime_at320and375() {
        for width: CGFloat in [320, 375] {
            for showsPlan in [false, true] {
                let set = SetRowColumnLayout.setColumn(rowWidth: width, showsPlan: showsPlan)
                let last = CGRect(
                    x: SetRowColumnLayout.indexWidth(showsPlan: showsPlan) + SetRowColumnLayout.spacing,
                    y: 0,
                    width: SetRowColumnLayout.lastWidth(showsPlan: showsPlan),
                    height: 44
                )
                XCTAssertGreaterThanOrEqual(set.height, 44, "width \(width)")
                XCTAssertGreaterThanOrEqual(set.width, 44, "width \(width) plan \(showsPlan)")
                XCTAssertFalse(
                    SetRowColumnLayout.centerHits(last, setColumn: set),
                    "set center hits last time at \(width) plan \(showsPlan)"
                )
            }
        }
    }
}
