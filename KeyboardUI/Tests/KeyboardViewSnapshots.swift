import XCTest
import SwiftUI
@testable import KeyboardUI
import KeymojiCore
import KeyboardCore

@MainActor 
final class KeyboardViewSnapshots: XCTestCase {

	private static let iPhoneWidth: CGFloat = 393
	/// iPhone landscape width (e.g. iPhone 14/15 on its side). In landscape the number row is always
	/// dropped (`KeyboardState.effectiveShowsNumberRow` → false), so the layout is built without it.
	private static let iPhoneLandscapeWidth: CGFloat = 852

	/// Snapshot canvas sized to the keyboard's *intrinsic* height, derived from `KeyboardMetrics` —
	/// the same formula `KeyboardView` and `KeyboardViewController` use. Keeps the test frame in lock-step
	/// with the constant-height model (task 52 / task 61) so no hardcoded height can drift from the real
	/// keyboard. Height is independent of whether the suggestion bar is shown — the top region is always
	/// reserved — so there's no `showsSuggestionBar` term here anymore.
	private func keyboardSize(
		for layout: KeyboardLayout,
		width: CGFloat = iPhoneWidth
	) -> CGSize {
		CGSize(
			width: width,
			height: KeyboardMetrics.keyboardHeight(for: layout)
		)
	}

	// MARK: - Letters lower

	func testLettersLower_withNumberRow() {
		let layout = KeyboardCore.makeLayout(page: .letters(.lower), showNumberRow: true, returnKeyType: .default)
		let view = KeyboardView(layout: layout, width: Self.iPhoneWidth, onKey: { _ in })

		assertKeyboardSnapshot(view, size: keyboardSize(for: layout), colorScheme: .dark)
		assertKeyboardSnapshot(view, size: keyboardSize(for: layout), colorScheme: .light)
	}

	// MARK: - Letters upper / caps lock

	func testLettersUpper_withNumberRow() {
		let layout = KeyboardCore.makeLayout(page: .letters(.upper), showNumberRow: true, returnKeyType: .default)
		let view = KeyboardView(layout: layout, width: Self.iPhoneWidth, onKey: { _ in })

		assertKeyboardSnapshot(view, size: keyboardSize(for: layout), colorScheme: .dark)
		assertKeyboardSnapshot(view, size: keyboardSize(for: layout), colorScheme: .light)
	}

	func testLettersCapsLock_withNumberRow() {
		let layout = KeyboardCore.makeLayout(page: .letters(.capsLock), showNumberRow: true, returnKeyType: .default)
		let view = KeyboardView(layout: layout, width: Self.iPhoneWidth, onKey: { _ in })

		assertKeyboardSnapshot(view, size: keyboardSize(for: layout), colorScheme: .dark)
		assertKeyboardSnapshot(view, size: keyboardSize(for: layout), colorScheme: .light)
	}

	// MARK: - QWERTZ letter layout

	func testLettersLower_qwertz_withNumberRow() {
		let layout = KeyboardCore.makeLayout(page: .letters(.lower), showNumberRow: true, returnKeyType: .default, letterLayout: .qwertz)
		let view = KeyboardView(layout: layout, width: Self.iPhoneWidth, onKey: { _ in })

		assertKeyboardSnapshot(view, size: keyboardSize(for: layout), colorScheme: .dark)
	}

	// MARK: - Symbols

	func testSymbolsPrimary_withNumberRow() {
		let layout = KeyboardCore.makeLayout(page: .symbols(.primary), showNumberRow: true, returnKeyType: .default)
		let view = KeyboardView(layout: layout, width: Self.iPhoneWidth, onKey: { _ in })

		assertKeyboardSnapshot(view, size: keyboardSize(for: layout), colorScheme: .dark)
		assertKeyboardSnapshot(view, size: keyboardSize(for: layout), colorScheme: .light)
	}

	func testSymbolsAlternate_withNumberRow() {
		let layout = KeyboardCore.makeLayout(page: .symbols(.alternate), showNumberRow: true, returnKeyType: .default)
		let view = KeyboardView(layout: layout, width: Self.iPhoneWidth, onKey: { _ in })

		assertKeyboardSnapshot(view, size: keyboardSize(for: layout), colorScheme: .dark)
		assertKeyboardSnapshot(view, size: keyboardSize(for: layout), colorScheme: .light)
	}

	func testSymbolsPrimary_withoutNumberRow() {
		let layout = KeyboardCore.makeLayout(page: .symbols(.primary), showNumberRow: false, returnKeyType: .default)
		let view = KeyboardView(layout: layout, width: Self.iPhoneWidth, onKey: { _ in })

		assertKeyboardSnapshot(view, size: keyboardSize(for: layout), colorScheme: .dark)
	}

