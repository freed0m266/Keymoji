//
//  AboutSnapshots.swift
//  About_Tests
//
//  Created by Martin Svoboda on 24.05.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import XCTest
import SwiftUI
import SnapshotTesting
@testable import About

@MainActor
final class AboutSnapshots: XCTestCase {

	private static let size = CGSize(width: 393, height: 852)

	func testAbout_dark() {
		let view = NavigationStack {
			AboutView(viewModel: AboutViewModelMock())
		}
		.preferredColorScheme(.dark)

		assertSnapshot(view, scheme: .dark)
	}

	private func assertSnapshot<V: View>(
		_ view: V,
		scheme: ColorScheme,
		record: Bool = false,
		file: StaticString = #filePath,
		testName: String = #function,
		line: UInt = #line
	) {
		let style: UIUserInterfaceStyle = scheme == .dark ? .dark : .light
		let host = view.frame(width: Self.size.width, height: Self.size.height)
		SnapshotTesting.assertSnapshot(
			of: host,
			as: .image(
				drawHierarchyInKeyWindow: false,
				perceptualPrecision: 0.93,
				layout: .fixed(width: Self.size.width, height: Self.size.height),
				traits: .init(userInterfaceStyle: style)
			),
			record: record,
			file: file,
			testName: testName + "_\(scheme == .dark ? "dark" : "light")",
			line: line
		)
	}
}
