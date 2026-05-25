import XCTest
import SwiftUI
@testable import KeyboardUI
import KeyboardCore

final class KeyboardViewSnapshots: XCTestCase {

	private static let iPhoneWidth: CGFloat = 393

	// MARK: - Letters lower

	func testLettersLower_withNumberRow() {
		let layout = KeyboardCore.makeLayout(page: .letters(.lower), showNumberRow: true, returnKeyType: .default)
		let view = KeyboardView(layout: layout, width: Self.iPhoneWidth, onKey: { _ in })

		assertKeyboardSnapshot(view, colorScheme: .dark)
		assertKeyboardSnapshot(view, colorScheme: .light)
	}

	// MARK: - Letters upper / caps lock

	func testLettersUpper_withNumberRow() {
		let layout = KeyboardCore.makeLayout(page: .letters(.upper), showNumberRow: true, returnKeyType: .default)
		let view = KeyboardView(layout: layout, width: Self.iPhoneWidth, onKey: { _ in })

		assertKeyboardSnapshot(view, colorScheme: .dark)
		assertKeyboardSnapshot(view, colorScheme: .light)
	}

	func testLettersCapsLock_withNumberRow() {
		let layout = KeyboardCore.makeLayout(page: .letters(.capsLock), showNumberRow: true, returnKeyType: .default)
		let view = KeyboardView(layout: layout, width: Self.iPhoneWidth, onKey: { _ in })

		assertKeyboardSnapshot(view, colorScheme: .dark)
		assertKeyboardSnapshot(view, colorScheme: .light)
	}

	// MARK: - Symbols

	func testSymbolsPrimary_withNumberRow() {
		let layout = KeyboardCore.makeLayout(page: .symbols(.primary), showNumberRow: true, returnKeyType: .default)
		let view = KeyboardView(layout: layout, width: Self.iPhoneWidth, onKey: { _ in })

		assertKeyboardSnapshot(view, colorScheme: .dark)
		assertKeyboardSnapshot(view, colorScheme: .light)
	}

	func testSymbolsAlternate_withNumberRow() {
		let layout = KeyboardCore.makeLayout(page: .symbols(.alternate), showNumberRow: true, returnKeyType: .default)
		let view = KeyboardView(layout: layout, width: Self.iPhoneWidth, onKey: { _ in })

		assertKeyboardSnapshot(view, colorScheme: .dark)
		assertKeyboardSnapshot(view, colorScheme: .light)
	}

	func testSymbolsPrimary_withoutNumberRow() {
		let layout = KeyboardCore.makeLayout(page: .symbols(.primary), showNumberRow: false, returnKeyType: .default)
		let view = KeyboardView(layout: layout, width: Self.iPhoneWidth, onKey: { _ in })

		let size = CGSize(width: 393, height: 216)
		assertKeyboardSnapshot(view, size: size, colorScheme: .dark)
	}

	// MARK: - Without number row

	func testLettersLower_withoutNumberRow() {
		let layout = KeyboardCore.makeLayout(page: .letters(.lower), showNumberRow: false, returnKeyType: .default)
		let view = KeyboardView(layout: layout, width: Self.iPhoneWidth, onKey: { _ in })

		let size = CGSize(width: 393, height: 216)
		assertKeyboardSnapshot(view, size: size, colorScheme: .dark)
		assertKeyboardSnapshot(view, size: size, colorScheme: .light)
	}

	// MARK: - Adaptive return labels

	func testReturnLabel_search() {
		let layout = KeyboardCore.makeLayout(page: .letters(.lower), showNumberRow: true, returnKeyType: .search)
		assertKeyboardSnapshot(KeyboardView(layout: layout, width: Self.iPhoneWidth, onKey: { _ in }), colorScheme: .dark)
	}

	func testReturnLabel_go() {
		let layout = KeyboardCore.makeLayout(page: .letters(.lower), showNumberRow: true, returnKeyType: .go)
		assertKeyboardSnapshot(KeyboardView(layout: layout, width: Self.iPhoneWidth, onKey: { _ in }), colorScheme: .dark)
	}

