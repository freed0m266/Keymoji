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

	/// Suggestion bar's own height (the chips/favorites strip). Internal detail of how the bar fills the
	/// `topRegion` — the bar (40) + `suggestionBarGap` (2) add up to `topRegionHeight`. Height of the
	/// keyboard no longer depends on whether the bar is shown (task 61); `topRegion` is reserved always.
	public static let suggestionBarHeight: CGFloat = 40
	/// Gap below the suggestion bar, above the first key row. Internal detail of the bar's fill (see above).
	public static let suggestionBarGap: CGFloat = 2   // 40 + 2 = topRegionHeight of 42

	/// Horizontal padding on the keyboard VStack (outside the emoji panel).
	public static let horizontalPadding: CGFloat = 3

	/// Floor for the emoji-search chrome (search field + horizontal results bar + intra-row gaps) stacked
	/// above the QWERTY rows. The chrome is otherwise *derived* (see `keyboardHeight`) so emoji-search
	/// matches the canonical height — but it can never shrink below this irreducible minimum.
	public static let emojiSearchMinChrome: CGFloat = 86   // 32 + 44 + 4 + 6 (today's breakdown)

	// MARK: - Derived

	/// Reserved height of the region above the keyboard rows (task 61). Today it hosts the
	/// `SuggestionBarView`, but the region is reserved on *every* page (letters, symbols, emoji,
	/// emoji-search) and at all times — independent of the suggestions toggle and field eligibility,
	/// which now gate only the region's *content* (bar vs empty), not its existence or height. Equal to
	/// the suggestion bar's old footprint (`suggestionBarHeight` 40 + `suggestionBarGap` 2 = 42).
	public static var topRegionHeight: CGFloat {
		suggestionBarHeight + suggestionBarGap
	}

	/// Slot height (cap + gap) for a row, picking the number-row cap when `isNumberRow`.
	public static func rowSlotHeight(isNumberRow: Bool) -> CGFloat {
		(isNumberRow ? numberRowCapHeight : keyCapHeight) + rowGap
	}

	/// The four standard rows every page is sized around: three letter/symbol body rows + the bottom row.
	/// The emoji page swaps the body rows for a panel and emoji-search stacks chrome above them, but both
	/// occupy this same vertical budget for the rows themselves.
	public static var qwertyRowsHeight: CGFloat {
		4 * rowSlotHeight(isNumberRow: false)
	}

	/// The single canonical keyboard height for a given number-row preference (task 61): the number row
	/// (when on) + the four standard rows + the reserved `topRegion`. Letters, symbols and emoji are
	/// *always* exactly this tall, and emoji-search too whenever the number row leaves it enough headroom
	/// (see `keyboardHeight`). Constant *across pages* so switching letters → symbols → emoji → search
	/// never makes the keyboard jump; it still varies with the number-row toggle and landscape, which is
	/// an explicit user/space trade-off intentionally outside the "constant" guarantee.
	public static func canonicalHeight(showsNumberRow: Bool) -> CGFloat {
		let numberRow = showsNumberRow ? rowSlotHeight(isNumberRow: true) : 0
		return numberRow + qwertyRowsHeight + topRegionHeight
	}

	/// Total host/input-view height for a built layout. SINGLE place that computes it — both the SwiftUI
	/// frame and the UIInputView height constraint call this, so they can't drift. The result no longer
	/// depends on whether the suggestion bar is shown (task 61): the `topRegion` is reserved
	/// unconditionally, so this takes no `showsSuggestionBar` flag and drift between the two callers is
	/// structurally impossible.
	///
	/// - **letters / symbols:** the page's own rows + the reserved `topRegion` = `canonicalHeight`.
	/// - **emoji:** `canonicalHeight` — the `EmojiPanelView` fills it; `layout.rows` carries only the
	///   bottom row, so we can't sum it and size from the number-row preference instead.
	/// - **emoji-search:** the QWERTY rows + derived chrome. The chrome normally expands so the page
	///   matches `canonicalHeight`, but never shrinks below `emojiSearchMinChrome`. So when the number row
	///   is off (user choice or landscape) and `canonicalHeight` is short, emoji-search is the one page
	///   allowed to stay taller — its search field + results bar are irreducible and bigger than the bar.
	public static func keyboardHeight(for layout: KeyboardLayout) -> CGFloat {
		let canonical = canonicalHeight(showsNumberRow: layout.showsNumberRow)
		if layout.page == .emojis {
			return canonical
		}
		let rows = layout.rows.reduce(0) { $0 + rowSlotHeight(isNumberRow: $1.isNumberRow) }
		if layout.page.isEmojiSearch {
			// `rows` here is the QWERTY rows only (the number row is dropped on search pages), so the
			// chrome fills whatever the canonical height leaves above them — floored at the minimum.
			let chrome = max(emojiSearchMinChrome, canonical - rows)
			return rows + chrome
		}
		return rows + topRegionHeight
	}
}
