import XCTest
@testable import KeymojiCore

/// Boundary-2 guard (ADR 0004): the settings snapshot may carry only enumerated states and coarse
/// buckets — never content. These tests pin the allow-list, the bucket boundaries, and that seeded
/// content (favourite glyphs, learned words) never reaches the wire parameters.
final class AnalyticsSettingsSnapshotTests: XCTestCase {

	private static let storeSuite = "keymoji.AnalyticsSettingsSnapshotTests.store"
	private static let consentSuite = "keymoji.AnalyticsSettingsSnapshotTests.consent"

	private var store: AppGroupStore!
	private var consentDefaults: UserDefaults!
	private var consent: AnalyticsConsentStore!

	/// The exact set of keys the wire payload is allowed to contain. Adding a key here is a deliberate
	/// act — a reviewer must confirm it carries no content.
	private let allowedKeys: Set<String> = [
		"appearance", "letterLayout", "letterAlternateSet", "showNumberRow", "hapticFeedback",
		"keyClickSound", "spaceDoubleTap", "suggestions", "autoCapitalization", "plusStatus",
		"analyticsEnabled", "favoritesCount", "learnedWordsCount"
	]

	override func setUp() {
		super.setUp()
		store = AppGroupStore(suiteName: Self.storeSuite)
		store.reset()
		consentDefaults = UserDefaults(suiteName: Self.consentSuite)
		consentDefaults.removePersistentDomain(forName: Self.consentSuite)
		consent = AnalyticsConsentStore(defaults: consentDefaults)
	}

	override func tearDown() {
		store.reset()
		consentDefaults.removePersistentDomain(forName: Self.consentSuite)
		super.tearDown()
	}

	// MARK: - Allow-list / no content

	func testParameters_onlyContainAllowedKeys() {
		let params = AnalyticsSettingsSnapshot.current(store: store, consent: consent).parameters
		XCTAssertEqual(Set(params.keys), allowedKeys)
	}

	func testSnapshot_neverLeaksFavoriteGlyphsOrLearnedWords() {
		// Seed real "content": favourite emoji and learned words with distinctive tokens.
		store.favoriteEmojis = ["🦄", "🔥"]
		store.wordCompletionRecentsJSON = #"{"hunter2":5,"s3cr3tword":3}"#

		let params = AnalyticsSettingsSnapshot.current(store: store, consent: consent).parameters
		let wireBlob = params.values.joined(separator: "|")

		for secret in ["🦄", "🔥", "hunter2", "s3cr3tword"] {
			XCTAssertFalse(wireBlob.contains(secret), "Snapshot leaked content token: \(secret)")
		}
		// The counts survive — but only as buckets, not the raw numbers.
		XCTAssertEqual(params["favoritesCount"], AnalyticsCountBucket.low.rawValue)        // 2 → 1–3
		XCTAssertEqual(params["learnedWordsCount"], AnalyticsCountBucket.low.rawValue)     // 2 → 1–9
	}

	// MARK: - Faithful mapping

	func testSnapshot_reflectsStoredSettings() {
		store.appearance = .dark
		store.letterLayout = .qwertz
		store.letterAlternateSet = .slovak
		store.showNumberRow = false
		store.hapticFeedbackEnabled = false
		store.keyClickSoundEnabled = true
		store.spaceDoubleTapAction = .dismissKeyboard
		store.suggestionsEnabled = false
		store.autoCapitalizationEnabled = false

		let params = AnalyticsSettingsSnapshot.current(store: store, consent: consent).parameters
		XCTAssertEqual(params["appearance"], AppearancePreference.dark.rawValue)
		XCTAssertEqual(params["letterLayout"], LetterLayout.qwertz.rawValue)
		XCTAssertEqual(params["letterAlternateSet"], LetterAlternateSet.slovak.rawValue)
		XCTAssertEqual(params["showNumberRow"], "false")
		XCTAssertEqual(params["hapticFeedback"], "false")
		XCTAssertEqual(params["keyClickSound"], "true")
		XCTAssertEqual(params["spaceDoubleTap"], SpaceDoubleTapAction.dismissKeyboard.rawValue)
		XCTAssertEqual(params["suggestions"], "false")
		XCTAssertEqual(params["autoCapitalization"], "false")
	}

	func testSnapshot_reflectsAnalyticsConsentState() {
		consent.isEnabled = false
		let params = AnalyticsSettingsSnapshot.current(store: store, consent: consent).parameters
		XCTAssertEqual(params["analyticsEnabled"], "false")
	}

	// MARK: - Plus status

	func testPlusStatus_paidWins() {
		store.isPlus = true
		store.promoPlusExpiresAt = nil
		let params = AnalyticsSettingsSnapshot.current(store: store, consent: consent).parameters
		XCTAssertEqual(params["plusStatus"], AnalyticsPlusStatus.paid.rawValue)
	}

	func testPlusStatus_activePromoIsTrial() {
		store.isPlus = false
		store.promoPlusExpiresAt = Date(timeIntervalSinceNow: 86_400)
		let now = Date()
		let params = AnalyticsSettingsSnapshot.current(store: store, consent: consent, now: now).parameters
		XCTAssertEqual(params["plusStatus"], AnalyticsPlusStatus.trial.rawValue)
	}

	func testPlusStatus_expiredPromoIsFree() {
		store.isPlus = false
		store.promoPlusExpiresAt = Date(timeIntervalSinceNow: -60)
		let params = AnalyticsSettingsSnapshot.current(store: store, consent: consent).parameters
		XCTAssertEqual(params["plusStatus"], AnalyticsPlusStatus.free.rawValue)
	}

	// MARK: - Buckets

	func testFavoritesBuckets() {
		XCTAssertEqual(AnalyticsCountBucket.favorites(0), .none)
		XCTAssertEqual(AnalyticsCountBucket.favorites(1), .low)
		XCTAssertEqual(AnalyticsCountBucket.favorites(3), .low)
		XCTAssertEqual(AnalyticsCountBucket.favorites(4), .medium)
		XCTAssertEqual(AnalyticsCountBucket.favorites(6), .medium)
		XCTAssertEqual(AnalyticsCountBucket.favorites(7), .high)
		XCTAssertEqual(AnalyticsCountBucket.favorites(99), .high)
	}

	func testLearnedWordsBuckets() {
		XCTAssertEqual(AnalyticsCountBucket.learnedWords(0), .none)
		XCTAssertEqual(AnalyticsCountBucket.learnedWords(9), .low)
		XCTAssertEqual(AnalyticsCountBucket.learnedWords(10), .medium)
		XCTAssertEqual(AnalyticsCountBucket.learnedWords(49), .medium)
		XCTAssertEqual(AnalyticsCountBucket.learnedWords(50), .high)
		XCTAssertEqual(AnalyticsCountBucket.learnedWords(199), .high)
		XCTAssertEqual(AnalyticsCountBucket.learnedWords(200), .veryHigh)
	}
}
