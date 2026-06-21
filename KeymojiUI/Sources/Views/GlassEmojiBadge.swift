//
//  GlassEmojiBadge.swift
//  KeymojiUI
//
//  Created by Martin Svoboda on 20.06.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import SwiftUI

public struct GlassEmojiBadge: View {
	let emoji: String

	public init(_ emoji: String) {
		self.emoji = emoji
	}

	public var body: some View {
		Text(emoji)
			.font(.system(size: 52))
			.frame(width: 94, height: 94)
			.glassEffect()
	}
}

#if DEBUG
#Preview {
	VStack(spacing: 32) {
		GlassEmojiBadge("⭐️")
		GlassEmojiBadge("✨")
	}
	.padding()
}
#endif
