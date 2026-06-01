//
//  View+Extensions.swift
//  KeyboUI
//
//  Created by Martin Svoboda on 26.04.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import SwiftUI

public extension View {
	func mainBackground() -> some View {
		self
			.scrollContentBackground(.hidden)
			.background {
				RadialGradient(
					colors: [
						.blue.opacity(0.2),
						.clear
					],
					center: .topLeading,
					startRadius: 0,
					endRadius: 500
				)
				.ignoresSafeArea()

				RadialGradient(
					colors: [
						.orange.opacity(0.1),
						.clear
					],
					center: .trailing,
					startRadius: 0,
					endRadius: 400
				)
				.ignoresSafeArea()
			}
	}
}