	func testSymbolsPrimary_withSuggestionBar() {
		// Task 56: the suggestion bar occupies the top region on the symbol page too (everywhere except
		// emoji / emoji-search). Word/Slack suggestions are letter-page only, so the bar falls back to
		// favorites here. Task 61: the region is reserved regardless, so the canvas is the same canonical
		// height as the empty-region symbols snapshot — only the region's *content* differs.
		let layout = KeyboardCore.makeLayout(page: .symbols(.primary), showNumberRow: true, returnKeyType: .default)
		let view = KeyboardView(
			layout: layout,
			width: Self.iPhoneWidth,
			favoriteEmojis: ["❤️", "🚀", "🍕", "🐶"],
			suggestions: [],
			onKey: { _ in }
		)
		let size = keyboardSize(for: layout)
		assertKeyboardSnapshot(view, size: size, colorScheme: .dark)
		assertKeyboardSnapshot(view, size: size, colorScheme: .light)
	}

	// MARK: - Without number row

	func testLettersLower_withoutNumberRow() {
		let layout = KeyboardCore.makeLayout(page: .letters(.lower), showNumberRow: false, returnKeyType: .default)
		let view = KeyboardView(layout: layout, width: Self.iPhoneWidth, onKey: { _ in })

		assertKeyboardSnapshot(view, size: keyboardSize(for: layout), colorScheme: .dark)
		assertKeyboardSnapshot(view, size: keyboardSize(for: layout), colorScheme: .light)
	}

	// MARK: - Landscape (number row dropped)

	func testLettersLower_landscape_noNumberRow() {
		// Landscape: `effectiveShowsNumberRow` is false even though the user's preference is on, so the
		// digit row is absent and the keyboard is shorter. Built at landscape width with the effective
		// (false) value the controller would pass.
		let layout = KeyboardCore.makeLayout(page: .letters(.lower), showNumberRow: false, returnKeyType: .default)
		let view = KeyboardView(layout: layout, width: Self.iPhoneLandscapeWidth, onKey: { _ in })

		let size = keyboardSize(for: layout, width: Self.iPhoneLandscapeWidth)
		assertKeyboardSnapshot(view, size: size, colorScheme: .dark)
		assertKeyboardSnapshot(view, size: size, colorScheme: .light)
	}

	// MARK: - Adaptive return labels

	func testReturnLabel_search() {
		let layout = KeyboardCore.makeLayout(page: .letters(.lower), showNumberRow: true, returnKeyType: .search)
		assertKeyboardSnapshot(KeyboardView(layout: layout, width: Self.iPhoneWidth, onKey: { _ in }), size: keyboardSize(for: layout), colorScheme: .dark)
	}

	func testReturnLabel_go() {
		let layout = KeyboardCore.makeLayout(page: .letters(.lower), showNumberRow: true, returnKeyType: .go)
		assertKeyboardSnapshot(KeyboardView(layout: layout, width: Self.iPhoneWidth, onKey: { _ in }), size: keyboardSize(for: layout), colorScheme: .dark)
	}

	func testReturnLabel_done() {
		let layout = KeyboardCore.makeLayout(page: .letters(.lower), showNumberRow: true, returnKeyType: .done)
		assertKeyboardSnapshot(KeyboardView(layout: layout, width: Self.iPhoneWidth, onKey: { _ in }), size: keyboardSize(for: layout), colorScheme: .dark)
	}

	func testReturnLabel_send() {
		let layout = KeyboardCore.makeLayout(page: .letters(.lower), showNumberRow: true, returnKeyType: .send)
		assertKeyboardSnapshot(KeyboardView(layout: layout, width: Self.iPhoneWidth, onKey: { _ in }), size: keyboardSize(for: layout), colorScheme: .dark)
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
		assertKeyboardSnapshot(view, size: keyboardSize(for: layout), colorScheme: .dark)
		assertKeyboardSnapshot(view, size: keyboardSize(for: layout), colorScheme: .light)
	}

	func testEmojis_withRecents_withNumberRow() {
		let layout = KeyboardCore.makeLayout(page: .emojis, showNumberRow: true, returnKeyType: .default)
		let view = KeyboardView(
			layout: layout,
			width: Self.iPhoneWidth,
			recentEmojis: ["😀", "👋", "🎉", "❤️", "🚀", "🍕", "🐶", "🌈"],
			onKey: { _ in }
		)
		assertKeyboardSnapshot(view, size: keyboardSize(for: layout), colorScheme: .dark)
		assertKeyboardSnapshot(view, size: keyboardSize(for: layout), colorScheme: .light)
	}

	// MARK: - Suggestion bar (task 40)

