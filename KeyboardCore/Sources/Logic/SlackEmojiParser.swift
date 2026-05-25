import Foundation

/// Detects Slack/Discord/GitHub-style `:shortcode:` patterns at the end of a text buffer
/// and resolves them to the matching emoji from a lookup table.
///
/// Pure function — no I/O, no proxy access. The dispatcher reads
/// `documentContextBeforeInput` after each insertion and feeds it here; on a hit it
/// deletes `consumedLength` characters from the proxy and inserts `emoji`.
///
/// Match rule: the buffer must end with `:`, immediately preceded by ≥1 valid shortcode
/// character (ASCII letters/digits/`_`/`+`/`-`), then another `:`. The captured shortcode
/// is lowercased before lookup so `:Smile:` resolves the same as `:smile:`. Any other
/// character inside the would-be shortcode (whitespace, punctuation, accented letters)
/// cancels the match; the dispatcher leaves the text alone.
public enum SlackEmojiParser {

	public struct Match: Equatable, Sendable {
		/// The emoji to insert in place of the shortcode (e.g. "😄").
		public let emoji: String

		/// Number of trailing characters (Swift `Character`s) to delete from the proxy
		/// before inserting `emoji`. Includes both colons.
		public let consumedLength: Int

		public init(emoji: String, consumedLength: Int) {
			self.emoji = emoji
			self.consumedLength = consumedLength
		}
	}

	/// Detect a `:shortcode:` pattern at the very end of `text` and resolve it against `table`.
	/// Returns nil if `text` does not end in a complete, recognized shortcode.
	public static func detectMatch(
		atEndOf text: String,
		table: [String: String] = SlackEmojiTable.defaultTable
	) -> Match? {
		guard text.hasSuffix(":") else { return nil }

		let chars = Array(text)
		let closingIndex = chars.count - 1
		guard closingIndex > 0 else { return nil }

		var i = closingIndex - 1
		while i >= 0 {
			let c = chars[i]
			if c == ":" {
				let shortcodeStart = i + 1
				let shortcodeEnd = closingIndex - 1
				// `::` (no chars between colons) is not a valid shortcode.
				guard shortcodeEnd >= shortcodeStart else { return nil }
				let shortcode = String(chars[shortcodeStart...shortcodeEnd]).lowercased()
				guard let emoji = table[shortcode] else { return nil }
				let consumed = closingIndex - i + 1
				return Match(emoji: emoji, consumedLength: consumed)
			}
			if !isValidShortcodeChar(c) { return nil }
			i -= 1
		}
		return nil
	}

	private static func isValidShortcodeChar(_ c: Character) -> Bool {
		guard c.unicodeScalars.count == 1, let scalar = c.unicodeScalars.first, scalar.isASCII else {
			return false
		}
		let v = scalar.value
		// a-z, A-Z, 0-9, _, +, -
		return (0x61...0x7A).contains(v)
			|| (0x41...0x5A).contains(v)
			|| (0x30...0x39).contains(v)
			|| v == 0x5F || v == 0x2B || v == 0x2D
	}
}
