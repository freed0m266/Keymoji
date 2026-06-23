import SwiftUI
import KeyboardCore

/// One horizontal row of keys. Distributes width proportionally to each key's `visualWeight`.
///
/// `Equatable` (task 73, Phase B): rendering is a pure function of `row`, `page`, `returnKeyType`,
/// `totalWidth`, and `isTrackpadActive` — the callbacks don't affect what's drawn. With `.equatable()`
/// applied at the call site, SwiftUI skips re-evaluating a row whose layout inputs are unchanged, so a
/// keystroke that only updates the suggestion bar never re-renders the key grid.
struct KeyRowView: View, Equatable {
	let row: KeyboardRow
	let page: KeyboardPage
	let returnKeyType: ReturnKeyType
	let totalWidth: CGFloat
	/// Keyboard-wide trackpad-on-space flag (task 75), forwarded down to every `KeyView` so the glyphs
	/// blank when the user scrubs the cursor. A render-determining input — see `==` below.
	let isTrackpadActive: Bool
	let onKey: (Key) -> Void
	let onKeyTapHaptic: () -> Void
	let onKeyClick: (ClickSoundKind) -> Void
	let onPopoverEntry: () -> Void
	let onHighlightChanged: () -> Void
	let canEscalateBackspace: (() -> Bool)?
	let onTrackpadModeChanged: (Bool) -> Void

	/// Compare only render-determining inputs; the closures are stable forwarders that don't change
	/// output (see `KeyboardViewModel`), so ignoring them is what lets unchanged rows short-circuit.
	/// `isTrackpadActive` *must* be compared (task 75) — omitting it lets the short-circuit skip the
	/// re-render that flips the keys to blank, so the trackpad would engage with no visual change.
	/// `nonisolated` because `Equatable.==` is a nonisolated requirement while `View` is main-actor
	/// isolated — and it only reads `Sendable` value-type fields, so there's no data-race risk.
	nonisolated static func == (lhs: KeyRowView, rhs: KeyRowView) -> Bool {
		lhs.row == rhs.row
			&& lhs.page == rhs.page
			&& lhs.returnKeyType == rhs.returnKeyType
			&& lhs.totalWidth == rhs.totalWidth
			&& lhs.isTrackpadActive == rhs.isTrackpadActive
	}

	var body: some View {
		HStack(spacing: 0) {
			if insetWidth > 0 { Spacer().frame(width: insetWidth) }
			ForEach(Array(row.keys.enumerated()), id: \.element.id) { index, key in
				let keyWidth = width(for: key)
				let leadingGap = unitWidth * CGFloat(key.leadingGapWeight)
				let trailingGap = unitWidth * CGFloat(key.trailingGapWeight)
				KeyView(
					key: key,
					style: KeyStyle.style(for: key, page: page),
					returnKeyType: returnKeyType,
					keyWidth: keyWidth,
					capHeight: capHeight,
					leadingGapWidth: leadingGap,
					trailingGapWidth: trailingGap,
					popoverAlignment: popoverAlignment(forKeyAt: index, keyWidth: keyWidth),
					isTrackpadActive: isTrackpadActive,
					onTap: onKey,
					onKeyTapHaptic: onKeyTapHaptic,
					onKeyClick: onKeyClick,
					onPopoverEntry: onPopoverEntry,
					onHighlightChanged: onHighlightChanged,
					canEscalateBackspace: canEscalateBackspace,
					onTrackpadModeChanged: onTrackpadModeChanged
				)
				// The key owns its edge gaps: its frame spans cap + gaps, so the gap area carries the
				// key's background and tap target instead of being a dead transparent strip.
				.frame(width: keyWidth + leadingGap + trailingGap)
			}
			if insetWidth > 0 { Spacer().frame(width: insetWidth) }
		}
	}

	/// Summed width budget for the row, including per-key edge gaps. Each gap consumes the same
	/// proportional share as a key of equal weight, so neighbors don't expand into it.
	private var actualTotalWeight: Double {
		row.keys.reduce(0) { $0 + $1.leadingGapWeight + $1.visualWeight.value + $1.trailingGapWeight }
	}

	/// Symmetric per-side inset for rows that declare a `referenceWeight` higher than their
	/// summed key weights. Keeps per-key width equal to a fuller row's per-key width.
	private var insetWidth: CGFloat {
		guard let ref = row.referenceWeight, ref > actualTotalWeight else { return 0 }
		let unitWidth = totalWidth / CGFloat(ref)
		let missingWeight = ref - actualTotalWeight
		return unitWidth * CGFloat(missingWeight) / 2.0
	}