	func testSuggestionBar_wordChips_withNumberRow() {
		// Word chips render in the reserved top region above the number row (A2 — no mutex). Task 61: the
		// region is always reserved, so the canvas is the canonical height — the chips fill it, not grow it.
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
			onKey: { _ in }
		)
		let size = keyboardSize(for: layout)
		assertKeyboardSnapshot(view, size: size, colorScheme: .dark)
		assertKeyboardSnapshot(view, size: size, colorScheme: .light)
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
			onKey: { _ in }
		)
		assertKeyboardSnapshot(view, size: keyboardSize(for: layout), colorScheme: .dark)
	}

	func testSuggestionBar_emptyFavorites_showsDefaultStarterSet() {
		// With no suggestions *and* no user favorites, the bar falls back to `EmojiCatalog.defaultFavorites`
		// (D — bar is never empty; mirrors onboarding's "never empty" guarantee, task 62). The truly-silent
		// no-suggestions-no-favorites branch is covered at the component level by
		// `SuggestionBarViewSnapshots.testEmptyBar_alwaysShown`.
		let layout = KeyboardCore.makeLayout(page: .letters(.lower), showNumberRow: true, returnKeyType: .default)
		let view = KeyboardView(
			layout: layout,
			width: Self.iPhoneWidth,
			favoriteEmojis: [],
			suggestions: [],
			onKey: { _ in }
		)
		assertKeyboardSnapshot(view, size: keyboardSize(for: layout), colorScheme: .dark)
	}

	func testSecureField_topRegionReservedButEmpty() {
		// Secure (password) fields pass `fieldAllowsBar: false`, so the bar — favorites and suggestions
		// alike — is hidden, but the top region keeps its reserved height (task 61) so the keyboard doesn't
		// jump when focus moves between secure and normal fields.
		let layout = KeyboardCore.makeLayout(page: .letters(.lower), showNumberRow: true, returnKeyType: .default)
		let view = KeyboardView(
			layout: layout,
			width: Self.iPhoneWidth,
			favoriteEmojis: ["❤️", "🚀", "🍕", "🐶"],
			suggestions: [],
			fieldAllowsBar: false,
			onKey: { _ in }
		)
		assertKeyboardSnapshot(view, size: keyboardSize(for: layout), colorScheme: .dark)
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
		assertKeyboardSnapshot(view, size: keyboardSize(for: layout), colorScheme: .dark)
		assertKeyboardSnapshot(view, size: keyboardSize(for: layout), colorScheme: .light)
	}

	// MARK: - Emoji search page

	/// Search mode stacks the search bar + horizontal results bar above the regular QWERTY rows. The
	/// keyboard's intrinsic height (number row dropped + chrome added) is derived from `KeyboardMetrics`,
	/// so the canvas grows to match and the bottom space/return row isn't clipped.

	func testEmojiSearch_emptyQuery_noRecents() {
		let layout = KeyboardCore.makeLayout(page: .emojiSearch, showNumberRow: true, returnKeyType: .default)
		let view = KeyboardView(
			layout: layout,
			width: Self.iPhoneWidth,
			recentEmojis: [],
			searchQuery: "",
			onKey: { _ in }
		)
		assertKeyboardSnapshot(view, size: keyboardSize(for: layout), colorScheme: .dark)
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
		assertKeyboardSnapshot(view, size: keyboardSize(for: layout), colorScheme: .dark)
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
		assertKeyboardSnapshot(view, size: keyboardSize(for: layout), colorScheme: .dark)
		assertKeyboardSnapshot(view, size: keyboardSize(for: layout), colorScheme: .light)
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
		assertKeyboardSnapshot(view, size: keyboardSize(for: layout), colorScheme: .dark)
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
		assertKeyboardSnapshot(view, size: keyboardSize(for: layout), colorScheme: .dark)
	}

	// MARK: - Numeric numpad (task 59)

	func testNumericInteger_numpad() {
		// Forced numpad for a `.numberPad` field. No number row and no suggestion bar — numeric fields
		// are `.denied`, so `fieldAllowsBar` is false and the reserved top region stays empty. `0` sits
		// centered in the middle column with an empty bottom-left third; delete hugs the right.
		let layout = KeyboardCore.makeLayout(page: .numeric(.integer), showNumberRow: false, returnKeyType: .default)
		let view = KeyboardView(layout: layout, width: Self.iPhoneWidth, fieldAllowsBar: false, onKey: { _ in })

		assertKeyboardSnapshot(view, size: keyboardSize(for: layout), colorScheme: .dark)
		assertKeyboardSnapshot(view, size: keyboardSize(for: layout), colorScheme: .light)
	}

	func testNumericDecimal_numpad() {
		// Forced numpad for a `.decimalPad` field. Same grid as the integer pad, but the bottom-left slot
		// holds the locale decimal separator (here the `.` default).
		let layout = KeyboardCore.makeLayout(page: .numeric(.decimal), showNumberRow: false, returnKeyType: .default, decimalSeparator: ".")
		let view = KeyboardView(layout: layout, width: Self.iPhoneWidth, fieldAllowsBar: false, onKey: { _ in })

		assertKeyboardSnapshot(view, size: keyboardSize(for: layout), colorScheme: .dark)
		assertKeyboardSnapshot(view, size: keyboardSize(for: layout), colorScheme: .light)
	}
}
