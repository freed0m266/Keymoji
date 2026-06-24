//
//  Locale+Extensions.swift
//  KeymojiCore
//
//  Created by Martin Svoboda on 24.06.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import Foundation

public extension Locale {
	static var preferredLanguageCode: String? {
		guard let preferredLanguage else { return nil }
		return Locale(identifier: preferredLanguage).language.languageCode?.identifier
	}

	static var preferredLanguage: String? {
		preferredLanguages.first
	}
}
