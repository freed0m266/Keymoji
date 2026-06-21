//
//  EmojiSelectableCell.swift
//  KeymojiUI
//
//  Created by Martin Svoboda on 20.06.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import SwiftUI

/// A toggleable emoji cell: a selected background tint + a top-trailing checkmark badge, dimmed and
/// disabled when the selection cap is reached. Shared by the onboarding pick-favorites grid and the
/// full emoji catalog picker — identical apart from the glyph size, which is a parameter.
public struct EmojiSelectableCell: View {
	let glyph: String
	let isSelected: Bool
	let isDimmed: Bool
	let onTap: () -> Void

	public init(
		glyph: String,
		isSelected: Bool,
		isDimmed: Bool,
		onTap: @escaping () -> Void
	) {
		self.glyph = glyph
		self.isSelected = isSelected
		self.isDimmed = isDimmed
		self.onTap = onTap
	}

	public var body: some View {
		Button(action: onTap) {
			ZStack(alignment: .topTrailing) {
				Text(glyph)
					.font(.system(size: 30))
					.frame(maxWidth: .infinity)
					.frame(height: 52)
					.background(
						RoundedRectangle(cornerRadius: 8)
							.fill(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
					)

				if isSelected {
					Icon.checkmarkCircleFill
						.font(.system(size: 14))
						.foregroundStyle(Color.accentColor, Color(.systemBackground))
						.padding(2)
				}
			}
			.contentShape(.rect)
			.opacity(isDimmed ? 0.35 : 1)
		}
		.buttonStyle(.plain)
		.disabled(isDimmed)
		.accessibilityLabel(glyph)
		.accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
	}
}

#if DEBUG
#Preview {
	LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
		EmojiSelectableCell(glyph: "❤️", isSelected: true, isDimmed: false) {}
		EmojiSelectableCell(glyph: "🔥", isSelected: false, isDimmed: false) {}
		EmojiSelectableCell(glyph: "🎉", isSelected: false, isDimmed: true) {}
		EmojiSelectableCell(glyph: "🚀", isSelected: true, isDimmed: false) {}
	}
	.padding()
}
#endif