	func testReturnLabel_done() {
		let layout = KeyboardCore.makeLayout(page: .letters(.lower), showNumberRow: true, returnKeyType: .done)
		assertKeyboardSnapshot(KeyboardView(layout: layout, width: Self.iPhoneWidth, onKey: { _ in }), colorScheme: .dark)
	}

	func testReturnLabel_send() {
		let layout = KeyboardCore.makeLayout(page: .letters(.lower), showNumberRow: true, returnKeyType: .send)
		assertKeyboardSnapshot(KeyboardView(layout: layout, width: Self.iPhoneWidth, onKey: { _ in }), colorScheme: .dark)
	}

	// MARK: - Emoji page

	func testEmojis_noRecents_withNumberRow() {
		let layout = KeyboardCore.makeLayout(page: .emojis, showNumberRow: true, returnKeyType: .default)
		let view = KeyboardView(
			layout: layout,
			width: Self.iPhoneWidth,
			recentEmojis: [],
			onKey: { _ in }
		)
		assertKeyboardSnapshot(view, colorScheme: .dark)
		assertKeyboardSnapshot(view, colorScheme: .light)
	}

	func testEmojis_withRecents_withNumberRow() {
		let layout = KeyboardCore.makeLayout(page: .emojis, showNumberRow: true, returnKeyType: .default)
		let view = KeyboardView(
			layout: layout,
			width: Self.iPhoneWidth,
			recentEmojis: ["😀", "👋", "🎉", "❤️", "🚀", "🍕", "🐶", "🌈"],
			onKey: { _ in }
		)
		assertKeyboardSnapshot(view, colorScheme: .dark)
		assertKeyboardSnapshot(view, colorScheme: .light)
	}

	// MARK: - Slack suggestion bar

	func testSlackSuggestions_replacesNumberRow() {
		let layout = KeyboardCore.makeLayout(page: .letters(.lower), showNumberRow: true, returnKeyType: .default)
		let suggestions: [SlackEmojiSuggester.Suggestion] = [
			.init(shortcode: "smile", emoji: "😄"),
			.init(shortcode: "smiley", emoji: "😃"),
			.init(shortcode: "smirk", emoji: "😏"),
			.init(shortcode: "smiling_imp", emoji: "😈"),
			.init(shortcode: "smoking", emoji: "🚬")
		]
		let view = KeyboardView(
			layout: layout,
			width: Self.iPhoneWidth,
			slackSuggestions: suggestions,
			onKey: { _ in }
		)
		assertKeyboardSnapshot(view, colorScheme: .dark)
		assertKeyboardSnapshot(view, colorScheme: .light)
	}

	func testSlackSuggestions_withoutNumberRow_growsKeyboard() {
		let layout = KeyboardCore.makeLayout(page: .letters(.lower), showNumberRow: false, returnKeyType: .default)
		let suggestions: [SlackEmojiSuggester.Suggestion] = [
			.init(shortcode: "fire", emoji: "🔥"),
			.init(shortcode: "thumbsup", emoji: "👍")
		]
		let view = KeyboardView(
			layout: layout,
			width: Self.iPhoneWidth,
			slackSuggestions: suggestions,
			onKey: { _ in }
		)
		let size = CGSize(width: 393, height: 260)
		assertKeyboardSnapshot(view, size: size, colorScheme: .dark)
	}

	func testEmojis_withFavorites_withNumberRow() {
		let layout = KeyboardCore.makeLayout(page: .emojis, showNumberRow: true, returnKeyType: .default)
		let view = KeyboardView(
			layout: layout,
			width: Self.iPhoneWidth,
			recentEmojis: ["😀", "👋"],
			favoriteEmojis: ["❤️", "🚀", "🍕", "🐶"],
			onKey: { _ in }
		)
		assertKeyboardSnapshot(view, colorScheme: .dark)
		assertKeyboardSnapshot(view, colorScheme: .light)
	}
}
