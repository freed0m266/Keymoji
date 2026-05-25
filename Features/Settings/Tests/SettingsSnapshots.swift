//
//  SettingsSnapshots.swift
//  Settings_Tests
//
//  Created by Martin Svoboda on 24.05.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import XCTest
import SwiftUI
import SnapshotTesting
import KeyboCore
@testable import Settings

@MainActor
final class SettingsSnapshots: XCTestCase {

	private static let size = CGSize(width: 393, height: 852)

	func testSettings_defaultBothOn_dark() {
		let view = SettingsView(viewModel: SettingsViewModelMock())
			.preferredColorScheme(.dark)
		assertSnapshot(view)
	}

	func testSettings_bothOff_dark() {
		let view = SettingsView(viewModel: SettingsViewModelMock(showNumberRow: false, hapticFeedbackEnabled: false))
			.preferredColorScheme(.dark)
		assertSnapshot(view)
	}

	func testSettings_appearanceSystem_dark() {
		let view = SettingsView(viewModel: SettingsViewModelMock(appearance: .system))
			.preferredColorScheme(.dark)
		assertSnapshot(view)
	}

	func testSettings_appearanceLight_dark() {
		let view = SettingsView(viewModel: SettingsViewModelMock(appearance: .light))
			.preferredColorScheme(.dark)
		assertSnapshot(view)
	}

	func testSettings_appearanceDark_dark() {
		let view = SettingsView(viewModel: SettingsViewModelMock(appearance: .dark))
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
