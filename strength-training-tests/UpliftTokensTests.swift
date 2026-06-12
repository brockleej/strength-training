//
//  UpliftTokensTests.swift
//  strength-training-tests
//

import XCTest
import SwiftUI
@testable import strength_training

final class UpliftTokensTests: XCTestCase {

    private func components(of color: Color) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b, a)
    }

    func test_hexInit_parsesRGBChannels() {
        let c = components(of: Color(hex: 0x5AB8F5))   // accent ice
        XCTAssertEqual(c.r, 90 / 255, accuracy: 0.001)
        XCTAssertEqual(c.g, 184 / 255, accuracy: 0.001)
        XCTAssertEqual(c.b, 245 / 255, accuracy: 0.001)
        XCTAssertEqual(c.a, 1.0, accuracy: 0.001)
    }

    func test_hexInit_appliesOpacity() {
        let c = components(of: Color(hex: 0xEBEBF5, opacity: 0.62))   // fgMuted
        XCTAssertEqual(c.a, 0.62, accuracy: 0.001)
    }

    func test_dayTypeInkMapping() {
        let arms = components(of: DayType.arms.upliftInk)
        XCTAssertEqual(arms.r, 255 / 255, accuracy: 0.001)
        XCTAssertEqual(arms.g, 77 / 255, accuracy: 0.001)
        XCTAssertEqual(arms.b, 136 / 255, accuracy: 0.001)
    }

    func test_dayTypeWashMapping_usesInkHueAtWashOpacity() {
        let arms = components(of: DayType.arms.upliftWash)
        XCTAssertEqual(arms.r, 255 / 255, accuracy: 0.001)
        XCTAssertEqual(arms.g, 77 / 255, accuracy: 0.001)
        XCTAssertEqual(arms.b, 136 / 255, accuracy: 0.001)
        XCTAssertEqual(arms.a, 0.14, accuracy: 0.001)
    }
}
