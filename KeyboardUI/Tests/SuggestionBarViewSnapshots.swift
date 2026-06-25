import XCTest
import SwiftUI
@testable import KeyboardUI
import KeyboardCore

/// Snapshots for the suggestion bar in isolation (40 pt tall). Covers both render styles, the
/// always-on empty state (C1), the sparse state (F2), and long-word overflow on a narrow device.
@MainActor
final class SuggestionBarViewSnapshots: XCTestCase {

	private static let iPhoneWidth: CGFloat = 393
	private static let iPhoneSEWidth: CGFloat = 320
	private static let barHeight: CGFloat = 40

	private func size(width: CGFloat = iPhoneWidth) -> CGSize {
		CGSize(width: width, height: Self.barHeight)
	}

	// MARK: - Plain word chips

	func testThreePlainChips() {
		let view = SuggestionBarView(
			suggestions: [
				.plainChip("hello", score: 0.9),
				.plainChip("help", score: 0.7),
				.plainChip("helicopter", score: 0.5)
			],
			totalWidth: 387,
			onSelect: { _ in }
		)
		assertKeyboardSnapshot(view, size: size(), colorScheme: .dark)
		assertKeyboardSnapshot(view, size: size(), colorScheme: .light)
	}

	func testSinglePlainChip_sparse() {
		// F2: fewer than three candidates → fewer chips, no empty padding.
		let view = SuggestionBarView(
			suggestions: [.plainChip("hello", score: 0.9)],
			totalWidth: 387,
			onSelect: { _ in }
		)
		assertKeyboardSnapshot(view, size: size(), colorScheme: .dark)
		assertKeyboardSnapshot(view, size: size(), colorScheme: .light)
	}

	func testEmptyBar_alwaysShown() {
		// C1: the bar is shown when enabled even with no chips — visually silent, background only.
		let view = SuggestionBarView(suggestions: [], totalWidth: 387, onSelect: { _ in })
		assertKeyboardSnapshot(view, size: size(), colorScheme: .dark)
		assertKeyboardSnapshot(view, size: size(), colorScheme: .light)
	}

	// MARK: - Slack pill chips (regression)

	func testThreePillChips() {
		let view = SuggestionBarView(
			suggestions: [
				.pillChip("smile", "😄"),
				.pillChip("smiley", "😃"),
				.pillChip("smirk", "😏")
			],
			totalWidth: 387,
			onSelect: { _ in }
		)
		assertKeyboardSnapshot(view, size: size(), colorScheme: .dark)
		assertKeyboardSnapshot(view, size: size(), colorScheme: .light)
	}

	// MARK: - Favorites (paged emoji quick-access)

	func testFavorites_firstPage() {
		// Visual parity with the former free-scroll favorites row: same glyphs, spacing, 40 pt
		// height, no page dots. Seven glyphs fit on one page at iPhone width.
		let view = SuggestionBarView(
			suggestions: [],
			favoriteEmojis: ["❤️", "😀", "🚀", "🎉", "🐶", "🍕", "👍"],
			totalWidth: 387,
			onSelect: { _ in },
			onSelectEmoji: { _ in }
		)
		assertKeyboardSnapshot(view, size: size(), colorScheme: .dark)
		assertKeyboardSnapshot(view, size: size(), colorScheme: .light)
	}

	func testFavorites_overflowFirstPage() {
		// More favorites than fit on a page (15) → first page shows only `emojisPerPage` glyphs
		// (9 at iPhone width), height stays 40 pt, no page dots, no keyboard-height shift (C1).
		let view = SuggestionBarView(
			suggestions: [],
			favoriteEmojis: ["❤️", "😀", "🚀", "🎉", "🐶", "🍕", "👍", "🔥", "✨",
							 "🎈", "🌈", "⭐️", "🍩", "🐱", "🦄"],
			totalWidth: 387,
			onSelect: { _ in },
			onSelectEmoji: { _ in }
		)
		assertKeyboardSnapshot(view, size: size(), colorScheme: .dark)
	}

	// MARK: - Favorites centered (free users — task 82)

	func testFavorites_centered_sixGlyphs() {
		// Free single-page case at the free limit (6) → the cluster is centered, with symmetric gaps
		// left and right rather than stuck flush-left. `centersFavorites` is the only difference from
		// `testFavorites_firstPage`.
		let view = SuggestionBarView(
			suggestions: [],
			favoriteEmojis: ["❤️", "😀", "🚀", "🎉", "🐶", "🍕"],
			centersFavorites: true,
			totalWidth: 387,
			onSelect: { _ in },
			onSelectEmoji: { _ in }
		)
		assertKeyboardSnapshot(view, size: size(), colorScheme: .dark)
		assertKeyboardSnapshot(view, size: size(), colorScheme: .light)
	}

	func testFavorites_centered_threeGlyphs() {
		// Sparse free case (3 favorites) → larger symmetric gaps, cluster still centered (not justified
		// across the full width — see task 82's "centered cluster, not spread" decision).
		let view = SuggestionBarView(
			suggestions: [],
			favoriteEmojis: ["❤️", "😀", "🚀"],
			centersFavorites: true,
			totalWidth: 387,
			onSelect: { _ in },
			onSelectEmoji: { _ in }
		)
		assertKeyboardSnapshot(view, size: size(), colorScheme: .dark)
	}

	// MARK: - Overflow on a narrow device

	func testLongWord_overflowOnSEWidth() {
		// A learned email is the worst case for plain-chip truncation.
		let view = SuggestionBarView(
			suggestions: [
				.plainChip("martin.svoboda026@gmail.com", score: 0.9),
				.plainChip("martin", score: 0.6),
				.plainChip("mark", score: 0.4)
			],
			totalWidth: 387,
			onSelect: { _ in }
		)
		assertKeyboardSnapshot(view, size: size(width: Self.iPhoneSEWidth), colorScheme: .dark)
	}
}
