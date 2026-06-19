//
//  EmojiCatalogPickerSnapshots.swift
//  EmojiCatalogPicker_Tests
//
//  Created by Martin Svoboda on 27.05.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import XCTest
import SwiftUI
import SnapshotTesting
@testable import EmojiCatalogPicker

@MainActor
final class EmojiCatalogPickerSnapshots: XCTestCase {

	private static let size = CGSize(width: 393, height: 852)

	func testEmojiCatalogPicker_noSelection_dark() {
		let view = NavigationStack {
			EmojiCatalogPickerView(
				selectedEmojis: [],
				onToggle: { _ in },
				onDone: {}
			)
		}
		.preferredColorScheme(.dark)
		assertSnapshot(view)
	}

	func testEmojiCatalogPicker_someSelected_dark() {
		let view = NavigationStack {
			EmojiCatalogPickerView(
				selectedEmojis: ["😀", "❤️", "🚀", "🎉", "🐶"],
				onToggle: { _ in },
				onDone: {}
			)
		}
		.preferredColorScheme(.dark)
		assertSnapshot(view)
	}

	func testEmojiCatalogPicker_atSelectionLimit_dimsRest_dark() {
		// 6 selected with a cap of 6 → every unselected cell dims/disables (task 64 Scope 7).
		let view = NavigationStack {
			EmojiCatalogPickerView(
				selectedEmojis: ["😀", "❤️", "🚀", "🎉", "🐶", "✨"],
				onToggle: { _ in },
				onDone: {},
				selectionLimit: 6
			)
		}
		.preferredColorScheme(.dark)
		assertSnapshot(view)
	}

	private func assertSnapshot<V: View>(
		_ view: V,
		record: Bool = false,
		file: StaticString = #filePath,
		testName: String = #function,
		line: UInt = #line
	) {
		let host = view.frame(width: Self.size.width, height: Self.size.height)
		SnapshotTesting.assertSnapshot(
			of: host,
			as: .image(
				drawHierarchyInKeyWindow: false,
				perceptualPrecision: 0.93,
				layout: .fixed(width: Self.size.width, height: Self.size.height),
				traits: .init(userInterfaceStyle: .dark)
			),
			record: record,
			file: file,
			testName: testName + "_dark",
			line: line
		)
	}
}
