//
//  EmojiCodesView.swift
//  EmojiCodes
//
//  Created by Martin Svoboda on 25.05.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import SwiftUI
import KeyboCore
import KeyboResources

public struct EmojiCodesView<ViewModel: EmojiCodesViewModeling>: View {
	@Bindable private var viewModel: ViewModel

	typealias Texts = L10n.EmojiCodes

	public init(viewModel: ViewModel) {
		_viewModel = Bindable(wrappedValue: viewModel)
	}

	public var body: some View {
		Group {
			if viewModel.entries.isEmpty {
				emptyState
			} else {
				list
			}
		}
		.navigationTitle(Texts.title)
		.navigationBarTitleDisplayMode(.inline)
		.searchable(text: $viewModel.searchQuery, prompt: Text(Texts.searchPrompt))
		.autocorrectionDisabled()
		.textInputAutocapitalization(.never)
		.overlay(alignment: .bottom) {
			if let shortcode = viewModel.copiedShortcode {
				toast(for: shortcode)
					.transition(.move(edge: .bottom).combined(with: .opacity))
					.padding(.bottom, 24)
			}
		}
		.animation(.easeOut(duration: 0.2), value: viewModel.copiedShortcode)
	}

	private var list: some View {
		List {
			Section {
				ForEach(viewModel.entries) { entry in
					Button {
						viewModel.copy(entry)
					} label: {
						row(for: entry)
					}
					.buttonStyle(.plain)
					.accessibilityLabel("\(entry.wrappedShortcode), \(entry.emoji)")
					.accessibilityHint(Texts.copyHint)
				}
			} footer: {
				Text(Texts.copyHint)
			}
		}
	}

	private func row(for entry: EmojiCodeEntry) -> some View {
		HStack(spacing: 12) {
			Text(entry.emoji)
				.font(.system(size: 28))
				.frame(width: 40, alignment: .center)
			Text(entry.wrappedShortcode)
				.font(.body.monospaced())
				.foregroundStyle(.primary)
			Spacer()
			Image(systemName: "doc.on.doc")
				.font(.footnote)
				.foregroundStyle(.tertiary)
		}
		.contentShape(Rectangle())
	}

	private var emptyState: some View {
		ContentUnavailableView.search
	}

	private func toast(for shortcode: String) -> some View {
		Text(Texts.copiedToast(":\(shortcode):"))
			.font(.callout.weight(.medium))
			.foregroundStyle(.white)
			.padding(.horizontal, 16)
			.padding(.vertical, 10)
			.background(
				Capsule().fill(Color.black.opacity(0.85))
			)
			.shadow(radius: 8, y: 2)
	}
}

#if DEBUG
#Preview {
	NavigationStack {
		EmojiCodesView(viewModel: EmojiCodesViewModelMock())
	}
	.preferredColorScheme(.dark)
}
#endif
