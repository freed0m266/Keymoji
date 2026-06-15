//
//  PrimaryButton.swift
//  About
//
//  Created by Martin Svoboda on 09.06.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import SwiftUI

public struct PrimaryButton: View {
	@Environment(\.isEnabled) private var isEnabled

	let title: String
	let isLoading: Bool
	let action: () -> Void

	public init(
		_ title: String,
		isLoading: Bool = false,
		isDisabled: Bool = false,
		action: @escaping () -> Void
	) {
		self.title = title
		self.isLoading = isLoading
		self.action = action
	}

	public var body: some View {
		Button(action: action) {
			Group {
				if isLoading {
					ProgressView()
				} else {
					Text(title)
						.font(.title3.bold())
				}
			}
			.frame(maxWidth: .infinity)
			.padding(.vertical, 10)
		}
		.buttonStyle(.glassProminent)
		.tint(.accentColor)
		.disabled(!isEnabled || isLoading)
	}
}

#if DEBUG
#Preview {
	VStack(spacing: 16) {
		PrimaryButton("Continue") {}

		PrimaryButton("Purchase", isLoading: true) {}

		PrimaryButton("Disabled", isDisabled: true) {}
	}
	.padding()
}
#endif
