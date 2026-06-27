//
//  View+Extensions.swift
//  KeymojiUI
//
//  Created by Martin Svoboda on 26.04.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import SwiftUI

extension View {
	func tappable<S>(_ shape: S = .rect) -> some View where S: Shape {
		self
			.contentShape(shape)
			.background(Color.black.opacity(0.001))
	}
}

public extension View {
	func mainBackground() -> some View {
		self
			.scrollContentBackground(.hidden)
			.background {
				MeshGradient(
					width: 2,
					height: 2,
					points: [
						[0.0, 0.0], [0.5, 0.0], [1.0, 0.0], [0.0, 1.0]
					],
					colors: [
						Color(hexString: "060913"),
						Color(hexString: "111A3A"),
						Color(hexString: "3A145F"),
						Color(hexString: "090B10")
					]
				)
				.opacity(0.8)
				.blur(radius: 100)
				.ignoresSafeArea()
			}
	}

	func aboutBackground() -> some View {
		self
			.scrollContentBackground(.hidden)
			.background {
				MeshGradient(
					width: 2,
					height: 2,
					points: [
						[0.6, 0.0], [0.5, 0.0], [1.0, 0.0], [0.0, 1.0]
					],
					colors: [
						.indigo
					],
				)
				.opacity(0.8)
				.blur(radius: 100)
				.ignoresSafeArea()
			}
	}
}

public extension View {
	/// When app did enter foreground
	func onForeground(action: @escaping () -> Void) -> some View {
		onReceive(
			NotificationCenter.default.publisher(
				for: UIApplication.didBecomeActiveNotification
			),
			perform: { _ in action() }
		)
	}
}
