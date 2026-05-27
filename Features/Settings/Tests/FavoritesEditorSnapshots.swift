//
//  FavoritesEditorSnapshots.swift
//  Settings_Tests
//
//  Created by Martin Svoboda on 27.05.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import XCTest
import SwiftUI
import SnapshotTesting
@testable import Settings

@MainActor
final class FavoritesEditorSnapshots: XCTestCase {

	private static let size = CGSize(width: 393, height: 852)

	func testFavoritesEditor_withKnownEmojis_dark() {
		let view = NavigationStack {
			FavoritesEditorView(
				viewModel: FavoritesEditorViewModelMock(favorites: ["❤️", "😀", "🚀", "🎉", "🐶"])
			)
		}
		.preferredColorScheme(.dark)
		assertSnapshot(view)
	}

	func testFavoritesEditor_withUnknownEmoji_dark() {
		// 🫨 (shaking face) and 🪅 (piñata) are not in SlackEmojiTable — verifies
		// the italic "No shortcode" fallback renders alongside known shortcodes.
		let view = NavigationStack {
			FavoritesEditorView(
				viewModel: FavoritesEditorViewModelMock(favorites: ["🚀", "🫨", "❤️", "🪅"])
			)
		}
		.preferredColorScheme(.dark)
		assertSnapshot(view)
	}

	func testFavoritesEditor_empty_dark() {
		let view = NavigationStack {
			FavoritesEditorView(viewModel: FavoritesEditorViewModelMock(favorites: []))
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
