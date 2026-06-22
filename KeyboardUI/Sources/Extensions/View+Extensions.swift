//
//  View+Extensions.swift
//  About
//
//  Created by Martin Svoboda on 21.06.2026.
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

extension View {
	func searchFieldChrome() -> some View {
		self
			.padding(.horizontal, 10)
			.frame(height: 32)
			.background {
				RoundedRectangle(cornerRadius: 8, style: .continuous)
					.fill(Color(.systemGray3).opacity(0.45))
			}
	}
}
