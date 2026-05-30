import XCTest
import SwiftUI
@testable import KeyboardUI
import KeyboardCore

/// Snapshots for the suggestion bar in isolation (40 pt tall). Covers both render styles, the
/// always-on empty state (C1), the sparse state (F2), and long-word overflow on a narrow device.
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
			onSelect: { _ in }
		)
		assertKeyboardSnapshot(view, size: size(), colorScheme: .dark)
		assertKeyboardSnapshot(view, size: size(), colorScheme: .light)
	}

	func testSinglePlainChip_sparse() {
		// F2: fewer than three candidates → fewer chips, no empty padding.
		let view = SuggestionBarView(
			suggestions: [.plainChip("hello", score: 0.9)],
			onSelect: { _ in }
		)
		assertKeyboardSnapshot(view, size: size(), colorScheme: .dark)
		assertKeyboardSnapshot(view, size: size(), colorScheme: .light)
	}

	func testEmptyBar_alwaysShown() {
		// C1: the bar is shown when enabled even with no chips — visually silent, background only.
		let view = SuggestionBarView(suggestions: [], onSelect: { _ in })
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
			onSelect: { _ in }
		)
		assertKeyboardSnapshot(view, size: size(), colorScheme: .dark)
		assertKeyboardSnapshot(view, size: size(), colorScheme: .light)
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
			onSelect: { _ in }
		)
		assertKeyboardSnapshot(view, size: size(width: Self.iPhoneSEWidth), colorScheme: .dark)
	}
}
