//
//  Icon.swift
//  KeymojiUI
//
//  Created by Martin Svoboda on 26.04.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import SwiftUI

public struct Icon: View {
	private let name: String

	public var body: some View {
		image
	}
}

private extension Icon {
	var image: Image { .init(systemName: name) }
}

extension Icon: ExpressibleByStringLiteral {
	nonisolated public init(stringLiteral value: StaticString) {
		self.name = "\(value)"
	}
}

public extension Icon {
	func size(_ size: CGFloat, weight: Font.Weight? = nil) -> some View {
		image
			.resizable()
			.scaledToFit()
			.frame(width: size, height: size)
	}
}

public extension Icon {
	/// chevron.right
	static var chevronRight: Icon = "chevron.right"
	/// globe
	static var globe: Icon = "globe"
	/// keyboard.badge.eye
	static var keyboardBadgeEye: Icon = "keyboard.badge.eye"
	/// lock.shield
	static var lockShield: Icon = "lock.shield"
}

#Preview {
	VStack(spacing: 40) {
		Icon.chevronRight
			.size(24)

		Icon.globe
			.size(24)

		Icon.keyboardBadgeEye
			.size(24)

		Icon.lockShield
			.size(24)
	}
	.frame(maxWidth: 300, maxHeight: 300)
	.padding(16)
}
