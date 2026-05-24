import XCTest
import SwiftUI
@testable import KeyboardUI
import KeyboardCore

final class LongPressPopoverSnapshots: XCTestCase {

	private static let cellSize = CGSize(width: 40, height: 44)
	private static let snapshotSize = CGSize(width: 360, height: 60)

	// MARK: - 8 alternates (e, o, u patterns)

	func testEightAlternates_eFirstHighlighted() {
		let view = LongPressPopoverView(
			alternates: [
				.text("é"), .text("ě"), .text("è"), .text("ê"),
				.text("ë"), .text("ē"), .text("ė"), .text("ę")
			],
			highlightedIndex: 0,
			cellSize: Self.cellSize
		)
		.padding()

		assertKeyboardSnapshot(view, size: Self.snapshotSize, colorScheme: .dark)
		assertKeyboardSnapshot(view, size: Self.snapshotSize, colorScheme: .light)
	}

	func testEightAlternates_secondHighlighted() {
		let view = LongPressPopoverView(
			alternates: [
				.text("é"), .text("ě"), .text("è"), .text("ê"),
				.text("ë"), .text("ē"), .text("ė"), .text("ę")
			],
			highlightedIndex: 1,
			cellSize: Self.cellSize
		)
		.padding()

		assertKeyboardSnapshot(view, size: Self.snapshotSize, colorScheme: .dark)
	}

	// MARK: - 4 alternates (c pattern)

	func testFourAlternates_dark() {
		let view = LongPressPopoverView(
			alternates: [.text("č"), .text("ç"), .text("ć"), .text("ĉ")],
			highlightedIndex: 0,
			cellSize: Self.cellSize
		)
		.padding()

		assertKeyboardSnapshot(view, size: Self.snapshotSize, colorScheme: .dark)
		assertKeyboardSnapshot(view, size: Self.snapshotSize, colorScheme: .light)
	}

	// MARK: - 2 alternates (n pattern)

	func testTwoAlternates_dark() {
		let view = LongPressPopoverView(
			alternates: [.text("ñ"), .text("ň")],
			highlightedIndex: 0,
			cellSize: Self.cellSize
		)
		.padding()

		assertKeyboardSnapshot(view, size: CGSize(width: 200, height: 60), colorScheme: .dark)
	}
}
