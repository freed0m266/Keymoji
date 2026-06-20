import XCTest
import CoreGraphics
@testable import KeyboardUI

/// Covers the long-press popover downward-cancel threshold (task 69). The gesture itself isn't
/// unit-testable, but the arm decision is extracted into `KeyView.shouldArmPopoverCancel` so the
/// threshold/coordinate math — the part that silently re-breaks — has a regression net.
final class KeyViewPopoverCancelTests: XCTestCase {

	func testSidewaysMotion_doesNotCancel() {
		// Reaching sideways for an accent (e → ě) keeps the downward delta at ~0 → never cancels.
		// This is the exact regression the original absolute-Y threshold caused.
		XCTAssertFalse(KeyView.shouldArmPopoverCancel(draggedDown: 0))
	}

	func testUpwardMotion_doesNotCancel() {
		// Sliding up onto the popover is negative downward delta → never cancels.
		XCTAssertFalse(KeyView.shouldArmPopoverCancel(draggedDown: -80))
	}

	func testSmallDownwardDrift_doesNotCancel() {
		// Drifting down within the key while picking an accent must not cancel.
		XCTAssertFalse(KeyView.shouldArmPopoverCancel(draggedDown: 40))
	}

	func testAtThreshold_doesNotCancel() {
		// Strict greater-than: exactly the threshold is not yet a cancel.
		XCTAssertFalse(KeyView.shouldArmPopoverCancel(draggedDown: 56))
	}

	func testJustPastThreshold_cancels() {
		XCTAssertTrue(KeyView.shouldArmPopoverCancel(draggedDown: 57))
	}

	func testDeliberateDownwardDrag_cancels() {
		XCTAssertTrue(KeyView.shouldArmPopoverCancel(draggedDown: 120))
	}
}
