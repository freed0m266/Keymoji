import SwiftUI
import KeyboardCore

/// One horizontal row of keys. Distributes width proportionally to each key's `visualWeight`.
struct KeyRowView: View {
	let row: KeyboardRow
	let page: KeyboardPage
	let returnKeyType: ReturnKeyType
	let totalWidth: CGFloat
	let onKey: (Key) -> Void
	let onPopoverEntry: () -> Void
	let onHighlightChanged: () -> Void

	private let spacing: CGFloat = 4

	var body: some View {
		HStack(spacing: spacing) {
			ForEach(Array(row.keys.enumerated()), id: \.element.id) { index, key in
				let keyWidth = width(for: key)
				KeyView(
					key: key,
					style: KeyStyle.style(for: key, page: page),
					returnKeyType: returnKeyType,
					keyWidth: keyWidth,
					popoverAlignment: popoverAlignment(forKeyAt: index, keyWidth: keyWidth),
					onTap: onKey,
					onPopoverEntry: onPopoverEntry,
					onHighlightChanged: onHighlightChanged
				)
				.frame(width: keyWidth)
			}
		}
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
			leadingX += width(for: row.keys[i]) + spacing
		}
		let keyMidX = leadingX + keyWidth / 2

		// Popover width estimate — must match LongPressPopoverView geometry: cell pitch + horizontal padding.
		let cellPitch: CGFloat = 42
		let popoverWidth = CGFloat(key.alternates.count) * cellPitch + 8
		let halfPopover = popoverWidth / 2

		if keyMidX - halfPopover < 0 { return .leading }
		if keyMidX + halfPopover > totalWidth { return .trailing }
		return .center
	}

	private var totalWeight: Double {
		row.keys.reduce(0) { $0 + $1.visualWeight.value }
	}

	private func width(for key: Key) -> CGFloat {
		let keyCount = Double(row.keys.count)
		guard keyCount > 0, totalWeight > 0 else { return 0 }
		let totalSpacing = spacing * CGFloat(max(0, keyCount - 1))
		let available = max(0, totalWidth - totalSpacing)
		return available * CGFloat(key.visualWeight.value / totalWeight)
	}
}
