//
//  ExampleView.swift
//  Example
//
//  Created by Martin Svoboda on 26.04.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import SwiftUI
import KeyboUI

public struct ExampleView<ViewModel: ExampleViewModeling>: View {
	@State private var viewModel: ViewModel

	init(viewModel: ViewModel) {
		_viewModel = .init(wrappedValue: viewModel)
	}

	public var body: some View {
		Text("Hello, World!")
	}
}

#if DEBUG
#Preview {
	ExampleView(viewModel: ExampleViewModelMock())
}
#endif
