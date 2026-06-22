import SwiftUI

struct EmojiCellButtonStyle: ButtonStyle {
	func makeBody(configuration: Configuration) -> some View {
		ZStack {
			RoundedRectangle(cornerRadius: 5)
				.fill(configuration.isPressed ? Color(.systemGray3) : Color.clear)

			configuration.label
		}
	}
}
