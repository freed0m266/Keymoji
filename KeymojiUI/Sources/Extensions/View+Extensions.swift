//
//  View+Extensions.swift
//  KeymojiUI
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
				LinearGradient(
					colors: [
						Color(hexString: "5F7EFF").opacity(0.4),
						Color(hexString: "5A39AD").opacity(0.2),
						Color.black,
						Color.black
					],
					startPoint: .top,
					endPoint: .bottom
				)
				.ignoresSafeArea()
			}
	}
}

public extension View {
	func tappable<S>(_ shape: S = .rect) -> some View where S : Shape {
		self
			.contentShape(shape)
			.background(Color.black.opacity(0.001))
	}
}
