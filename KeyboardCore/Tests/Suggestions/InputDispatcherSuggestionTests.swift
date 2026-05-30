import XCTest
@testable import KeyboardCore

@MainActor
final class InputDispatcherSuggestionTests: XCTestCase {

	private var proxy: SuggestionMockProxy!
	private var controller: SuggestionMockController!
	private var recorder: LearnRecorder!

	override func setUp() {
		super.setUp()
		proxy = SuggestionMockProxy()
		controller = SuggestionMockController()
		recorder = LearnRecorder()
	}

	private func dispatch(_ key: Key, _ state: inout KeyboardState, learning: LearningHook? = nil, now: @escaping () -> Date = Date.init) {
		InputDispatcher.dispatch(key: key, state: &state, proxy: proxy, controller: controller, learning: learning, now: now)
	}

	private func spaceKey() -> Key {
		Key(id: "space", primary: .text(""), alternates: [], action: .space, visualWeight: .space, role: .system)
	}

	private func acceptKey(_ display: String, _ replacement: String? = nil) -> Key {
		Key(
			id: "suggestion.\(display)",
			primary: .text(display),
			alternates: [],
			action: .suggestionAccept(displayText: display, replacementText: replacement ?? display),
			visualWeight: .standard,
			role: .system
		)
	}

	private func letterKey(_ char: String) -> Key {
		Key(id: "letter.\(char)", primary: .text(char), alternates: [], action: .insertText(char), visualWeight: .standard, role: .character)
	}

	private func boundaryKey(_ text: String) -> Key {
		Key(id: "punct.\(text)", primary: .text(text), alternates: [], action: .insertText(text), visualWeight: .standard, role: .character)
	}

	private func proseState() -> KeyboardState {
		KeyboardState(
			page: .letters(.lower),
			currentEligibility: SuggestionEligibility(allowDisplay: true, learningContext: .prose)
		)
	}

	// MARK: - .suggestionAccept

	func testSuggestionAccept_replacesPrefix_andAppendsSpace() {
		var state = proseState()
		proxy.documentContextBeforeInput = "hel"
		dispatch(acceptKey("hello"), &state)
		XCTAssertEqual(proxy.deleteCount, 3, "the in-progress prefix is deleted")
		XCTAssertEqual(proxy.inserted, ["hello "])
		XCTAssertEqual(proxy.documentContextBeforeInput, "hello ")
	}

	func testSuggestionAccept_preservesPrecedingText() {
		var state = proseState()
		proxy.documentContextBeforeInput = "I said hel"
		dispatch(acceptKey("hello"), &state)
		XCTAssertEqual(proxy.documentContextBeforeInput, "I said hello ")
	}

	func testSuggestionAccept_noPrefix_justInserts() {
		var state = proseState()
		proxy.documentContextBeforeInput = nil
		dispatch(acceptKey("hello"), &state)
		XCTAssertEqual(proxy.deleteCount, 0)
		XCTAssertEqual(proxy.inserted, ["hello "])
	}

	func testSuggestionAccept_downshiftsOneShotUpper() {
		var state = KeyboardState(
			page: .letters(.upper),
			currentEligibility: SuggestionEligibility(allowDisplay: true, learningContext: .prose)
		)
		proxy.documentContextBeforeInput = "Hel"
		dispatch(acceptKey("Hello"), &state)
		XCTAssertEqual(state.page, .letters(.lower), "accepting a word counts as character insertion (SH3)")
	}

	func testSuggestionAccept_capsLockStays() {
		var state = KeyboardState(page: .letters(.capsLock))
		proxy.documentContextBeforeInput = "HEL"
		dispatch(acceptKey("HELLO"), &state)
		XCTAssertEqual(state.page, .letters(.capsLock))
	}

	func testSuggestionAccept_marksTrailingSpaceForDoubleTap() {
		var state = proseState()
		proxy.documentContextBeforeInput = "hel"
		dispatch(acceptKey("hello"), &state)
		XCTAssertTrue(state.lastInsertWasSpace)
		XCTAssertNotNil(state.lastSpaceInsertedAt)
	}

	// MARK: - Learning hook

	func testLearning_onSpace_inProse_learnsLastWord() {
		var state = proseState()
		let hook = LearningHook { [recorder] word, context in recorder?.record(word, context) }
		for char in "hello" { dispatch(letterKey(String(char)), &state, learning: hook) }
		dispatch(Key(id: "space", primary: .text(""), alternates: [], action: .space, visualWeight: .space, role: .system), &state, learning: hook)
		XCTAssertEqual(recorder.calls.count, 1)
		XCTAssertEqual(recorder.calls.first?.word, "hello")
		XCTAssertEqual(recorder.calls.first?.context, .prose)
	}

