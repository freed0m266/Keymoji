import XCTest
@testable import KeyboardCore

final class SuggestionEligibilityTests: XCTestCase {

	private func evaluate(
		secure: Bool = false,
		keyboard: KeyboardInputKind = .default,
		content: TextContentKind? = nil
	) -> SuggestionEligibility {
		.evaluate(isSecureTextEntry: secure, keyboardType: keyboard, textContentType: content)
	}

	// MARK: - Secure entry wins over everything

	func testSecureEntry_deniesEverything() {
		let result = evaluate(secure: true, keyboard: .default, content: .emailAddress)
		XCTAssertFalse(result.allowDisplay)
		XCTAssertEqual(result.learningContext, .denied)
	}

	// MARK: - Sensitive content types

	func testSensitiveContentTypes_denied() {
		for content in [TextContentKind.password, .newPassword, .oneTimeCode, .creditCardNumber] {
			let result = evaluate(keyboard: .default, content: content)
			XCTAssertFalse(result.allowDisplay, "\(content) should deny display")
			XCTAssertEqual(result.learningContext, .denied)
		}
	}

	func testNameContentType_denied() {
		// Name fields are on the privacy deny-list even on a default keyboard.
		let result = evaluate(keyboard: .default, content: .name)
		XCTAssertFalse(result.allowDisplay)
		XCTAssertEqual(result.learningContext, .denied)
	}

	// MARK: - Email exception

	func testEmailContentType_displaysAndLearnsEmail() {
		let result = evaluate(keyboard: .default, content: .emailAddress)
		XCTAssertTrue(result.allowDisplay)
		XCTAssertEqual(result.learningContext, .emailAddress)
	}

	func testEmailKeyboard_displaysAndLearnsEmail() {
		let result = evaluate(keyboard: .emailAddress, content: nil)
		XCTAssertTrue(result.allowDisplay)
		XCTAssertEqual(result.learningContext, .emailAddress)
	}

	func testEmailContentType_overridesDenyKeyboard() {
		// Content type is evaluated before keyboard type, so an email content type wins even on a
		// number pad.
		let result = evaluate(keyboard: .numberPad, content: .emailAddress)
		XCTAssertTrue(result.allowDisplay)
		XCTAssertEqual(result.learningContext, .emailAddress)
	}

	// MARK: - Deny-list keyboard types

	func testDenyKeyboards_denied() {
		let denied: [KeyboardInputKind] = [
			.numberPad, .decimalPad, .phonePad, .asciiCapableNumberPad,
			.url, .webSearch, .twitter, .namePhonePad
		]
		for keyboard in denied {
			let result = evaluate(keyboard: keyboard, content: nil)
			XCTAssertFalse(result.allowDisplay, "\(keyboard) should deny display")
			XCTAssertEqual(result.learningContext, .denied)
		}
	}

	// MARK: - Prose default

	func testProseKeyboards_displayAndLearnProse() {
		for keyboard in [KeyboardInputKind.default, .asciiCapable, .numbersAndPunctuation] {
			let result = evaluate(keyboard: keyboard, content: nil)
			XCTAssertTrue(result.allowDisplay, "\(keyboard) should allow display")
			XCTAssertEqual(result.learningContext, .prose)
		}
	}

	func testOtherContentType_fallsBackToKeyboardRules() {
		// A non-sensitive content type (`.other`) defers to the keyboard type.
		XCTAssertEqual(evaluate(keyboard: .default, content: .other).learningContext, .prose)
		XCTAssertEqual(evaluate(keyboard: .numberPad, content: .other).learningContext, .denied)
	}

	func testDeniedDefault() {
		XCTAssertEqual(SuggestionEligibility.denied.learningContext, .denied)
		XCTAssertFalse(SuggestionEligibility.denied.allowDisplay)
	}
}
