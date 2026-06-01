import SwiftUI
import KeyboardCore

/// One horizontal row of keys. Distributes width proportionally to each key's `visualWeight`.
struct KeyRowView: View {
	let row: KeyboardRow
	let page: KeyboardPage
	let returnKeyType: ReturnKeyType
	let totalWidth: CGFloat
	let onKey: (Key) -> Void
	let onKeyTapHaptic: () -> Void
	let onKeyClick: (ClickSoundKind) -> Void
	let onPopoverEntry: () -> Void
	let onHighlightChanged: () -> Void
	let canEscalateBackspace: (() -> Bool)?
	let onTrackpadModeChanged: (Bool) -> Void

	private let spacing: CGFloat = 6

	var body: some View {
		HStack(spacing: spacing) {
			if insetWidth > 0 { Spacer().frame(width: insetWidth) }
			ForEach(Array(row.keys.enumerated()), id: \.element.id) { index, key in
				let keyWidth = width(for: key)
				KeyView(
					key: key,
					style: KeyStyle.style(for: key, page: page),
					returnKeyType: returnKeyType,
					keyWidth: keyWidth,
					popoverAlignment: popoverAlignment(forKeyAt: index, keyWidth: keyWidth),
					onTap: onKey,
					onKeyTapHaptic: onKeyTapHaptic,
					onKeyClick: onKeyClick,
					onPopoverEntry: onPopoverEntry,
					onHighlightChanged: onHighlightChanged,
					canEscalateBackspace: canEscalateBackspace,
					onTrackpadModeChanged: onTrackpadModeChanged
				)
				.frame(width: keyWidth)
			}
			if insetWidth > 0 { Spacer().frame(width: insetWidth) }
		}
	}

	private var actualTotalWeight: Double {
		row.keys.reduce(0) { $0 + $1.visualWeight.value }
	}

	/// Symmetric per-side inset for rows that declare a `referenceWeight` higher than their
	/// summed key weights. Keeps per-key width equal to a fuller row's per-key width.
	private var insetWidth: CGFloat {
		guard let ref = row.referenceWeight, ref > actualTotalWeight else { return 0 }
		let totalSpacing = spacing * CGFloat(max(0, row.keys.count - 1))
		let effectiveAvailable = max(0, totalWidth - totalSpacing)
		let unitWidth = effectiveAvailable / CGFloat(ref)
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

	private func width(for key: Key) -> CGFloat {
		guard !row.keys.isEmpty, actualTotalWeight > 0 else { return 0 }
		let totalSpacing = spacing * CGFloat(max(0, row.keys.count - 1))
		let available = max(0, totalWidth - totalSpacing - insetWidth * 2)
		return available * CGFloat(key.visualWeight.value / actualTotalWeight)
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
