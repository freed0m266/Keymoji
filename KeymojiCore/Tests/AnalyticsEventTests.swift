import XCTest
@testable import KeymojiCore

/// Pins the wire contract of `AnalyticsEvent`: stable signal names, and content-free parameters on
/// every non-snapshot case (the snapshot's payload is covered by `AnalyticsSettingsSnapshotTests`).
final class AnalyticsEventTests: XCTestCase {

	func testSignalNames_areStable() {
		XCTAssertEqual(AnalyticsEvent.onboardingCompleted.signalName, "Lifecycle.onboardingCompleted")
		XCTAssertEqual(AnalyticsEvent.purchaseCompleted.signalName, "Funnel.purchaseCompleted")
		XCTAssertEqual(AnalyticsEvent.trialActivated.signalName, "Funnel.trialActivated")
		XCTAssertEqual(AnalyticsEvent.reviewTapped.signalName, "Funnel.reviewTapped")
		XCTAssertEqual(AnalyticsEvent.paywallShown(context: .settings).signalName, "Funnel.paywallShown")
		XCTAssertEqual(AnalyticsEvent.settingsSubScreenOpened(.about).signalName, "Navigation.settingsSubScreen")
	}

	func testLifecycleEvents_carryNoParameters() {
		for event: AnalyticsEvent in [.onboardingCompleted, .purchaseCompleted, .trialActivated, .reviewTapped] {
			XCTAssertTrue(event.parameters.isEmpty, "\(event.signalName) must carry no parameters")
		}
	}

	func testPaywallShown_carriesOnlyContextLabel() {
		let params = AnalyticsEvent.paywallShown(context: .afterTrial).parameters
		XCTAssertEqual(params, ["context": PaywallContext.afterTrial.rawValue])
	}

	func testSubScreenOpened_carriesOnlyScreenLabel() {
		let params = AnalyticsEvent.settingsSubScreenOpened(.learnedWords).parameters
		XCTAssertEqual(params, ["screen": AnalyticsSubScreen.learnedWords.rawValue])
	}
}
