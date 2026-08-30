//
//  SwipeToDeleteLogicTests.swift
//  strength-training-tests
//
//  Hit-zone contract for reveal-then-tap. Build 24 showed the trash but the
//  tap did nothing: a full-row close overlay sat on top of the trailing strip.
//

import XCTest
@testable import strength_training

final class SwipeToDeleteLogicTests: XCTestCase {

    private let rowWidth: CGFloat = 360
    private var reveal: CGFloat { SwipeToDeleteLogic.revealWidth }

    func test_revealedTrailingStrip_isTrashNotClose() {
        let trashX = rowWidth - reveal + 8
        XCTAssertEqual(
            SwipeToDeleteLogic.hitZone(x: trashX, rowWidth: rowWidth, isRevealed: true),
            .trash
        )
        XCTAssertEqual(
            SwipeToDeleteLogic.hitZone(x: rowWidth - 1, rowWidth: rowWidth, isRevealed: true),
            .trash
        )
    }

    func test_revealedLeadingArea_isRowSoTapCanDismiss() {
        XCTAssertEqual(
            SwipeToDeleteLogic.hitZone(x: 80, rowWidth: rowWidth, isRevealed: true),
            .row
        )
        XCTAssertEqual(
            SwipeToDeleteLogic.hitZone(x: rowWidth - reveal - 1, rowWidth: rowWidth, isRevealed: true),
            .row
        )
    }

    func test_closedRow_hasNoTrashZone() {
        XCTAssertEqual(
            SwipeToDeleteLogic.hitZone(x: rowWidth - 8, rowWidth: rowWidth, isRevealed: false),
            .row
        )
    }

    /// The build-24 overlay used padding then contentShape. That shape is the
    /// full row width, so a trash-x tap lands in the close control.
    func test_oldPaddedContentShape_coversTrash() {
        let overlayMinX: CGFloat = 0
        let overlayMaxX = rowWidth
        let trashX = rowWidth - reveal + 8
        XCTAssertTrue(
            trashX >= overlayMinX && trashX < overlayMaxX,
            "Regression reminder: do not put a full-row close overlay over the trash."
        )
        XCTAssertEqual(
            SwipeToDeleteLogic.hitZone(x: trashX, rowWidth: rowWidth, isRevealed: true),
            .trash
        )
    }

    func test_endAction_revealsPastHalfway() {
        XCTAssertEqual(
            SwipeToDeleteLogic.endAction(projectedOffset: -reveal / 2 - 1, fullSwipeDeletes: false),
            .reveal
        )
        XCTAssertEqual(
            SwipeToDeleteLogic.endAction(projectedOffset: -reveal / 2 + 1, fullSwipeDeletes: false),
            .close
        )
    }

    func test_endAction_fullSwipeDeletesOnlyWhenEnabled() {
        let strong = -reveal * 1.25 - 1
        XCTAssertEqual(
            SwipeToDeleteLogic.endAction(projectedOffset: strong, fullSwipeDeletes: true),
            .delete
        )
        XCTAssertEqual(
            SwipeToDeleteLogic.endAction(projectedOffset: strong, fullSwipeDeletes: false),
            .reveal
        )
    }
}
