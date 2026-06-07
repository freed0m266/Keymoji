import CoreGraphics

/// Single source of truth for keyboard key/row dimensions. Consumed by `KeyboardView` (SwiftUI render)
/// AND `KeyboardViewController` (host input-view height constraint) so the two never disagree — if they
/// computed height separately and drifted, the SwiftUI content would overflow and clip (the original
/// "missing search bar on `.emojiSearch`" bug).
///
/// Model is bottom-up: cap heights are fixed; total keyboard height is *derived* from them. Tune
/// `keyCapHeight` (and `numberRowCapHeight`) to resize keys — everything else follows.
public enum KeyboardMetrics {
	/// Visible cap height of a standard key (letters, symbols, bottom row). THE knob to tune key height.
	public static let keyCapHeight: CGFloat = 42
	/// Visible cap height of a number-row key — intentionally a touch shorter than `keyCapHeight`.
	public static let numberRowCapHeight: CGFloat = 36
	/// Vertical gap between rows. Applied as `rowGap/2` padding top+bottom inside each `KeyView`, so the
	/// gap stays inside the key's hit area (task 42). Row slot height = cap + rowGap.
	public static let rowGap: CGFloat = 12

	/// Suggestion bar's own height (the chips/favorites strip).
	public static let suggestionBarHeight: CGFloat = 40
	/// Gap below the suggestion bar, above the first key row.
	public static let suggestionBarGap: CGFloat = 2   // 40 + 2 = today's footprint of 42

	/// Horizontal padding on the keyboard VStack (outside the emoji panel).
	public static let horizontalPadding: CGFloat = 3

	/// Emoji-search chrome (search bar + results bar + intra-row gap) stacked above the QWERTY rows.
	public static let emojiSearchChromeHeight: CGFloat = 86   // 32 + 44 + 4 + 6 (today's breakdown)

	// MARK: - Derived

	/// Vertical footprint the suggestion bar adds when shown: the bar plus the gap above the keys below.
	public static var suggestionBarFootprint: CGFloat {
		suggestionBarHeight + suggestionBarGap
	}

	/// Slot height (cap + gap) for a row, picking the number-row cap when `isNumberRow`.
	public static func rowSlotHeight(isNumberRow: Bool) -> CGFloat {
		(isNumberRow ? numberRowCapHeight : keyCapHeight) + rowGap
	}

	/// Total host/input-view height for a built layout. SINGLE place that computes it — both the SwiftUI
	/// frame and the UIInputView height constraint call this, so they can't drift.
	///
	/// The emoji page is special-cased: it renders an `EmojiPanelView` in place of the letter/symbol
	/// rows, so `layout.rows` carries only the bottom row. To keep the panel the same size it has today,
	/// we size the emoji page like a letters page (three body rows + bottom, plus the number row when the
	/// user's preference is on) rather than summing its single real row.
	public static func keyboardHeight(for layout: KeyboardLayout, showsSuggestionBar: Bool) -> CGFloat {
		if layout.page == .emojis {
			return emojiPageHeight(showsNumberRow: layout.showsNumberRow)
		}
		let rows = layout.rows.reduce(0) { $0 + rowSlotHeight(isNumberRow: $1.isNumberRow) }
		let bar = showsSuggestionBar ? suggestionBarFootprint : 0
		let chrome = layout.page.isEmojiSearch ? emojiSearchChromeHeight : 0
		return rows + bar + chrome
	}

	/// Height of the emoji page: mirrors a letters page (3 body rows + bottom row, plus the number row
	/// when enabled) so the `EmojiPanelView` keeps today's footprint. The emoji page never shows the
	/// suggestion bar, so no bar term here.
	private static func emojiPageHeight(showsNumberRow: Bool) -> CGFloat {
		let bodyRowCount = 3
		let bodyRows = CGFloat(bodyRowCount) * rowSlotHeight(isNumberRow: false)
		let bottomRow = rowSlotHeight(isNumberRow: false)
		let numberRow = showsNumberRow ? rowSlotHeight(isNumberRow: true) : 0
		return numberRow + bodyRows + bottomRow
	}
}
