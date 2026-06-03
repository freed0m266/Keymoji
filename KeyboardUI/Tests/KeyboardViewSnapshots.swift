import XCTest
import SwiftUI
@testable import KeyboardUI
import KeymojiCore
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

	// MARK: - QWERTZ letter layout

	func testLettersLower_qwertz_withNumberRow() {
		let layout = KeyboardCore.makeLayout(page: .letters(.lower), showNumberRow: true, returnKeyType: .default, letterLayout: .qwertz)
		let view = KeyboardView(layout: layout, width: Self.iPhoneWidth, onKey: { _ in })

		assertKeyboardSnapshot(view, colorScheme: .dark)
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

	// MARK: - Suggestion bar (task 40)

	/// Word chips coexist with the number row as a separate row above it (A2 — no mutex). The
	/// keyboard grows by the bar footprint, so the snapshot frame is taller than the base 260.
	private static let withBarAndNumberRowSize = CGSize(width: 393, height: 311)

	func testSuggestionBar_wordChips_withNumberRow() {
		let layout = KeyboardCore.makeLayout(page: .letters(.lower), showNumberRow: true, returnKeyType: .default)
		let suggestions: [Suggestion] = [
			.plainChip("hello", score: 0.9),
			.plainChip("help", score: 0.7),
			.plainChip("helicopter", score: 0.5)
		]
		let view = KeyboardView(
			layout: layout,
			width: Self.iPhoneWidth,
			suggestions: suggestions,
			showsSuggestionBar: true,
			onKey: { _ in }
		)
		assertKeyboardSnapshot(view, size: Self.withBarAndNumberRowSize, colorScheme: .dark)
		assertKeyboardSnapshot(view, size: Self.withBarAndNumberRowSize, colorScheme: .light)
	}

	func testSuggestionBar_slackPills_withNumberRow() {
		// Slack regression: pills now render in the same generic bar, stacked above the number row.
		let layout = KeyboardCore.makeLayout(page: .letters(.lower), showNumberRow: true, returnKeyType: .default)
		let suggestions: [Suggestion] = [
			.pillChip("smile", "😄"),
			.pillChip("smiley", "😃"),
			.pillChip("smirk", "😏"),
			.pillChip("smiling_imp", "😈")
		]
		let view = KeyboardView(
			layout: layout,
			width: Self.iPhoneWidth,
			suggestions: suggestions,
			showsSuggestionBar: true,
			onKey: { _ in }
		)
		assertKeyboardSnapshot(view, size: Self.withBarAndNumberRowSize, colorScheme: .dark)
	}

	func testSuggestionBar_alwaysShownWhenEmpty_withNumberRow() {
		// C1: the bar holds its slot even with no chips (visually silent), so height stays stable.
		let layout = KeyboardCore.makeLayout(page: .letters(.lower), showNumberRow: true, returnKeyType: .default)
		let view = KeyboardView(
			layout: layout,
			width: Self.iPhoneWidth,
			suggestions: [],
			showsSuggestionBar: true,
			onKey: { _ in }
		)
		assertKeyboardSnapshot(view, size: Self.withBarAndNumberRowSize, colorScheme: .dark)
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

	// MARK: - Emoji search page

	/// Search mode stacks ~92 pt of chrome (search bar + horizontal results bar) above the
	/// regular QWERTY rows. The view's intrinsic keyboardHeight grows accordingly; tests
	/// have to allocate the matching frame so the bottom space/delete row isn't clipped.
	private static let emojiSearchSize = CGSize(width: 393, height: 308)

	func testEmojiSearch_emptyQuery_noRecents() {
		let layout = KeyboardCore.makeLayout(page: .emojiSearch, showNumberRow: true, returnKeyType: .default)
		let view = KeyboardView(
			layout: layout,
			width: Self.iPhoneWidth,
			recentEmojis: [],
			searchQuery: "",
			onKey: { _ in }
		)
		assertKeyboardSnapshot(view, size: Self.emojiSearchSize, colorScheme: .dark)
	}

	func testEmojiSearch_emptyQuery_withRecents() {
		let layout = KeyboardCore.makeLayout(page: .emojiSearch, showNumberRow: true, returnKeyType: .default)
		let view = KeyboardView(
			layout: layout,
			width: Self.iPhoneWidth,
			recentEmojis: ["😀", "👋", "🎉", "❤️", "🚀", "🍕"],
			searchQuery: "",
			onKey: { _ in }
		)
		assertKeyboardSnapshot(view, size: Self.emojiSearchSize, colorScheme: .dark)
	}

	func testEmojiSearch_query_rain() {
		let layout = KeyboardCore.makeLayout(page: .emojiSearch, showNumberRow: true, returnKeyType: .default)
		let view = KeyboardView(
			layout: layout,
			width: Self.iPhoneWidth,
			recentEmojis: [],
			searchQuery: "rain",
			onKey: { _ in }
		)
		assertKeyboardSnapshot(view, size: Self.emojiSearchSize, colorScheme: .dark)
		assertKeyboardSnapshot(view, size: Self.emojiSearchSize, colorScheme: .light)
	}

	func testEmojiSearch_noResults() {
		let layout = KeyboardCore.makeLayout(page: .emojiSearch, showNumberRow: true, returnKeyType: .default)
		let view = KeyboardView(
			layout: layout,
			width: Self.iPhoneWidth,
			recentEmojis: [],
			searchQuery: "xyz123nope",
			onKey: { _ in }
		)
		assertKeyboardSnapshot(view, size: Self.emojiSearchSize, colorScheme: .dark)
	}

	func testEmojiSearchSymbols_primary_query7() {
		// Native parity: typing `7` in symbols sub-page surfaces matches like 7️⃣ and the
		// clock-7 glyph. Verifies the numbers/symbols layout renders correctly under search.
		let layout = KeyboardCore.makeLayout(page: .emojiSearchSymbols(.primary), showNumberRow: true, returnKeyType: .default)
		let view = KeyboardView(
			layout: layout,
			width: Self.iPhoneWidth,
			recentEmojis: [],
			searchQuery: "7",
			onKey: { _ in }
		)
		assertKeyboardSnapshot(view, size: Self.emojiSearchSize, colorScheme: .dark)
	}
}
