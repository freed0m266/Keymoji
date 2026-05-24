import XCTest
@testable import KeyboardCore

@MainActor
final class HapticDispatchTests: XCTestCase {

	private var proxy: MockProxy!
	private var controller: MockController!
	private var haptics: MockHaptics!

	override func setUp() {
		super.setUp()
		proxy = MockProxy()
		controller = MockController()
		haptics = MockHaptics()
	}

	func testInsertText_triggersKeyTapHaptic() {
		var state = KeyboardState()
		dispatch(letterKey("a"), &state)
		XCTAssertEqual(haptics.keyTapCount, 1)
	}

	func testInsertRawText_triggersKeyTapHaptic() {
		var state = KeyboardState()
		let key = Key(id: "alt", primary: .text("é"), alternates: [], action: .insertRawText("é"), visualWeight: .standard, role: .character)
		dispatch(key, &state)
		XCTAssertEqual(haptics.keyTapCount, 1)
	}

	func testBackspace_triggersKeyTapHaptic() {
		var state = KeyboardState()
		dispatch(systemKey(.backspace), &state)
		XCTAssertEqual(haptics.keyTapCount, 1)
	}

	func testSpace_triggersKeyTapHaptic() {
		var state = KeyboardState()
		dispatch(systemKey(.space), &state)
		XCTAssertEqual(haptics.keyTapCount, 1)
	}

	func testReturn_triggersKeyTapHaptic() {
		var state = KeyboardState()
		dispatch(systemKey(.return), &state)
		XCTAssertEqual(haptics.keyTapCount, 1)
	}

	func testShift_doesNotTriggerHaptic() {
		var state = KeyboardState()
		dispatch(systemKey(.shift), &state)
		XCTAssertEqual(haptics.keyTapCount, 0)
	}

	func testSwitchPage_doesNotTriggerHaptic() {
		var state = KeyboardState()
		dispatch(systemKey(.switchPage(.symbols(.primary))), &state)
		XCTAssertEqual(haptics.keyTapCount, 0)
	}

	func testNextKeyboard_doesNotTriggerHaptic() {
		var state = KeyboardState()
		dispatch(systemKey(.nextKeyboard), &state)
		XCTAssertEqual(haptics.keyTapCount, 0)
	}

	// MARK: - Helpers

	private func dispatch(_ key: Key, _ state: inout KeyboardState) {
		InputDispatcher.dispatch(
			key: key,
			state: &state,
			proxy: proxy,
			controller: controller,
			haptics: haptics
		)
	}

	private func letterKey(_ char: String) -> Key {
		Key(id: "letter.\(char)", primary: .text(char), alternates: [], action: .insertText(char), visualWeight: .standard, role: .character)
	}

	private func systemKey(_ action: KeyAction) -> Key {
		Key(id: "sys", primary: .text(""), alternates: [], action: action, visualWeight: .standard, role: .system)
	}
}

@MainActor
private final class MockProxy: TextDocumentProxying {
	var documentContextBeforeInput: String?
	var documentContextAfterInput: String?
	var inserted: [String] = []
	var deleteCount = 0
	func insertText(_ text: String) { inserted.append(text) }
	func deleteBackward() { deleteCount += 1 }
}

@MainActor
private final class MockController: KeyboardControlling {
	func advanceToNextInputMode() {}
	func dismissKeyboard() {}
}

@MainActor
private final class MockHaptics: HapticFeedbackProviding {
	var keyTapCount = 0
	var popoverEntryCount = 0
	var popoverHighlightCount = 0
	func keyTap() { keyTapCount += 1 }
	func popoverEntry() { popoverEntryCount += 1 }
	func popoverHighlightChanged() { popoverHighlightCount += 1 }
}
