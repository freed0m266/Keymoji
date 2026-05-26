import XCTest
@testable import KeyboCore

@MainActor
final class SettingsChangeNotifierTests: XCTestCase {

	// Darwin notifications are system-wide. Tests within a single process still go through
	// the Darwin center, so post → observe round-trips work and prove the wiring without
	// needing two processes. (The actual host-app → extension hop can only be verified
	// manually on device — there's no two-process XCTest harness.)

	func testPost_invokesObserverHandler() async {
		let notifier = SettingsChangeNotifier()
		let expectation = expectation(description: "handler fires")
		let token = notifier.addObserver(for: .showNumberRow) {
			expectation.fulfill()
		}

		notifier.post(.showNumberRow)

		await fulfillment(of: [expectation], timeout: 2.0)
		_ = token // keep alive past the fulfillment
	}

	func testPost_doesNotInvokeObserverForDifferentKey() async {
		let notifier = SettingsChangeNotifier()
		let unwanted = expectation(description: "handler must NOT fire")
		unwanted.isInverted = true
		let token = notifier.addObserver(for: .showNumberRow) {
			unwanted.fulfill()
		}

		notifier.post(.hapticFeedbackEnabled)

		await fulfillment(of: [unwanted], timeout: 0.5)
		_ = token
	}

	func testToken_deinit_removesObserver() async {
		let notifier = SettingsChangeNotifier()
		let unwanted = expectation(description: "handler must NOT fire after token released")
		unwanted.isInverted = true

		// Scope the token so it deallocates before we post.
		do {
			let token = notifier.addObserver(for: .appearance) {
				unwanted.fulfill()
			}
			_ = token
		}

		notifier.post(.appearance)

		await fulfillment(of: [unwanted], timeout: 0.5)
	}

	func testMultipleObservers_onSameKey_allFire() async {
		let notifier = SettingsChangeNotifier()
		let first = expectation(description: "first handler")
		let second = expectation(description: "second handler")
		let tokenA = notifier.addObserver(for: .favoriteEmojis) {
			first.fulfill()
		}
		let tokenB = notifier.addObserver(for: .favoriteEmojis) {
			second.fulfill()
		}

		notifier.post(.favoriteEmojis)

		await fulfillment(of: [first, second], timeout: 2.0)
		_ = (tokenA, tokenB)
	}
}