	func testLearning_onPunctuation_learnsLastWord() {
		var state = proseState()
		let hook = LearningHook { [recorder] word, context in recorder?.record(word, context) }
		for char in "hey" { dispatch(letterKey(String(char)), &state, learning: hook) }
		dispatch(boundaryKey("."), &state, learning: hook)
		XCTAssertEqual(recorder.calls.map(\.word), ["hey"])
	}

	func testLearning_letters_doNotTriggerLearning() {
		var state = proseState()
		let hook = LearningHook { [recorder] word, context in recorder?.record(word, context) }
		for char in "hey" { dispatch(letterKey(String(char)), &state, learning: hook) }
		XCTAssertTrue(recorder.calls.isEmpty, "only boundary characters commit a word")
	}

	func testLearning_deniedContext_neverLearns() {
		var state = KeyboardState(page: .letters(.lower), currentEligibility: .denied)
		let hook = LearningHook { [recorder] word, context in recorder?.record(word, context) }
		for char in "secret" { dispatch(letterKey(String(char)), &state, learning: hook) }
		dispatch(Key(id: "space", primary: .text(""), alternates: [], action: .space, visualWeight: .space, role: .system), &state, learning: hook)
		XCTAssertTrue(recorder.calls.isEmpty)
	}

	func testLearning_emailContext_skipsInlineLearning() {
		// Email fields learn the whole field elsewhere (the controller), never word-by-word.
		var state = KeyboardState(
			page: .letters(.lower),
			currentEligibility: SuggestionEligibility(allowDisplay: true, learningContext: .emailAddress)
		)
		let hook = LearningHook { [recorder] word, context in recorder?.record(word, context) }
		for char in "foo" { dispatch(letterKey(String(char)), &state, learning: hook) }
		dispatch(Key(id: "space", primary: .text(""), alternates: [], action: .space, visualWeight: .space, role: .system), &state, learning: hook)
		XCTAssertTrue(recorder.calls.isEmpty)
	}

	func testLearning_doubleSpacePeriod_doesNotDoubleCount() {
		// Default double-tap action is `.insertPeriod`: the first space learns "hello", the second
		// rewrites the space to ". " — which must NOT re-learn the same word.
		var state = proseState()
		let hook = LearningHook { [recorder] word, context in recorder?.record(word, context) }
		let t0 = Date(timeIntervalSince1970: 1_000)
		for char in "hello" { dispatch(letterKey(String(char)), &state, learning: hook) }
		dispatch(spaceKey(), &state, learning: hook, now: { t0 })
		dispatch(spaceKey(), &state, learning: hook, now: { t0.addingTimeInterval(0.3) })
		XCTAssertEqual(proxy.documentContextBeforeInput, "hello. ")
		XCTAssertEqual(recorder.calls.map(\.word), ["hello"], "the sentence-final word is learned exactly once")
	}

	func testLearning_nilHook_isNoOp() {
		var state = proseState()
		for char in "hello" { dispatch(letterKey(String(char)), &state) }
		dispatch(Key(id: "space", primary: .text(""), alternates: [], action: .space, visualWeight: .space, role: .system), &state)
		// No learning hook supplied → nothing recorded, no crash.
		XCTAssertTrue(recorder.calls.isEmpty)
	}
}

// MARK: - Mocks

@MainActor
private final class SuggestionMockProxy: TextDocumentProxying {
	var documentContextAfterInput: String?
	var inserted: [String] = []
	var deleteCount = 0
	var cursorOffsets: [Int] = []
	private var buffer = ""

	var documentContextBeforeInput: String? {
		get { buffer.isEmpty ? nil : buffer }
		set { buffer = newValue ?? "" }
	}

	func insertText(_ text: String) {
		inserted.append(text)
		buffer.append(text)
	}

	func deleteBackward() {
		deleteCount += 1
		if !buffer.isEmpty { buffer.removeLast() }
	}

	func adjustTextPosition(byCharacterOffset offset: Int) {
		cursorOffsets.append(offset)
	}
}

@MainActor
private final class SuggestionMockController: KeyboardControlling {
	var dismissCount = 0
	func dismissKeyboard() { dismissCount += 1 }
}

@MainActor
private final class LearnRecorder {
	var calls: [(word: String, context: TextContextType)] = []
	func record(_ word: String, _ context: TextContextType) {
		calls.append((word, context))
	}
}
