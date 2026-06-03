//
//  FeatureHighlight.swift
//  Onboarding
//
//  Created by Martin Svoboda on 28.05.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import Foundation
import KeymojiResources

/// One item shown in the post-activation feature tour.
public struct FeatureHighlight: Sendable, Hashable, Identifiable {
	public let id: String
	public let symbol: String
	public let title: String
	public let description: String

	public init(id: String, symbol: String, title: String, description: String) {
		self.id = id
		self.symbol = symbol
		self.title = title
		self.description = description
	}
}

public extension FeatureHighlight {
	typealias Texts = L10n.Onboarding.Tour

	/// Curated, ordered list of non-obvious user-facing capabilities the tour shows.
	/// Limited to ~7 items by design — see task 38, scope §1.
	static let all: [FeatureHighlight] = [
		FeatureHighlight(
			id: "diacritics",
			symbol: "character.cursor.ibeam",
			title: Texts.Diacritics.title,
			description: Texts.Diacritics.description
		),
		// Placed second so the privacy angle ("learns on this iPhone") is visible early (task 40).
		FeatureHighlight(
			id: "suggestions",
			symbol: "text.cursor",
			title: Texts.Suggestions.title,
			description: Texts.Suggestions.description
		),
		FeatureHighlight(
			id: "slack",
			symbol: "face.smiling",
			title: Texts.Slack.title,
			description: Texts.Slack.description
		),
		FeatureHighlight(
			id: "favorites",
			symbol: "heart.fill",
			title: Texts.Favorites.title,
			description: Texts.Favorites.description
		),
		FeatureHighlight(
			id: "emojiCodes",
			symbol: "list.bullet.rectangle",
			title: Texts.EmojiCodes.title,
			description: Texts.EmojiCodes.description
		),
		FeatureHighlight(
			id: "trackpad",
			symbol: "rectangle.and.hand.point.up.left",
			title: Texts.Trackpad.title,
			description: Texts.Trackpad.description
		),
		FeatureHighlight(
			id: "deleteWord",
			symbol: "delete.left",
			title: Texts.DeleteWord.title,
			description: Texts.DeleteWord.description
		)
		// `customize` was dropped to keep the tour at 7 items (task 38 cap) when `suggestions` was
		// added (task 40). It was the most self-discoverable entry — Settings toggles, unlike the
		// other tour items, are easy to stumble on — so it was the least valuable in a tour of
		// non-obvious features. Its `Onboarding.Tour.Customize.*` strings are left in place.
	]
}
