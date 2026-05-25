//
//  EmojiCodesSnapshots.swift
//  EmojiCodes_Tests
//
//  Created by Martin Svoboda on 25.05.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import XCTest
import SwiftUI
import SnapshotTesting
@testable import EmojiCodes

@MainActor
final class EmojiCodesSnapshots: XCTestCase {

	private static let size = CGSize(width: 393, height: 852)

	func testEmojiCodes_list_dark() {
		let view = NavigationStack {
			EmojiCodesView(viewModel: EmojiCodesViewModelMock())
		}
		.preferredColorScheme(.dark)
		assertSnapshot(view)
	}

	func testEmojiCodes_empty_dark() {
		let view = NavigationStack {
			EmojiCodesView(viewModel: EmojiCodesViewModelMock(entries: []))
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
