//
//  ContentView.swift
//  Keybo
//
//  Created by Martin Svoboda on 26.04.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import SwiftUI

struct ContentView: View {
	var body: some View {
		Text("Hello, World!")
			.font(.title2.weight(.semibold))
			.foregroundStyle(.white)
			.frame(maxWidth: .infinity, maxHeight: .infinity)
			.background {
				RadialGradient(
					colors: [
						Color(red: 40/255, green: 92/255, blue: 35/255).opacity(0.65),
						Color(red: 40/255, green: 92/255, blue: 35/255).opacity(0.18),
						.black.opacity(0.0)
					],
					center: .topLeading,
					startRadius: 40,
					endRadius: 500
				)
				.ignoresSafeArea()
			}
	}
}

#Preview {
	ContentView()
}
