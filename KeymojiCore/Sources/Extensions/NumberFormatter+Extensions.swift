//
//  NumberFormatter+Extensions.swift
//  KeymojiCore
//
//  Created by Martin Svoboda on 26.04.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import Foundation

extension NumberFormatter {
	static let decimal = {
		let formatter = NumberFormatter()
		formatter.locale = .autoupdatingCurrent
		formatter.numberStyle = .decimal
		return formatter
	}()
}