	/// Anchor the popover so it never spills off-screen. We check whether the popover —
	/// centered on the key — would overflow either side of the row, and flip it to the
	/// nearer edge when it would. Width of the popover is derived from this key's
	/// alternate count, so longer popovers flip earlier than short ones.
	private func popoverAlignment(forKeyAt index: Int, keyWidth: CGFloat) -> HorizontalAlignment {
		let key = row.keys[index]
		guard !key.alternates.isEmpty else { return .center }

		var leadingX: CGFloat = 0
		for i in 0..<index {
			let k = row.keys[i]
			leadingX += unitWidth * CGFloat(k.leadingGapWeight + k.visualWeight.value + k.trailingGapWeight)
		}
		leadingX += unitWidth * CGFloat(row.keys[index].leadingGapWeight)
		let keyMidX = leadingX + keyWidth / 2

		// Popover width estimate — must match LongPressPopoverView geometry: cell pitch + horizontal padding.
		let cellPitch: CGFloat = 42
		let popoverWidth = CGFloat(key.alternates.count) * cellPitch + 8
		let halfPopover = popoverWidth / 2

		if keyMidX - halfPopover < 0 { return .leading }
		if keyMidX + halfPopover > totalWidth { return .trailing }
		return .center
	}

	/// Fixed visible cap height for every key in this row — the number row is a touch shorter than the
	/// letter / symbol / bottom rows. The row's total slot is `capHeight + rowGap` (the gap padding lives
	/// inside each `KeyView`).
	private var capHeight: CGFloat {
		row.isNumberRow ? KeyboardMetrics.numberRowCapHeight : KeyboardMetrics.keyCapHeight
	}

	/// Width of one weight unit after subtracting symmetric insets. Keys and gaps both bill against it.
	private var unitWidth: CGFloat {
		guard !row.keys.isEmpty, actualTotalWeight > 0 else { return 0 }
		let available = max(0, totalWidth - insetWidth * 2)
		return available / CGFloat(actualTotalWeight)
	}

	private func width(for key: Key) -> CGFloat {
		unitWidth * CGFloat(key.visualWeight.value)
	}
}

#if DEBUG
private struct KeyRowPreview: View {
	let row: KeyboardRow
	let page: KeyboardPage
	let returnKeyType: ReturnKeyType
	private let totalWidth: CGFloat = 387

	var body: some View {
		KeyRowView(
			row: row,
			page: page,
			returnKeyType: returnKeyType,
			totalWidth: totalWidth,
			isTrackpadActive: false,
			onKey: { _ in },
			onKeyTapHaptic: {},
			onKeyClick: { _ in },
			onPopoverEntry: {},
			onHighlightChanged: {},
			canEscalateBackspace: nil,
			onTrackpadModeChanged: { _ in }
		)
		.padding(.horizontal, 3)
		.padding(.vertical, 8)
		.frame(width: 393)
		.background(Color(.systemBackground))
	}
}

#Preview("Letters row 1 (qwertyuiop) / Dark") {
	let layout = KeyboardCore.makeLayout(page: .letters(.lower), showNumberRow: false, returnKeyType: .default)
	KeyRowPreview(row: layout.rows[0], page: layout.page, returnKeyType: layout.returnKeyType)
		.preferredColorScheme(.dark)
}

#Preview("Letters row 2 (asdfghjkl) / Dark") {
	let layout = KeyboardCore.makeLayout(page: .letters(.lower), showNumberRow: false, returnKeyType: .default)
	KeyRowPreview(row: layout.rows[1], page: layout.page, returnKeyType: layout.returnKeyType)
		.preferredColorScheme(.dark)
}

#Preview("Shift + letters + delete (upper) / Dark") {
	let layout = KeyboardCore.makeLayout(page: .letters(.upper), showNumberRow: false, returnKeyType: .default)
	KeyRowPreview(row: layout.rows[2], page: layout.page, returnKeyType: layout.returnKeyType)
		.preferredColorScheme(.dark)
}

#Preview("Bottom row (Return = Go) / Dark") {
	let layout = KeyboardCore.makeLayout(page: .letters(.lower), showNumberRow: false, returnKeyType: .go)
	KeyRowPreview(row: layout.rows[3], page: layout.page, returnKeyType: layout.returnKeyType)
		.preferredColorScheme(.dark)
}

#Preview("Symbols row A / Light") {
	let layout = KeyboardCore.makeLayout(page: .symbols(.primary), showNumberRow: false, returnKeyType: .default)
	KeyRowPreview(row: layout.rows[0], page: layout.page, returnKeyType: layout.returnKeyType)
		.preferredColorScheme(.light)
}
#endif
