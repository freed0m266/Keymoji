//
//  View+Extensions.swift
//  About
//
//  Created by Martin Svoboda on 21.06.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import SwiftUI

public extension View {
	func tappable<S>(_ shape: S = .rect) -> some View where S: Shape {
		self
			.contentShape(shape)
			.background(Color.black.opacity(0.001))
	}
}
