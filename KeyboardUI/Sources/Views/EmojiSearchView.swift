import SwiftUI
import BaseKitX
import KeyboardCore

/// Top half of the keyboard while `KeyboardPage` is `.emojiSearch`: a live-updated query
/// pill on top and a horizontal scrollable results bar beneath it. The QWERTY rows that
/// type into `query` are rendered separately by `KeyboardView` from the layout produced by
/// `LayoutBuilder.layout(page: .emojiSearch, …)` — this view only owns the search-specific
/// chrome above the keys.
public struct EmojiSearchView: View {
	let query: String
	let recents: [String]
	let onSelectEmoji: (String) -> Void
	let onClearSearch: () -> Void
	let onKeyTapHaptic: () -> Void
	let onKeyClick: () -> Void

	public init(
		query: String,
		recents: [String],
		onSelectEmoji: @escaping (String) -> Void,
		onClearSearch: @escaping () -> Void,
		onKeyTapHaptic: @escaping () -> Void = {},
		onKeyClick: @escaping () -> Void = {}
	) {
		self.query = query
		self.recents = recents
		self.onSelectEmoji = onSelectEmoji
		self.onClearSearch = onClearSearch
		self.onKeyTapHaptic = onKeyTapHaptic
		self.onKeyClick = onKeyClick
	}

	private static let cellWidth: CGFloat = 42
	private static let cellHeight: CGFloat = 44

	private var results: [String] {
		// `query` arrives from the dispatcher already lowercased, but the search index does
		// its own trim + lowercase anyway — passing the raw buffer keeps the call site simple
		// and means the placeholder/recents fallback fires on whitespace-only queries too.
		if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
			return recents
		}
		return EmojiSearchIndex.search(query: query).map(\.glyph)
	}

	public var body: some View {
		VStack(spacing: 6) {
			searchBar
			resultsBar
			Spacer(minLength: 0)
		}
		.padding(.top, 4)
	}

	// MARK: - Search bar

	private var searchBar: some View {
		HStack(spacing: 6) {
			Image(systemName: "magnifyingglass")
				.font(.system(size: 14, weight: .regular))
				.foregroundStyle(.secondary)

			ZStack(alignment: .leading) {
				if query.isEmpty {
					Text("Search Emoji")
						.font(.system(size: 15))
						.foregroundStyle(.secondary)
				}
				Text(query)
					.font(.system(size: 15))
					.foregroundStyle(.primary)
			}
			.frame(maxWidth: .infinity, alignment: .leading)

			Button {
				onKeyTapHaptic()
				onKeyClick()
				onClearSearch()
			} label: {
				Image(systemName: "xmark.circle.fill")
					.font(.system(size: 16))
					.foregroundStyle(.secondary)
			}
			.buttonStyle(.plain)
			.accessibilityLabel("Clear search")
		}
		.searchFieldChrome()
		.padding(.horizontal, 10)
	}

	// MARK: - Results bar

	private var resultsBar: some View {
		ScrollView(.horizontal, showsIndicators: false) {
			if results.isEmpty {
				emptyResultsPlaceholder
			} else {
				LazyHStack(spacing: 2) {
					ForEach(results, id: \.self) { emoji in
						EmojiCell(
							emoji: emoji,
							width: Self.cellWidth,
							height: Self.cellHeight
						) {
							onKeyTapHaptic()
							onKeyClick()
							onSelectEmoji(emoji)
						}
					}
				}
				.padding(.horizontal, 10)
			}
		}
		.frame(height: Self.cellHeight)
	}

	private var emptyResultsPlaceholder: some View {
		let label: String = {
			if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
				return "No recent emojis yet"
			}
			return "No results"
		}()
		return Text(label)
			.font(.footnote)
			.foregroundStyle(.secondary)
			.padding(.horizontal, 14)
			.frame(height: Self.cellHeight)
	}

}

#if DEBUG
#Preview("Search — empty query, no recents / Dark") {
	EmojiSearchView(
		query: "",
		recents: [],
		onSelectEmoji: { _ in },
		onClearSearch: {}
	)
	.frame(width: 393, height: 120)
	.background(Color(.systemBackground))
	.preferredColorScheme(.dark)
}

#Preview("Search — empty query, with recents / Dark") {
	EmojiSearchView(
		query: "",
		recents: ["😀", "👋", "🎉", "❤️", "🚀", "🍕"],
		onSelectEmoji: { _ in },
		onClearSearch: {}
	)
	.frame(width: 393, height: 120)
	.background(Color(.systemBackground))
	.preferredColorScheme(.dark)
}

#Preview("Search — query 'rain' / Dark") {
	EmojiSearchView(
		query: "rain",
		recents: [],
		onSelectEmoji: { _ in },
		onClearSearch: {}
	)
	.frame(width: 393, height: 120)
	.background(Color(.systemBackground))
	.preferredColorScheme(.dark)
}
#endif
