//
//  ExampleViewModel.swift
//  Example
//
//  Created by Martin Svoboda on 26.04.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import Foundation
import KeymojiCore

@MainActor
public protocol ExampleViewModeling: Observable {

}

@MainActor
public func exampleVM() -> some ExampleViewModeling {
	ExampleViewModel(dependencies: dependencies.example)
}

@Observable
final class ExampleViewModel: BaseViewModel, ExampleViewModeling {

	private let dependencies: ExampleDependencies

	// MARK: - Init

	init(dependencies: ExampleDependencies) {
		self.dependencies = dependencies
		super.init()
	}
}
