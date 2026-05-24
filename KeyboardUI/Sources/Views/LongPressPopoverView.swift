import SwiftUI
import KeyboardCore

/// Bubble shown above a key during a long-press, listing the key's alternates.
/// Pure presentation — gesture state is owned by `KeyView`.
struct LongPressPopoverView: View {
	let alternates: [KeyContent]
	let highlightedIndex: Int
	let cellSize: CGSize

	var body: some View {
		HStack(spacing: 2) {
			ForEach(alternates.indices, id: \.self) { idx in
				cell(for: alternates[idx], isHighlighted: idx == highlightedIndex)
			}
		}
		.padding(4)
		.background(
			RoundedRectangle(cornerRadius: 8)
				.fill(Color(.systemGray5))
				.shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 2)
		)
		.fixedSize()
	}

	private func cell(for content: KeyContent, isHighlighted: Bool) -> some View {
		ZStack {
			RoundedRectangle(cornerRadius: 5)
				.fill(isHighlighted ? Color.accentColor : Color.clear)
			contentView(for: content)
				.font(.system(size: 22, weight: .regular))
				.foregroundStyle(isHighlighted ? Color.white : Color(.label))
		}
		.frame(width: cellSize.width, height: cellSize.height)
	}

	@ViewBuilder
	private func contentView(for content: KeyContent) -> some View {
		switch content {
		case .text(let text):
			Text(text)
		case .symbol(let symbol):
			Image(systemName: symbol.systemName)
		}
	}
}

#if DEBUG
#Preview("8 alternates / dark") {
	LongPressPopoverView(
		alternates: [
			.text("é"), .text("ě"), .text("è"), .text("ê"),
			.text("ë"), .text("ē"), .text("ė"), .text("ę")
		],
		highlightedIndex: 1,
		cellSize: CGSize(width: 40, height: 44)
	)
	.preferredColorScheme(.dark)
	.padding()
}
#endif
