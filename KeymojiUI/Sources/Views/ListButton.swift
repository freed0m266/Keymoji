//
//  ListButton.swift
//  KeymojiUI
//
//  Created by Martin Svoboda on 20.06.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import SwiftUI

public struct ListButton: View {
	let title: String
	let caption: String?
	let icon: Icon?
	let action: () -> Void

	public init(
		title: String,
		caption: String? = nil,
		icon: Icon? = nil,
		action: @escaping () -> Void
	) {
		self.title = title
		self.caption = caption
		self.icon = icon
		self.action = action
	}

	public var body: some View {
		Button(action: action) {
			HStack(spacing: 12) {
				icon?
					.size(26)
					.foregroundStyle(.tint)

				VStack(alignment: .leading, spacing: 2) {
					Text(title)
						.font(.body.weight(caption == nil ? .regular : .semibold))
						.foregroundStyle(.primary)
						.frame(maxWidth: .infinity, alignment: .leading)

					if let caption {
						Text(caption)
							.font(.footnote)
							.foregroundStyle(.secondary)
					}
				}

				Icon.chevronRight
					.font(.footnote.weight(.bold))
					.foregroundStyle(.tertiary)
			}
		}
	}
}

#if DEBUG
#Preview {
	List {
		ListButton(title: "Privacy Policy") { }
		ListButton(title: "Get Keymoji Plus") { }
		ListButton(
			title: "Unlock more favorites",
			caption: "You've added 6 of 6 free emojis.",
			icon: .starCircleFill
		) {}
		ListButton(
			title: "Keep your extras", 
			caption: "You loved Plus. Get it back.",
			icon: .starCircleFill
		) {}
	}
}
#endif
