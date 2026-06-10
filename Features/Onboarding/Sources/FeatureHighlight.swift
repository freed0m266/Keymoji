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
public struct FeatureHighlight: Identifiable, Sendable {
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
	static let all: [FeatureHighlight] = [
		FeatureHighlight(
			id: "favorites",
			symbol: "heart.fill",
			title: Texts.Favorites.title,
			description: Texts.Favorites.description
		),
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
			id: "diacritics",
			symbol: "character.cursor.ibeam",
			title: Texts.Diacritics.title,
			description: Texts.Diacritics.description
		)
	]
}
