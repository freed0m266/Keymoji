//
//  Color+Extensions.swift
//  KeymojiUI
//
//  Created by Martin Svoboda on 03.06.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//
// https://blog.eidinger.info/from-hex-to-color-and-back-in-swiftui

import SwiftUI

public extension Color {
	init(hexString: String) {
		let hexSanitized = hexString
			.trimmingCharacters(in: .whitespacesAndNewlines)
			.replacingOccurrences(of: "#", with: "")
			.lowercased()

		var rgb: UInt64 = 0

		var r: CGFloat = 0.0
		var g: CGFloat = 0.0
		var b: CGFloat = 0.0
		let a: CGFloat = 1.0

		let length = hexSanitized.count

		guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
			self = .clear
			return
		}

		if length == 6 {
			r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
			g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
			b = CGFloat(rgb & 0x0000FF) / 255.0
		} else {
			self = .clear
		}

		self.init(red: r, green: g, blue: b, opacity: a)
	}
}
