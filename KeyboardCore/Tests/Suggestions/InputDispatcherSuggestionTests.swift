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

	func testSuggestionAccept_onSymbolsPage_hopsBackToLetters() {
		// Completions run on `.symbols` (Fáze B): accepting a numeric/nick chip there must hop back to
		// letters like a real space, so the user isn't stranded on `123`.
		var state = KeyboardState(
			page: .symbols(.primary),
			currentEligibility: SuggestionEligibility(allowDisplay: true, learningContext: .prose)
		)
		proxy.documentContextBeforeInput = "604"
		dispatch(acceptKey("604593010"), &state)
		XCTAssertEqual(proxy.inserted, ["604593010 "])
		XCTAssertEqual(state.page, .letters(.lower), "symbols → letters after accept")
	}

	func testSuggestionAccept_onLettersPage_staysOnLetters() {
		var state = proseState()
		proxy.documentContextBeforeInput = "hel"
		dispatch(acceptKey("hello"), &state)
		XCTAssertEqual(state.page, .letters(.lower))
	}

	func testSuggestionAccept_marksTrailingSpaceForDoubleTap() {
		var state = proseState()
		proxy.documentContextBeforeInput = "hel"
		dispatch(acceptKey("hello"), &state)
		XCTAssertTrue(state.lastInsertWasSpace)
		XCTAssertNotNil(state.lastSpaceInsertedAt)
	}

	// MARK: - .suggestionAccept as a usage signal (Fáze D)

	private func learningHook() -> LearningHook {
		LearningHook { [recorder] word, context in recorder?.record(word, context) }
	}

	func testSuggestionAccept_inProse_learnsAcceptedWord() {
		// Accepting a chip is using the word — it learns/increments the accepted replacement, not the
		// (possibly shorter) typed prefix. Promotes a dictionary-only word into the personal pool.
		var state = proseState()
		proxy.documentContextBeforeInput = "hel"
		dispatch(acceptKey("hello"), &state, learning: learningHook())
		XCTAssertEqual(recorder.calls.map(\.word), ["hello"])
		XCTAssertEqual(recorder.calls.first?.context, .prose)
	}

	func testSuggestionAccept_inEmail_doesNotLearn() {
		// Email fields are harvested whole at field-end; the `.prose` gate keeps accept from double-counting.
		var state = KeyboardState(
			page: .letters(.lower),
			currentEligibility: SuggestionEligibility(allowDisplay: true, learningContext: .emailAddress)
		)
		proxy.documentContextBeforeInput = ""
		dispatch(acceptKey("martin@x.com"), &state, learning: learningHook())
		XCTAssertTrue(recorder.calls.isEmpty, "email accept routes through field-end harvest, not accept-learn")
	}

	func testSuggestionAccept_inEmail_omitsTrailingSpace() {
		// An accepted address lands as a bare value — no trailing blank (email inputs commonly reject or
		// retain it). State tracking reflects that no space was inserted.
		var state = KeyboardState(
			page: .letters(.lower),
			currentEligibility: SuggestionEligibility(allowDisplay: true, learningContext: .emailAddress)
		)
		proxy.documentContextBeforeInput = "mar"
		dispatch(acceptKey("martin@x.com"), &state)
		XCTAssertEqual(proxy.deleteCount, 3, "the typed prefix is still replaced")
		XCTAssertEqual(proxy.inserted, ["martin@x.com"], "no trailing space in an email field")
		XCTAssertEqual(proxy.documentContextBeforeInput, "martin@x.com")
		XCTAssertFalse(state.lastInsertWasSpace)
		XCTAssertNil(state.lastSpaceInsertedAt)
	}

	func testSuggestionAccept_inProse_keepsTrailingSpace() {
		// Contrast with the email case: prose accepts keep the stock predictive-bar trailing space.
		var state = proseState()
		proxy.documentContextBeforeInput = "hel"
		dispatch(acceptKey("hello"), &state)
		XCTAssertEqual(proxy.inserted, ["hello "])
		XCTAssertTrue(state.lastInsertWasSpace)
	}

	func testSuggestionAccept_deniedContext_doesNotLearn() {
		var state = KeyboardState(page: .letters(.lower), currentEligibility: .denied)
		proxy.documentContextBeforeInput = "sec"
		dispatch(acceptKey("secret"), &state, learning: learningHook())
		XCTAssertTrue(recorder.calls.isEmpty)
	}

	func testSuggestionAccept_nilHook_doesNotLearn() {
		// Suggestions off → the controller passes a nil hook → accept inserts but learns nothing.
		var state = proseState()
		proxy.documentContextBeforeInput = "hel"
		dispatch(acceptKey("hello"), &state)
		XCTAssertEqual(proxy.inserted, ["hello "], "text still inserts")
		XCTAssertTrue(recorder.calls.isEmpty)
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

	func testLearning_prose_capturesWholeEmail() {
		// A prose-typed address is learned as one `.emailAddress` token (the tokenizer would otherwise
		// split it on `@`/`.`), and its trailing fragment ("com") is not also learned.
		var state = proseState()
		let hook = LearningHook { [recorder] word, context in recorder?.record(word, context) }
		for ch in "martin@gmail.com" { dispatch(letterKey(String(ch)), &state, learning: hook) }
		dispatch(spaceKey(), &state, learning: hook)
		XCTAssertTrue(
			recorder.calls.contains { $0.word == "martin@gmail.com" && $0.context == .emailAddress },
			"the whole address is learned as an email token"
		)
		XCTAssertFalse(recorder.calls.contains { $0.word == "com" }, "the trailing fragment is skipped")
	}

	func testLearning_prose_emailCapture_skippedInDenied() {
		var state = KeyboardState(page: .letters(.lower), currentEligibility: .denied)
		let hook = LearningHook { [recorder] word, context in recorder?.record(word, context) }
		for ch in "martin@gmail.com" { dispatch(letterKey(String(ch)), &state, learning: hook) }
		dispatch(spaceKey(), &state, learning: hook)
		XCTAssertTrue(recorder.calls.isEmpty)
	}

	func testLearning_emailField_doesNotInlineCaptureEmail() {
		// Email fields learn the whole field via the controller's harvest, never word-by-word inline —
		// so the dispatcher's prose email capture must not fire here (would double-count).
		var state = KeyboardState(
			page: .letters(.lower),
			currentEligibility: SuggestionEligibility(allowDisplay: true, learningContext: .emailAddress)
		)
		let hook = LearningHook { [recorder] word, context in recorder?.record(word, context) }
		for ch in "martin@gmail.com" { dispatch(letterKey(String(ch)), &state, learning: hook) }
		dispatch(spaceKey(), &state, learning: hook)
		XCTAssertTrue(recorder.calls.isEmpty)
	}

	func testLearning_nilHook_isNoOp() {
		var state = proseState()
		for char in "hello" { dispatch(letterKey(String(char)), &state) }
		dispatch(Key(id: "space", primary: .text(""), alternates: [], action: .space, visualWeight: .space, role: .system), &state)
		// No learning hook supplied → nothing recorded, no crash.
		XCTAssertTrue(recorder.calls.isEmpty)
	}

	// MARK: - Whitespace tokenizer + normalize-on-store (task 79)

	private func type(_ text: String, into state: inout KeyboardState, hook: LearningHook) {
		for ch in text {
			let key = ch == " " ? spaceKey() : letterKey(String(ch))
			dispatch(key, &state, learning: hook)
		}
	}

	func testLearning_emailThroughDots_learnsWholeAddress_dropsPartials() {
		// Typed in a prose field, `sv.mar@email.cz ` is learned as one `.emailAddress` token. The
		// internal-dot partials the learning boundaries fire on (`sv.`, `sv.mar@email.`) are dropped: too
		// short, or a TLD-less `@` token that isn't email-shaped.
		var state = proseState()
		type("sv.mar@email.cz ", into: &state, hook: learningHook())
		XCTAssertEqual(recorder.calls.map(\.word), ["sv.mar@email.cz"], "only the full address is learned")
		XCTAssertEqual(recorder.calls.first?.context, .emailAddress)
	}

	func testLearning_atTokenWithoutTLD_isDropped() {
		// `foo@bar` has an `@` but isn't a full address (no TLD) → not learned (not as prose either).
		var state = proseState()
		type("foo@bar ", into: &state, hook: learningHook())
		XCTAssertTrue(recorder.calls.isEmpty)
	}

	func testLearning_trailingComma_isTrimmed() {
		// `ahoj,` learns `ahoj` (edge punctuation trimmed by `wordCore`).
		var state = proseState()
		type("ahoj,", into: &state, hook: learningHook())
		XCTAssertEqual(recorder.calls.map(\.word), ["ahoj"])
		XCTAssertEqual(recorder.calls.first?.context, .prose)
	}

	func testLearning_sentenceFinalWord_withoutTrailingSpace() {
		// The period learning trigger captures `pizzu` from `pizzu.` even with no trailing space.
		var state = proseState()
		type("pizzu.", into: &state, hook: learningHook())
		XCTAssertEqual(recorder.calls.map(\.word), ["pizzu"])
	}

	func testLearning_abbreviations_areNotStored() {
		// `e.g.` / `i.e.` trim to a 2-alphanumeric core and are dropped (AC: never stored).
		var state = proseState()
		type("e.g. ", into: &state, hook: learningHook())
		type("i.e. ", into: &state, hook: learningHook())
		XCTAssertTrue(recorder.calls.isEmpty)
	}

	func testLearning_hyphenatedWord_isOneToken() {
		// `well-known` is a single learned token now (internal hyphen kept), not `known`.
		var state = proseState()
		type("well-known ", into: &state, hook: learningHook())
		XCTAssertEqual(recorder.calls.map(\.word), ["well-known"])
	}

	func testLearning_periodThenSpace_doesNotDoubleCount() {
		// A second boundary right after a punctuation one must not re-learn: `hello. ` learns `hello` once.
		var state = proseState()
		for ch in "hello" { dispatch(letterKey(String(ch)), &state, learning: learningHook()) }
		dispatch(boundaryKey("."), &state, learning: learningHook())
		dispatch(spaceKey(), &state, learning: learningHook())
		XCTAssertEqual(recorder.calls.map(\.word), ["hello"], "learned exactly once")
	}

	func testLearning_trailingNonTriggerPunctuation_isTrimmedAndLearned() {
		// Punctuation that isn't a learning trigger (`:`, `)`, `;`) sits between the word and the space.
		// The space is still the *first* learning boundary, so the token reaches `wordCore` and is learned.
		var state = proseState()
		type("note: ", into: &state, hook: learningHook())
		type("(hello) ", into: &state, hook: learningHook())
		XCTAssertEqual(recorder.calls.map(\.word), ["note", "hello"])
	}

	func testLearning_parenthesizedEmail_isLearned() {
		// `sv.mar@email.cz)` then space: the `)` isn't a learning trigger, so the space harvests the whole
		// token and `wordCore` trims the `)` → a full address is still learned.
		var state = proseState()
		type("(sv.mar@email.cz) ", into: &state, hook: learningHook())
		XCTAssertEqual(recorder.calls.map(\.word), ["sv.mar@email.cz"])
		XCTAssertEqual(recorder.calls.first?.context, .emailAddress)
	}

	func testLearning_triggerThenNonTriggerThenSpace_doesNotDoubleCount() {
		// `word.; ` — the period harvests `word`; the trailing `;`+space must NOT re-harvest it (an earlier
		// learning boundary already sits in the gap before the space).
		var state = proseState()
		for ch in "etc" { dispatch(letterKey(String(ch)), &state, learning: learningHook()) }
		dispatch(boundaryKey("."), &state, learning: learningHook())
		dispatch(boundaryKey(";"), &state, learning: learningHook())
		dispatch(spaceKey(), &state, learning: learningHook())
		XCTAssertEqual(recorder.calls.map(\.word), ["etc"], "learned exactly once despite the trailing `;`")
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
