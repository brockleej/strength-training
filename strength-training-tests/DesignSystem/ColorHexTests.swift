import XCTest
import SwiftUI
@testable import strength_training

final class ColorHexTests: XCTestCase {
    func testHexParsesRGB() {
        let c = Color(hex: 0xFF4D88)
        // Convert via UIColor for component inspection (Color isn't directly inspectable on iOS)
        let ui = UIColor(c)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(r, 1.0,    accuracy: 0.01, "red channel")
        XCTAssertEqual(g, 77/255, accuracy: 0.01, "green channel")
        XCTAssertEqual(b, 136/255, accuracy: 0.01, "blue channel")
        XCTAssertEqual(a, 1.0,    accuracy: 0.01, "alpha defaults to 1.0")
    }

    func testHexWithExplicitAlpha() {
        let c = Color(hex: 0x000000, opacity: 0.5)
        let ui = UIColor(c)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(a, 0.5, accuracy: 0.01)
    }
}
