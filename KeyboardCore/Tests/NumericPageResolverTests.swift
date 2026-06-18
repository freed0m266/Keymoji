import XCTest
import KeymojiCore
@testable import KeyboardCore

/// `NumericPageResolver` maps a focused field's keyboard type onto the numpad page it should force,
/// or `nil` when the field wants its regular typing layout (task 59). Only `.numberPad` /
/// `.decimalPad` force the numpad; everything else — including the letter-wanting
/// `.asciiCapableNumberPad` and the phone pads — opts out.
final class NumericPageResolverTests: XCTestCase {

	func testNumberPad_mapsToIntegerNumpad() {
		XCTAssertEqual(NumericPageResolver.numericPage(for: .numberPad), .numeric(.integer))
	}

	func testDecimalPad_mapsToDecimalNumpad() {
		XCTAssertEqual(NumericPageResolver.numericPage(for: .decimalPad), .numeric(.decimal))
	}

	func testAsciiCapableNumberPad_optsOut() {
		// Wants letters too — a locked numpad would trap the user, so it keeps the typing layout.
		XCTAssertNil(NumericPageResolver.numericPage(for: .asciiCapableNumberPad))
	}

	func testPhonePads_optOut() {
		XCTAssertNil(NumericPageResolver.numericPage(for: .phonePad))
		XCTAssertNil(NumericPageResolver.numericPage(for: .namePhonePad))
	}

	func testTextKinds_optOut() {
		for kind: KeyboardInputKind in [.default, .asciiCapable, .numbersAndPunctuation, .url,
		                                .emailAddress, .twitter, .webSearch] {
			XCTAssertNil(NumericPageResolver.numericPage(for: kind), "\(kind) must not force the numpad")
		}
	}
}
