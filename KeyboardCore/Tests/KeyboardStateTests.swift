import XCTest
import KeymojiCore
@testable import KeyboardCore

final class KeyboardStateTests: XCTestCase {

	// MARK: - effectiveShowsNumberRow

	func testEffectiveShowsNumberRow_portrait_followsPreference_whenEnabled() {
		let state = KeyboardState(showNumberRow: true, isLandscape: false)
		XCTAssertTrue(state.effectiveShowsNumberRow)
	}

	func testEffectiveShowsNumberRow_portrait_followsPreference_whenDisabled() {
		let state = KeyboardState(showNumberRow: false, isLandscape: false)
		XCTAssertFalse(state.effectiveShowsNumberRow)
	}

	func testEffectiveShowsNumberRow_landscape_alwaysHidden_evenWhenPreferenceEnabled() {
		let state = KeyboardState(showNumberRow: true, isLandscape: true)
		XCTAssertFalse(state.effectiveShowsNumberRow)
	}

	func testEffectiveShowsNumberRow_landscape_alwaysHidden_whenPreferenceDisabled() {
		let state = KeyboardState(showNumberRow: false, isLandscape: true)
		XCTAssertFalse(state.effectiveShowsNumberRow)
	}

	func testEffectiveShowsNumberRow_doesNotMutateStoredPreference() {
		// Landscape only *ignores* the preference; it must never overwrite it, so portrait restores
		// the user's choice exactly.
		let state = KeyboardState(showNumberRow: true, isLandscape: true)
		XCTAssertTrue(state.showNumberRow)
		XCTAssertFalse(state.effectiveShowsNumberRow)
	}
}
