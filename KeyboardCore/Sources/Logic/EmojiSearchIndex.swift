import Foundation

/// Pure-function emoji search over `EmojiCatalog.all` + `SlackEmojiTable`. Multi-token AND
/// prefix matching with a deterministic four-tier ranking, mirroring the algorithm spec
/// from task 39.
///
/// Designed to stay allocation-light: the bundled catalog precomputes lowercased name +
/// token slices once at load time, so a typical query walks ~1 400 entries and does
/// `String.hasPrefix` comparisons against pre-lowercased data only.
public enum EmojiSearchIndex {

	/// Default cap on returned results. `nil` means no cap — callers can lower it for
	/// tighter UIs (e.g. a vertical list) but the horizontal scroll bar in `EmojiSearchView`
	/// can fit an unbounded run.
	public static let defaultLimit: Int? = nil

	/// `catalog == nil` uses the bundled catalog and the precomputed search-entry projection
	/// (lowercased name + tokens + keywords) cached on `EmojiCatalog`. Passing a non-nil
	/// catalog is the test path — entries are rebuilt on the fly. The spec sketch defaulted
	/// `catalog` to `EmojiCatalog.all`, but comparing two 1 400-element arrays on every
	/// keystroke just to detect that case was wasteful, so the default is encoded as `nil`.
	public static func search(
		query: String,
		catalog: [Emoji]? = nil,
		slackTable: [String: String] = SlackEmojiTable.defaultTable,
		limit: Int? = defaultLimit
	) -> [Emoji] {
		let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
		guard !trimmed.isEmpty else { return [] }

		let tokens = trimmed
			.split(whereSeparator: { $0.isWhitespace })
			.map(String.init)
		guard !tokens.isEmpty else { return [] }

		let entries: [EmojiCatalog.SearchEntry]
		if let catalog {
			entries = catalog.map { emoji in
				EmojiCatalog.SearchEntry(
					emoji: emoji,
					nameLowercased: emoji.name.lowercased(),
					nameTokens: emoji.name
						.lowercased()
						.split(whereSeparator: { $0.isWhitespace || $0 == "-" })
						.map(String.init),
					keywords: emoji.keywords.map { $0.lowercased() }
				)
			}
		} else {
			entries = EmojiCatalog.searchEntries
		}

		// Inverted shortcode lookup, scoped to glyphs we actually carry — the parser already
		// builds a similar map but it picks one *canonical* shortcode per emoji. For search
		// we want every shortcode aliased onto its glyph, so a query like `thumbsup` and
		// `+1` both surface 👍.
		let shortcodesByGlyph = shortcodeIndex(from: slackTable)

		// Filter pass: each query token must prefix-match at least one searchable string
		// (full name, any name token, any keyword, or any aliased slack shortcode).
		// Tier classification happens in the same pass so we don't walk the catalog twice.
		var tiered: [(tier: Int, index: Int, emoji: Emoji)] = []
		tiered.reserveCapacity(64)

		for (index, entry) in entries.enumerated() {
			let shortcodes = shortcodesByGlyph[entry.emoji.glyph] ?? []
			guard tokensAllMatch(tokens, entry: entry, shortcodes: shortcodes) else { continue }
			let tier = classifyTier(
				trimmedQuery: trimmed,
				firstToken: tokens[0],
				isSingleToken: tokens.count == 1,
				entry: entry,
				shortcodes: shortcodes
			)
			tiered.append((tier: tier, index: index, emoji: entry.emoji))
		}

		// Stable sort: lower tier first, then original catalog index (Unicode order).
		tiered.sort { lhs, rhs in
			if lhs.tier != rhs.tier { return lhs.tier < rhs.tier }
			return lhs.index < rhs.index
		}

		let ranked = tiered.map(\.emoji)
		if let limit, limit >= 0 {
			return Array(ranked.prefix(limit))
		}
		return ranked
	}

	// MARK: - Matching

	private static func tokensAllMatch(
		_ tokens: [String],
		entry: EmojiCatalog.SearchEntry,
		shortcodes: [String]
	) -> Bool {
		for token in tokens {
			if !tokenMatchesAny(token, entry: entry, shortcodes: shortcodes) {
				return false
			}
		}
		return true
	}

	private static func tokenMatchesAny(
		_ token: String,
		entry: EmojiCatalog.SearchEntry,
		shortcodes: [String]
	) -> Bool {
		if entry.nameLowercased.hasPrefix(token) { return true }
		for namePiece in entry.nameTokens where namePiece.hasPrefix(token) {
			return true
		}
		for keyword in entry.keywords where keyword.hasPrefix(token) {
			return true
		}
		for code in shortcodes where code.hasPrefix(token) {
			return true
		}
		return false
	}

	// MARK: - Ranking

	/// Lower tier wins. Tiers are ordered the same way the task spec calls them out:
	///   1. exact full-name match (single-word query)
	///   2. `name.hasPrefix(query)` (single-word query)
	///   3. any keyword prefix-matches the first query token
	///   4. any slack shortcode prefix-matches the first query token
	///
	/// Multi-word queries skip tiers 1/2 (those only apply to a single token vs. the whole
	/// name) and start at tier 3 — matching the spec, which limits the exact-name shortcut
	/// to single-word lookups.
	private static func classifyTier(
		trimmedQuery: String,
		firstToken: String,
		isSingleToken: Bool,
		entry: EmojiCatalog.SearchEntry,
		shortcodes: [String]
	) -> Int {
		if isSingleToken {
			if entry.nameLowercased == trimmedQuery { return 1 }
			if entry.nameLowercased.hasPrefix(trimmedQuery) { return 2 }
		}
		for keyword in entry.keywords where keyword.hasPrefix(firstToken) {
			return 3
		}
		for code in shortcodes where code.hasPrefix(firstToken) {
			return 4
		}
		// Falls through when only secondary name tokens matched (e.g. multi-word AND
		// hit via name token + keyword combos). Group those alongside the keyword tier
		// so they sort after exact/name-prefix hits but before pure-shortcode matches.
		return 3
	}

	// MARK: - Slack shortcode reverse index

	private static func shortcodeIndex(from table: [String: String]) -> [String: [String]] {
		var result: [String: [String]] = [:]
		result.reserveCapacity(table.count)
		for (shortcode, glyph) in table {
			result[glyph, default: []].append(shortcode.lowercased())
		}
		return result
	}
}
