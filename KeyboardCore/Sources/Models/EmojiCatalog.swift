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
/// shipping all 250 ISO codes. Their names are derived (see `flagName(for:)`) so flags carry
/// a label like every other entry; search keywords for flags can be layered in later.
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

	/// Catalog entry for a glyph, or nil if it isn't part of the bundled set. Backed by an
	/// O(1) lookup built once at load — used where a glyph (e.g. a stored favorite) needs to
	/// recover its name without scanning `all`.
	public static func emoji(for glyph: String) -> Emoji? {
		storage.byGlyph[glyph]
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

	// MARK: - Flag names
	//
	// Country flags are regional-indicator pairs (🇨🇿 = 🇨 + 🇿): we decode the pair back to its
	// ISO 3166-1 alpha-2 code and let `Locale` resolve the country name, so only the handful of
	// non-country flags need a hand-written entry. English-only and lowercased to match the CLDR
	// names from the bundled dataset (both the search index and the display layer assume that).

	private static let englishLocale = Locale(identifier: "en_US")

	/// CLDR names for flags that aren't regional-indicator country pairs.
	private static let specialFlagNames: [String: String] = [
		"🏳️": "white flag",
		"🏴": "black flag",
		"🏁": "chequered flag",
		"🚩": "triangular flag",
		"🏳️‍🌈": "rainbow flag",
		"🏳️‍⚧️": "transgender flag",
		"🏴‍☠️": "pirate flag"
	]

	/// Lowercased display name for a flag glyph: the country name via `Locale` for regional-indicator
	/// pairs, otherwise the curated `specialFlagNames` entry (empty if neither applies).
	private static func flagName(for glyph: String) -> String {
		if let code = regionCode(from: glyph),
		   let country = englishLocale.localizedString(forRegionCode: code) {
			return country.lowercased()
		}
		return specialFlagNames[glyph] ?? ""
	}

	/// Decodes a two-symbol regional-indicator flag (🇨🇿) into its ISO 3166-1 alpha-2 code ("CZ").
	/// Returns nil for anything that isn't exactly two regional-indicator scalars (so the special
	/// flags above — single glyphs or ZWJ sequences — fall through to the curated table).
	private static func regionCode(from glyph: String) -> String? {
		let base: UInt32 = 0x1F1E6  // 🇦
		let top: UInt32 = 0x1F1FF   // 🇿
		var code = ""
		for scalar in glyph.unicodeScalars {
			guard (base...top).contains(scalar.value),
			      let letter = UnicodeScalar(scalar.value - base + 0x41) else { return nil }
			code.unicodeScalars.append(letter)
		}
		return code.count == 2 ? code : nil
	}

	// MARK: - JSON loading

	/// Stored ahead of `Storage` so we can fold a static and a lazy-loaded source into one
	/// cached snapshot. Building it once on first access amortises the JSON decode + token
	/// precomputation across the keyboard lifetime.
	private struct Storage: Sendable {
		let all: [Emoji]
		let byCategory: [EmojiCategory: [Emoji]]
		let byGlyph: [String: Emoji]
		let searchEntries: [SearchEntry]
	}

	private static let storage: Storage = buildStorage()

	private static func buildStorage() -> Storage {
		let loaded = loadFromBundle()
		let flags = flagGlyphs.map { Emoji(glyph: $0, name: flagName(for: $0), keywords: [], category: .flags) }
		let all = loaded + flags
		let byCategory = Dictionary(grouping: all, by: \.category)
		// First-wins on the (rare) duplicate glyph so the lookup mirrors `all`'s ordering.
		let byGlyph = Dictionary(all.map { ($0.glyph, $0) }, uniquingKeysWith: { first, _ in first })
		let searchEntries = all.map { emoji in
			SearchEntry(
				emoji: emoji,
				nameLowercased: emoji.name,
				nameTokens: tokenize(emoji.name),
				keywords: emoji.keywords
			)
		}
		return Storage(all: all, byCategory: byCategory, byGlyph: byGlyph, searchEntries: searchEntries)
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

public extension EmojiCatalog {
	/// Curated starter set shown in the onboarding favorites grid and used as the silent fallback
	/// written to `favoriteEmojis` when the user skips the step or selects nothing — so the
	/// favorites bar is never empty after onboarding. One source of truth for both the grid and the
	/// fallback keeps the glyph strings (incl. variation selectors) consistent, which is what the
	/// `contains` checkmark match and the bar renderer both rely on. Order = order in the favorites
	/// bar (manual sort). Global and locale-agnostic.
	static let defaultFavorites: [String] = [
		"❤️", "😂", "👍", "🙏", "😍", "🔥", "🎉", "😭", "🥰", "😎", "👌", "✨"
	]
}
