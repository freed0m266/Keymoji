import XCTest
@testable import KeymojiCore

final class LetterAlternateSetTests: XCTestCase {

	// MARK: - detectedDefault: language → region → .all

	func testDetectedDefault_languageMatch() {
		// A matching language wins outright — the region is never consulted.
		XCTAssertEqual(
			LetterAlternateSet.detectedDefault(preferredLanguageCode: "cs", regionCode: "US"),
			.czech
		)
	}

	func testDetectedDefault_languageMiss_regionFallback() {
		// Czech user on an English-language phone (UI in English, region still CZ) gets Czech accents.
		XCTAssertEqual(
			LetterAlternateSet.detectedDefault(preferredLanguageCode: "en", regionCode: "CZ"),
			.czech
		)
	}

	func testDetectedDefault_bothMiss_returnsAll() {
		XCTAssertEqual(
			LetterAlternateSet.detectedDefault(preferredLanguageCode: "en", regionCode: "GB"),
			.all
		)
	}

	func testDetectedDefault_ambiguousRegion_returnsAll() {
		// Multilingual regions (CH, BE, LU…) are intentionally excluded → `.all`.
		XCTAssertEqual(
			LetterAlternateSet.detectedDefault(preferredLanguageCode: "en", regionCode: "CH"),
			.all
		)
	}

	func testDetectedDefault_nilInputs_returnsAll() {
		XCTAssertEqual(
			LetterAlternateSet.detectedDefault(preferredLanguageCode: nil, regionCode: nil),
			.all
		)
	}

	func testDetectedDefault_emptyLanguageCode_fallsThroughToRegion() {
		// An empty language code (parsing produced "") misses `byLanguage` without crashing and
		// falls through to the region.
		XCTAssertEqual(
			LetterAlternateSet.detectedDefault(preferredLanguageCode: "", regionCode: "DE"),
			.german
		)
	}

	func testDetectedDefault_austriaRegion_mapsToGerman() {
		XCTAssertEqual(
			LetterAlternateSet.detectedDefault(preferredLanguageCode: "en", regionCode: "AT"),
			.german
		)
	}

	// MARK: - accentLanguageCode (task 65)

	func testAccentLanguageCode_concreteLanguages() {
		XCTAssertEqual(LetterAlternateSet.czech.accentLanguageCode, "cs")
		XCTAssertEqual(LetterAlternateSet.slovak.accentLanguageCode, "sk")
		XCTAssertEqual(LetterAlternateSet.german.accentLanguageCode, "de")
		XCTAssertEqual(LetterAlternateSet.polish.accentLanguageCode, "pl")
		XCTAssertEqual(LetterAlternateSet.french.accentLanguageCode, "fr")
		XCTAssertEqual(LetterAlternateSet.spanish.accentLanguageCode, "es")
	}

	func testAccentLanguageCode_allIsNil() {
		// `.all` isn't a single language — it contributes no completion dictionary.
		XCTAssertNil(LetterAlternateSet.all.accentLanguageCode)
	}

	func testAccentLanguageCode_definedForEveryConcreteSet() {
		// Guards against a new set being added without a `byLanguage` entry.
		for set in LetterAlternateSet.allCases where set != .all {
			XCTAssertNotNil(set.accentLanguageCode, "\(set) must map to a language code")
		}
	}

	// MARK: - Round-trip / coverage

	func testRawValueRoundTrip() {
		for set in LetterAlternateSet.allCases {
			XCTAssertEqual(LetterAlternateSet(rawValue: set.rawValue), set)
		}
	}
}
