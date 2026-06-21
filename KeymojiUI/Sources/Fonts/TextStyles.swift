//
//  TextStyles.swift
//  KeymojiUI
//
//  Created by Martin Svoboda on 21.06.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import SwiftUI

public extension View {
	/// Centred hero title used atop onboarding steps and the paywall header.
	/// Excludes padding — the call site keeps its own (paddings differ between sites).
	func heroTitle() -> some View {
		font(.title2.weight(.bold))
			.multilineTextAlignment(.center)
	}

	/// Centred secondary hero body copy under a `heroTitle()`.
	func heroDescription() -> some View {
		font(.callout)
			.foregroundStyle(.secondary)
			.multilineTextAlignment(.center)
	}

	/// Centred tertiary hero footnote shown below a hero block's call to action.
	func heroFootnote() -> some View {
		font(.footnote)
			.foregroundStyle(.tertiary)
			.multilineTextAlignment(.center)
	}
}

#if DEBUG
#Preview {
	ScrollView {
		VStack(spacing: 16) {
			Text("heroTitle").heroTitle()
			Text("heroDescription").heroDescription()
			Text("heroFootnote").heroFootnote()

			Divider()
		}
	}
}
#endif
