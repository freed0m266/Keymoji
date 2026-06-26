import XCTest
import KeymojiCore
@testable import Analytics

/// The acceptance gate for "opt-out OFF → zero signals" (ADR 0004, task 86) plus the Codex P1 fixes:
/// while opted out, the SDK must never run at all (not merely have `report` no-op), and an unconfigured
/// App ID must stay inert. Uses the `Provider` seam to assert start/stop/send without booting TelemetryDeck.
@MainActor
final class TelemetryDeckAnalyticsServiceTests: XCTestCase {

	private static let consentSuite = "keymoji.TelemetryDeckAnalyticsServiceTests.consent"
	private let validAppID = "00000000-0000-0000-0000-000000000000"

	private var defaults: UserDefaults!
	private var consent: AnalyticsConsentStore!

	/// Records the seam calls so tests can assert the SDK's running state and emitted signals.
	private final class Recorder {
		var starts = 0
		var stops = 0
		var sent: [(name: String, params: [String: String])] = []
		var provider: TelemetryDeckAnalyticsService.Provider {
			.init(
				start: { _ in self.starts += 1 },
				stop: { self.stops += 1 },
				send: { name, params in self.sent.append((name, params)) }
			)
		}
	}

	override func setUp() {
		super.setUp()
		defaults = UserDefaults(suiteName: Self.consentSuite)
		defaults.removePersistentDomain(forName: Self.consentSuite)
		consent = AnalyticsConsentStore(defaults: defaults)
	}

	override func tearDown() {
		defaults.removePersistentDomain(forName: Self.consentSuite)
		super.tearDown()
	}

	private func makeService(_ rec: Recorder, appID: String? = nil) -> TelemetryDeckAnalyticsService {
		TelemetryDeckAnalyticsService(appID: appID ?? validAppID, consent: consent, provider: rec.provider)
	}

	// MARK: - Opt-out → SDK never runs, nothing sent

	func testOptOut_neverStartsSDK_andEmitsNothing() {
		consent.isEnabled = false
		let rec = Recorder()
		let service = makeService(rec)        // constructed opted-out

		service.report(.reviewTapped)
		service.report(.settingsSubScreenOpened(.about))

		XCTAssertEqual(rec.starts, 0, "SDK must not be initialized while opted out")
		XCTAssertTrue(rec.sent.isEmpty, "No signal may be sent while opted out")
	}

	// MARK: - Opt-in → boots at launch and sends

	func testDefaultConsent_bootsSDKAndSends() {
		let rec = Recorder()
		let service = makeService(rec)        // default consent = opted in

		XCTAssertEqual(rec.starts, 1, "Opted-in launch must boot the SDK (for its session/retention signal)")

		service.report(.paywallShown(context: .settings))
		XCTAssertEqual(rec.sent.count, 1)
		XCTAssertEqual(rec.sent.first?.name, "Funnel.paywallShown")
		XCTAssertEqual(rec.sent.first?.params, ["context": PaywallContext.settings.rawValue])
	}

	// MARK: - Runtime consent flips

	func testFlipOnToOff_terminatesSDK_andStopsSending() {
		let rec = Recorder()
		let service = makeService(rec)        // opted in → started
		XCTAssertEqual(rec.starts, 1)

		consent.isEnabled = false
		service.consentDidChange()

		XCTAssertEqual(rec.stops, 1, "Opt-out must fully shut the SDK down")
		service.report(.reviewTapped)
		XCTAssertTrue(rec.sent.isEmpty, "Nothing may be sent after opting out")
	}

	func testFlipOffToOn_bootsSDK_andSends() {
		consent.isEnabled = false
		let rec = Recorder()
		let service = makeService(rec)        // dormant
		XCTAssertEqual(rec.starts, 0)

		consent.isEnabled = true
		service.consentDidChange()

		XCTAssertEqual(rec.starts, 1, "Opt-in must boot the SDK")
		service.report(.reviewTapped)
		XCTAssertEqual(rec.sent.map(\.name), ["Funnel.reviewTapped"])
	}

	// MARK: - Unconfigured App ID stays inert (Codex P1)

	func testPlaceholderAppID_staysInert_evenWhenOptedIn() {
		let rec = Recorder()
		let service = makeService(rec, appID: TelemetryDeckConfiguration.unconfiguredAppID)

		XCTAssertEqual(rec.starts, 0, "Placeholder App ID must not boot the SDK")
		service.report(.reviewTapped)
		XCTAssertTrue(rec.sent.isEmpty, "Placeholder App ID must send nothing — never to a bogus project")
	}
}
