import Foundation

/// Top-level categories shown as tabs in the emoji panel. Order mirrors Apple's stock picker
/// plus a Keymoji-specific `favorites` tab pinned to the left when the user has curated any.
/// `favorites` and `recents` are runtime-driven (not part of the bundled catalog) and only
/// appear when their respective data sources are non-empty.
public enum EmojiCategory: String, Sendable, CaseIterable, Equatable, Identifiable {
	case favorites
	case recents
	case smileys
	case people
	case animals
	case food
	case activity
	case travel
	case objects
	case symbols
	case flags

	public var id: String { rawValue }

	/// Accessibility label for the tab. Kept English-only in v1.1 — localization can be layered later.
	public var accessibilityLabel: String {
		switch self {
		case .favorites:  return "Favorites"
		case .recents:    return "Recently used"
		case .smileys:    return "Smileys & emotion"
		case .people:     return "People"
		case .animals:    return "Animals & nature"
		case .food:       return "Food & drink"
		case .activity:   return "Activity"
		case .travel:     return "Travel & places"
		case .objects:    return "Objects"
		case .symbols:    return "Symbols"
		case .flags:      return "Flags"
		}
	}
}

/// Bundled emoji dataset. The eight non-flag categories are loaded from
/// `Resources/EmojiData.json` (generated from `muan/unicode-emoji-json` + `muan/emojilib` by
/// `scripts/generate_emoji_search_data.sh`): ZWJ sequences, skin-tone variants, keycaps and
/// regional-indicator pairs are excluded. Ordering follows the official Unicode emoji order.
/// Flags stay hand-curated below — a Czech-relevant subset is pinned at the top rather than
/// shipping all 250 ISO codes, and search keywords for flags can be layered in later.
public enum EmojiCatalog {

	/// All categories that have at least one bundled emoji. Excludes `.recents` — that one is
	/// driven by the user's history at view time, not from the static catalog.
	public static let staticCategories: [EmojiCategory] = [
		.smileys, .people, .animals, .food, .activity, .travel, .objects, .symbols, .flags
	]

	/// Flat collection across every static category. Lazy-built from the bundled JSON the
	/// first time it's accessed; subsequent reads hit a cached copy.
	public static var all: [Emoji] { storage.all }

	public static func emojis(for category: EmojiCategory) -> [Emoji] {
		switch category {
		case .favorites, .recents:
			return []
		default:
			return storage.byCategory[category] ?? []
		}
	}

	// MARK: - Search hooks (internal — used by `EmojiSearchIndex`)

	/// Search-side projection of a catalog entry. Precomputed at bundle-load so the inner
	/// loop of `EmojiSearchIndex.search` doesn't pay the cost of lowercasing or tokenising
	/// the same strings on every keystroke.
	struct SearchEntry: Sendable {
		let emoji: Emoji
		/// Full lowercased name (e.g. `"red heart"`). Drives the tier-1/2 ranking checks.
		let nameLowercased: String
		/// `nameLowercased` split by whitespace + hyphens — used for the multi-word AND filter.
		let nameTokens: [String]
		/// Keywords from the bundled dataset, already lowercased at load time.
		let keywords: [String]
	}

	/// Parallel to `all` (same index = same emoji). Internal so the search index can read it
	/// without exposing precomputed strings on the public `Emoji` struct.
	static var searchEntries: [SearchEntry] { storage.searchEntries }

	// MARK: - Hardcoded flags
	//
	// Kept as a hand-picked Czech-relevant subset rather than the full 250-flag list. Flags
	// are intentionally excluded from `EmojiData.json` (the filter script drops regional
	// indicator pairs); we wrap each glyph as `Emoji` here so the rest of the pipeline (grid
	// rendering, recents, search) is uniform.

	private static let flagGlyphs: [String] = [
		"🏳️", "🏴", "🏁", "🚩", "🏳️‍🌈", "🏳️‍⚧️", "🏴‍☠️", "🇨🇿", "🇸🇰", "🇺🇸",
		"🇬🇧", "🇪🇺", "🇨🇦", "🇦🇺", "🇳🇿", "🇩🇪", "🇫🇷", "🇮🇹", "🇪🇸", "🇵🇹",
		"🇳🇱", "🇧🇪", "🇨🇭", "🇦🇹", "🇸🇪", "🇳🇴", "🇩🇰", "🇫🇮", "🇮🇸", "🇮🇪",
		"🇵🇱", "🇭🇺", "🇷🇴", "🇧🇬", "🇬🇷", "🇹🇷", "🇺🇦", "🇷🇺", "🇧🇾", "🇪🇪",
		"🇱🇻", "🇱🇹", "🇮🇱", "🇸🇦", "🇦🇪", "🇪🇬", "🇿🇦", "🇮🇳", "🇨🇳", "🇯🇵",
		"🇰🇷", "🇰🇵", "🇹🇼", "🇭🇰", "🇸🇬", "🇲🇾", "🇮🇩", "🇹🇭", "🇻🇳", "🇵🇭",
		"🇧🇷", "🇦🇷", "🇨🇱", "🇨🇴", "🇲🇽", "🇵🇪", "🇻🇪", "🇨🇺", "🇯🇲"
	]

	// MARK: - JSON loading

	/// Stored ahead of `Storage` so we can fold a static and a lazy-loaded source into one
	/// cached snapshot. Building it once on first access amortises the JSON decode + token
	/// precomputation across the keyboard lifetime.
	private struct Storage: Sendable {
		let all: [Emoji]
		let byCategory: [EmojiCategory: [Emoji]]
		let searchEntries: [SearchEntry]
	}

	private static let storage: Storage = buildStorage()

	private static func buildStorage() -> Storage {
		let loaded = loadFromBundle()
		let flags = flagGlyphs.map { Emoji(glyph: $0, name: "", keywords: [], category: .flags) }
		let all = loaded + flags
		let byCategory = Dictionary(grouping: all, by: \.category)
		let searchEntries = all.map { emoji in
			SearchEntry(
				emoji: emoji,
				nameLowercased: emoji.name,
				nameTokens: tokenize(emoji.name),
				keywords: emoji.keywords
			)
		}
		return Storage(all: all, byCategory: byCategory, searchEntries: searchEntries)
	}

	private struct RawEntry: Decodable {
		let g: String
		let n: String
		let k: [String]
		let c: String
	}

	private static func loadFromBundle() -> [Emoji] {
		guard let url = Bundle.module.url(forResource: "EmojiData", withExtension: "json") else {
			assertionFailure("EmojiData.json missing from KeyboardCore bundle")
			return []
		}
		do {
			let data = try Data(contentsOf: url)
			let raw = try JSONDecoder().decode([RawEntry].self, from: data)
			return raw.compactMap { entry in
				guard let category = EmojiCategory(rawValue: entry.c) else { return nil }
				return Emoji(
					glyph: entry.g,
					name: entry.n,
					keywords: entry.k,
					category: category
				)
			}
		} catch {
			assertionFailure("Failed to decode EmojiData.json: \(error)")
			return []
		}
	}

	/// Splits a CLDR name into individual word tokens. Whitespace and hyphens both act as
	/// word boundaries (so `"high-speed train"` yields `["high", "speed", "train"]`),
	/// matching how users mentally tokenise multi-word search queries.
	private static func tokenize(_ name: String) -> [String] {
		guard !name.isEmpty else { return [] }
		return name
			.split(whereSeparator: { $0.isWhitespace || $0 == "-" })
			.map(String.init)
	}
}
