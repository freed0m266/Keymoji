import Foundation

/// Computes typeahead suggestions for the Slack-style emoji shortcode bar that sits above
/// the keyboard while the user is composing a shortcode (e.g. `:smi` → smile, smiley, smirk…).
///
/// Pure logic. Caller (`KeyboardViewController`) supplies `documentContextBeforeInput` and
/// gets back a list of `Suggestion`s in display order, or an empty array when the buffer
/// isn't currently in a "shortcode authoring" state.
///
/// Activation rules (all must hold):
/// - The buffer ends with `:` + at least `minPrefixLength` valid shortcode characters
///   (ASCII letters/digits/`_`/`+`/`-`).
/// - The opening `:` sits at a word boundary — start of document or after whitespace.
///   Mirrors [`SlackEmojiParser`]'s rule so the popover and the closing-colon substitution
///   agree on what counts as a shortcode context.
///
/// Ranking: exact match first, then alphabetical prefix matches, capped at `limit`.
public enum SlackEmojiSuggester {

	public struct Suggestion: Equatable, Sendable, Identifiable {
		public let shortcode: String
		public let emoji: String

		public var id: String { shortcode }

		public init(shortcode: String, emoji: String) {
			self.shortcode = shortcode
			self.emoji = emoji
		}
	}

	public static let defaultLimit = 8
	public static let defaultMinPrefixLength = 2

	public static func suggestions(
		forContext context: String?,
		table: [String: String] = SlackEmojiTable.defaultTable,
		limit: Int = defaultLimit,
		minPrefixLength: Int = defaultMinPrefixLength
	) -> [Suggestion] {
		guard let context, !context.isEmpty else { return [] }
		guard let prefix = activeShortcodePrefix(in: context, minLength: minPrefixLength) else {
			return []
		}

		let lowered = prefix.lowercased()
		var exact: [Suggestion] = []
		var prefixMatches: [Suggestion] = []
		for (code, emoji) in table {
			if code == lowered {
				exact.append(Suggestion(shortcode: code, emoji: emoji))
			} else if code.hasPrefix(lowered) {
				prefixMatches.append(Suggestion(shortcode: code, emoji: emoji))
			}
		}
		prefixMatches.sort { $0.shortcode < $1.shortcode }
		return Array((exact + prefixMatches).prefix(limit))
	}

	/// Returns the active shortcode prefix the user is currently composing (without the
	/// opening `:`), or nil if `context` doesn't end in a valid shortcode-authoring state.
	///
	/// "Authoring state" = ends with `minLength`+ valid shortcode chars, preceded by `:`,
	/// preceded by a word boundary (start of buffer or whitespace).
	public static func activeShortcodePrefix(in context: String, minLength: Int = defaultMinPrefixLength) -> String? {
		let chars = Array(context)
		var i = chars.count - 1
		var trailingChars = 0
		while i >= 0, isValidShortcodeChar(chars[i]) {
			trailingChars += 1
			i -= 1
		}
		// Must have ≥ minLength trailing valid chars, and the char *before* them must be `:`.
		guard trailingChars >= minLength, i >= 0, chars[i] == ":" else { return nil }
		// And the opening `:` must sit at a word boundary.
		if i > 0, !SlackEmojiParser.isWordBoundary(chars[i - 1]) { return nil }
		let prefixStart = i + 1
		return String(chars[prefixStart...])
	}

	private static func isValidShortcodeChar(_ c: Character) -> Bool {
		guard c.unicodeScalars.count == 1, let scalar = c.unicodeScalars.first, scalar.isASCII else {
			return false
		}
		let v = scalar.value
		return (0x61...0x7A).contains(v)
			|| (0x41...0x5A).contains(v)
			|| (0x30...0x39).contains(v)
			|| v == 0x5F || v == 0x2B || v == 0x2D
	}
}
