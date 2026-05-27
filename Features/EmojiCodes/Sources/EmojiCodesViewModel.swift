//
//  EmojiCodesViewModel.swift
//  EmojiCodes
//
//  Created by Martin Svoboda on 25.05.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import Foundation
import UIKit
import KeyboCore
import KeyboardCore

public struct EmojiCodeEntry: Identifiable, Hashable, Sendable {
	public let shortcode: String
	public let emoji: String
	public var id: String { shortcode }

	public init(shortcode: String, emoji: String) {
		self.shortcode = shortcode
		self.emoji = emoji
	}

	public var wrappedShortcode: String { ":\(shortcode):" }
}

@MainActor
public protocol EmojiCodesViewModeling: Observable, AnyObject {
	var searchQuery: String { get set }
	var entries: [EmojiCodeEntry] { get }
	var copiedShortcode: String? { get }
	func copy(_ entry: EmojiCodeEntry)
}

@MainActor
public func emojiCodesVM() -> some EmojiCodesViewModeling {
	EmojiCodesViewModel()
}

@Observable
final class EmojiCodesViewModel: BaseViewModel, EmojiCodesViewModeling {

	var searchQuery: String = "" {
		didSet { recomputeEntries() }
	}

	private(set) var entries: [EmojiCodeEntry]
	private(set) var copiedShortcode: String?

	private let allEntries: [EmojiCodeEntry]
	private let pasteboard: PasteboardWriting
	private let toastDuration: TimeInterval
	private var toastTask: Task<Void, Never>?

	// MARK: - Init

	init(
		table: [String: String] = SlackEmojiTable.defaultTable,
		pasteboard: PasteboardWriting = SystemPasteboard(),
		toastDuration: TimeInterval = 1.6
	) {
		self.pasteboard = pasteboard
		self.toastDuration = toastDuration
		let sorted = table
			.map { EmojiCodeEntry(shortcode: $0.key, emoji: $0.value) }
			.sorted { $0.shortcode < $1.shortcode }
		self.allEntries = sorted
		self.entries = sorted
		super.init()
	}

	// MARK: - Public API

	func copy(_ entry: EmojiCodeEntry) {
		pasteboard.setString(entry.wrappedShortcode)
		UIImpactFeedbackGenerator(style: .light).impactOccurred()
		copiedShortcode = entry.shortcode
		toastTask?.cancel()
		toastTask = Task { [weak self, toastDuration] in
			try? await Task.sleep(nanoseconds: UInt64(toastDuration * 1_000_000_000))
			guard !Task.isCancelled, let self else { return }
			self.copiedShortcode = nil
		}
	}

	// MARK: - Private API

	private func recomputeEntries() {
		let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
		guard !trimmed.isEmpty else {
			entries = allEntries
			return
		}
		entries = allEntries.filter { entry in
			entry.shortcode.contains(trimmed) || entry.emoji.contains(trimmed)
		}
	}
}

public protocol PasteboardWriting: Sendable {
	func setString(_ string: String)
}

public struct SystemPasteboard: PasteboardWriting {
	public init() {}

	public func setString(_ string: String) {
		UIPasteboard.general.string = string
	}
}
