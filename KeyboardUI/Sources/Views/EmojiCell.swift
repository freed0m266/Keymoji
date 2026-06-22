import SwiftUI

struct EmojiCell: View {
	let emoji: String
	let width: CGFloat?
	let height: CGFloat
	let action: () -> Void

	var body: some View {
		Button(action: action) {
			glyph
				.contentShape(.rect)
		}
		.buttonStyle(EmojiCellButtonStyle())
		.accessibilityElement()
		.accessibilityLabel(emoji)
		.accessibilityAddTraits(.isKeyboardKey)
	}

	@ViewBuilder
	private var glyph: some View {
		let base = Text(emoji)
			.font(.system(size: 28))
			.minimumScaleFactor(0.8)
			.lineLimit(1)
		if let width {
			base.frame(width: width, height: height)
		} else {
			base.frame(maxWidth: .infinity).frame(height: height)
		}
	}
}
