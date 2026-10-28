//
//  TouchLog.swift
//  RockLog
//
//  TEMP: remove before merge. UI-test hit testing only. Class names and
//  accessibility identifiers. No labels, weights, names, or points.
//

import ObjectiveC
import SwiftUI
import UIKit

#if DEBUG
enum TouchLogInstaller {
    private static var installed = false

    static func installIfNeeded() {
        guard UITestLaunch.touchLogEnabled, !installed else { return }
        installed = true
        guard let original = class_getInstanceMethod(UIWindow.self, #selector(UIWindow.sendEvent(_:))),
              let hooked = class_getInstanceMethod(UIWindow.self, #selector(UIWindow.rocklog_sendEvent(_:)))
        else { return }
        method_exchangeImplementations(original, hooked)
    }
}

extension UIWindow {
    @objc func rocklog_sendEvent(_ event: UIEvent) {
        if event.type == .touches {
            for touch in event.allTouches ?? [] where touch.phase == .began {
                let point = touch.location(in: self)
                let hit = hitTest(point, with: event)
                MainActor.assumeIsolated {
                    TouchLog.shared.recordHit(hit)
                }
            }
        }
        rocklog_sendEvent(event)
    }
}

@MainActor
@Observable
final class TouchLog {
    static let shared = TouchLog()

    private(set) var hits: [String] = []
    private(set) var surfaces: [String] = []
    private(set) var cardTap: String = "none"
    private(set) var setFrame: String = "none"

    func recordHit(_ view: UIView?) {
        var chain: [String] = []
        var current = view
        var depth = 0
        while let node = current, depth < 6 {
            let identifier = node.accessibilityIdentifier ?? "-"
            let concrete = NSStringFromClass(object_getClass(node) ?? UIView.self)
            chain.append("type=\(concrete) id=\(identifier)")
            current = node.superview
            depth += 1
        }
        let line = chain.isEmpty ? "nil" : chain.joined(separator: " > ")
        hits.append(line)
        if hits.count > 8 {
            hits.removeFirst(hits.count - 8)
        }
    }

    func recordSurface(name: String, shown: Bool, blocksHits: Bool) {
        let when = String(format: "%.3f", Date().timeIntervalSince1970)
        let verb = shown ? "show" : "hide"
        let hits = blocksHits ? "blocks" : "allows"
        surfaces.append("\(verb):\(name)@\(when) hitTesting=\(hits)")
        if surfaces.count > 12 {
            surfaces.removeFirst(surfaces.count - 12)
        }
    }

    func recordCardTap(location: CGPoint, setFrame: CGRect) {
        cardTap = String(format: "%.1f,%.1f", location.x, location.y)
        self.setFrame = String(
            format: "%.1f,%.1f,%.1f,%.1f",
            setFrame.origin.x, setFrame.origin.y, setFrame.width, setFrame.height
        )
    }

    var summary: String {
        let last = hits.last ?? "none"
        let surface = surfaces.suffix(6).joined(separator: ",")
        return "TEMP touches=\(hits.count) last=\(last) cardTap=\(cardTap) geom=\(setFrame) surfaces=\(surface)"
    }
}

struct TouchLogReadout: View {
    var body: some View {
        let log = TouchLog.shared
        Color.clear
            .frame(width: 1, height: 1)
            .allowsHitTesting(false)
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier(AccessibilityID.focusTouchLogTEMP)
            .accessibilityLabel("touch log")
            .accessibilityValue(log.summary)
    }
}

extension View {
    func uiTestSurface(_ name: String, isShown: Bool, blocksHits: Bool) -> some View {
        onChange(of: isShown) { _, shown in
            guard UITestLaunch.touchLogEnabled else { return }
            TouchLog.shared.recordSurface(name: name, shown: shown, blocksHits: blocksHits)
        }
    }
}
#endif
