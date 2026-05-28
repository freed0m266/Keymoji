//
//  KeyboardSurfaceColors.swift
//  KeyboardUI
//
//  Created by Martin Svoboda on 27.05.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import SwiftUI

/// Per-mode color palette for the keyboard surface and key tiers. Values are tuned by eye against
/// Apple's stock keyboard in both dark and light mode — Apple's exact tints live in private
/// `_UIKBColor*` symbols we can't ship against, so these public-API approximations match within
/// a few percent RGB. Each color uses a `UIColor` dynamic provider so traits resolve at render
/// time (light/dark switch updates without re-instantiation).
enum KeyboardSurfaceColors {

	// MARK: - Character tier (lightest in dark mode, white in light)

	static let characterBackground = UIColor { traits in
		traits.userInterfaceStyle == .dark
			? UIColor(white: 0.4, alpha: 0.5)
			: UIColor.white
	}

	static let characterPressed = UIColor { traits in
		traits.userInterfaceStyle == .dark
			? UIColor(white: 0.56, alpha: 1.0)
			: UIColor(white: 0.84, alpha: 1.0)
	}

	// MARK: - Function tier (space, return, page switch, dismiss) — darkest

	static let functionBackground = UIColor { traits in
		traits.userInterfaceStyle == .dark
			? UIColor(white: 0.22, alpha: 1.0)
			: UIColor(white: 0.61, alpha: 1.0)
	}

	static let functionPressed = UIColor { traits in
		traits.userInterfaceStyle == .dark
			? UIColor(white: 0.38, alpha: 1.0)
			: UIColor(white: 0.78, alpha: 1.0)
	}
}
