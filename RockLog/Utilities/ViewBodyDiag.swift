//
//  ViewBodyDiag.swift
//  RockLog
//
//  Counts view bodies while -RockLogDiag is set. The count is an accessibility
//  label so a UI test can see that a screen stopped redrawing.
//

import SwiftUI

enum ViewBodyDiag {
    private static var counts: [String: Int] = [:]

    static func bump(_ name: String) -> Int {
        guard UITestLaunch.diagControlEnabled else { return 0 }
        let next = (counts[name] ?? 0) + 1
        counts[name] = next
        print("[RLDIAG] body \(name) #\(next)")
        return next
    }
}

extension View {
    /// Prints SwiftUI's change list and exposes the body count. No-op unless
    /// the UI test launched with `-RockLogDiag`.
    func diagBody(_ name: String) -> some View {
        modifier(DiagBodyModifier(name: name))
    }
}

private struct DiagBodyModifier: ViewModifier {
    let name: String

    func body(content: Content) -> some View {
        let count = ViewBodyDiag.bump(name)
        content.background {
            if UITestLaunch.diagControlEnabled {
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityElement()
                    .accessibilityIdentifier(AccessibilityID.diagBody(name))
                    .accessibilityLabel("\(count)")
            }
        }
    }
}
