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
			.font(.system(size: size, weight: weight))
	}
}

public extension Icon {
	/// checkmark.circle.fill
	static var checkmarkCircleFill: Icon = "checkmark.circle.fill"
	/// circle
	static var circle: Icon = "circle"
	/// xmark.circle.fill
	static var xmarkCircleFill: Icon = "xmark.circle.fill"
}

#Preview {
	VStack(spacing: 40) {
		Icon.checkmarkCircleFill
			.size(24)
			.foregroundColor(.green)

		Icon.xmarkCircleFill
			.size(24)
			.foregroundColor(.red)
	}
	.frame(maxWidth: 300, maxHeight: 300)
	.padding(16)
}
