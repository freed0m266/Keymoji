//
//  EmojiCodesViewModelMock.swift
//  EmojiCodes
//
//  Created by Martin Svoboda on 25.05.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

#if DEBUG
import Foundation

@Observable
@MainActor
public final class EmojiCodesViewModelMock: EmojiCodesViewModeling {

	public var searchQuery: String = "" {
		didSet { recompute() }
	}
	public private(set) var entries: [EmojiCodeEntry]
	public var copiedShortcode: String?
	public var copyCallCount = 0

	private let allEntries: [EmojiCodeEntry]

	public init(entries: [EmojiCodeEntry] = EmojiCodesViewModelMock.sampleEntries) {
		self.allEntries = entries
		self.entries = entries
	}

	public func copy(_ entry: EmojiCodeEntry) {
		copyCallCount += 1
		copiedShortcode = entry.shortcode
	}

	private func recompute() {
		let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
		guard !trimmed.isEmpty else {
			entries = allEntries
			return
		}
		entries = allEntries.filter { $0.shortcode.contains(trimmed) || $0.emoji.contains(trimmed) }
	}

	public static let sampleEntries: [EmojiCodeEntry] = [
		.init(shortcode: "100", emoji: "💯"),
		.init(shortcode: "fire", emoji: "🔥"),
		.init(shortcode: "heart", emoji: "❤️"),
		.init(shortcode: "joy", emoji: "😂"),
		.init(shortcode: "rocket", emoji: "🚀"),
		.init(shortcode: "smile", emoji: "😄"),
		.init(shortcode: "tada", emoji: "🎉"),
		.init(shortcode: "thumbsup", emoji: "👍")
	]
}
#endif
