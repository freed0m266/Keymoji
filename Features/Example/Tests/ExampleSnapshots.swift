//
//  ExampleSnapshots.swift
//  Example_Tests
//
//  Created by Martin Svoboda on 26.04.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import XCTest
import KeyboTesting
@testable import Example

class ExampleSnapshots: XCTestCase {
	@MainActor
	func testPreviews() {
		let view = ExampleView(viewModel: ExampleViewModelMock())
		AssertSnapshot(view)
	}
}
