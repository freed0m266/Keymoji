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

	// MARK: - completionLanguage: accent → device → English (task 78)

	func testCompletionLanguage_accentWins_deviceIgnored() {
		// A concrete accent set names the language outright; the device language is never consulted.
		XCTAssertEqual(LetterAlternateSet.czech.completionLanguage(deviceLanguageCode: "ja"), "cs")
		XCTAssertEqual(LetterAlternateSet.german.completionLanguage(deviceLanguageCode: "en"), "de")
	}

	func testCompletionLanguage_allUsesDeviceLanguage() {
		// `.all` carries no language of its own, so it follows the device — any language, not just the
		// six accent ones.
		XCTAssertEqual(LetterAlternateSet.all.completionLanguage(deviceLanguageCode: "cs"), "cs")
		XCTAssertEqual(LetterAlternateSet.all.completionLanguage(deviceLanguageCode: "en"), "en")
		XCTAssertEqual(LetterAlternateSet.all.completionLanguage(deviceLanguageCode: "ja"), "ja")
	}

	func testCompletionLanguage_allWithNoDeviceLanguage_fallsBackToEnglish() {
		// `.all` and no resolvable device language → English is the final fallback.
		XCTAssertEqual(LetterAlternateSet.all.completionLanguage(deviceLanguageCode: nil), "en")
	}

	func testCompletionLanguage_accentWinsEvenWithNilDevice() {
		// The accent link short-circuits the chain before the device/English fallbacks are reached.
		XCTAssertEqual(LetterAlternateSet.spanish.completionLanguage(deviceLanguageCode: nil), "es")
	}

	// MARK: - deviceLanguageCode parsing

	func testDeviceLanguageCode_regionalTag_parsesBareLanguage() {
		// `Locale.preferredLanguages` entries can be regional ("en-CZ") — only the language code is kept.
		XCTAssertEqual(LetterAlternateSet.deviceLanguageCode(preferredLanguage: "en-CZ"), "en")
		XCTAssertEqual(LetterAlternateSet.deviceLanguageCode(preferredLanguage: "zh-Hans-CN"), "zh")
	}

	func testDeviceLanguageCode_plainLanguage_passesThrough() {
		XCTAssertEqual(LetterAlternateSet.deviceLanguageCode(preferredLanguage: "cs"), "cs")
	}

	func testDeviceLanguageCode_nilOrEmpty_returnsNil() {
		// No preferred language, or one that parses to no code, yields nil so the chain falls to English.
		XCTAssertNil(LetterAlternateSet.deviceLanguageCode(preferredLanguage: nil))
		XCTAssertNil(LetterAlternateSet.deviceLanguageCode(preferredLanguage: ""))
	}

	// MARK: - Round-trip / coverage

	func testRawValueRoundTrip() {
		for set in LetterAlternateSet.allCases {
			XCTAssertEqual(LetterAlternateSet(rawValue: set.rawValue), set)
		}
	}
}
