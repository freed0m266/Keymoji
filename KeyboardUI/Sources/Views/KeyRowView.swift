import SwiftUI
import KeyboardCore

/// One horizontal row of keys. Distributes width proportionally to each key's `visualWeight`.
struct KeyRowView: View {
	let row: KeyboardRow
	let page: KeyboardPage
	let returnKeyType: ReturnKeyType
	let totalWidth: CGFloat
	let onKey: (Key) -> Void

	private let spacing: CGFloat = 4

	var body: some View {
		HStack(spacing: spacing) {
			ForEach(row.keys) { key in
				KeyView(
					key: key,
					style: KeyStyle.style(for: key, page: page),
					returnKeyType: returnKeyType,
					onTap: onKey
				)
				.frame(width: width(for: key))
			}
		}
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
