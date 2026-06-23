import Foundation

/// Tokenization for word completion. Pure, UIKit-free, fully unit-testable.
///
/// Word characters: Unicode letters, digits, the apostrophe (`'`), and Unicode combining marks
/// (so "café", "naïve", "don't", "ipv6" stay whole). Everything else — whitespace, hyphen, the
/// `,.;:?!()[]{}/\@` punctuation family — is a word boundary. Hyphen is *out* by design so
/// "well-known" completes "known", not "well-known".
public enum WordPrefixExtractor {

	/// The word the user is currently composing (the trailing run of word characters before the
	/// cursor), or nil when there is no active prefix to complete.
	///
	/// Returns nil when:
	/// - `before` is nil/empty or ends on a boundary character (no in-progress word), or
	/// - the cursor sits mid-word: `before` ends with a word char *and* `after` begins with one
	///   (completing here would mangle the tail of an existing word, so the bar collapses).
	public static func activeWordPrefix(before: String?, after: String?) -> String? {
		guard let before, !before.isEmpty else { return nil }

		// Mid-word guard: caret wedged between two word characters.
		if let lastBefore = before.last, isWordCharacter(lastBefore),
		   let firstAfter = after?.first, isWordCharacter(firstAfter) {
			return nil
		}

		let chars = Array(before)
		var index = chars.count - 1
		var startOfWord = chars.count
		while index >= 0, isWordCharacter(chars[index]) {
			startOfWord = index
			index -= 1
		}
		guard startOfWord < chars.count else { return nil }
		return String(chars[startOfWord...])
	}

	/// The last *completed* word in `before` — the trailing word run after skipping any trailing
	/// boundary characters (the space or punctuation the user just typed). Used by the learning
	/// hook: after a word-boundary keystroke, this is the word to learn. Returns nil when there's
	/// no word to harvest.
	public static func lastCompletedWord(in before: String?) -> String? {
		guard let before, !before.isEmpty else { return nil }
		let chars = Array(before)
		var index = chars.count - 1
		// Skip the trailing boundary run (e.g. the just-typed " " or ". ").
		while index >= 0, !isWordCharacter(chars[index]) {
			index -= 1
		}
		guard index >= 0 else { return nil }
		let end = index + 1
		var startOfWord = end
		while index >= 0, isWordCharacter(chars[index]) {
			startOfWord = index
			index -= 1
		}
		return String(chars[startOfWord..<end])
	}

	/// The whole email address at the very end of `text` (ignoring trailing whitespace/punctuation), or
	/// nil when the text doesn't end in one. The word tokenizer treats `@` and `.` as boundaries, so a
	/// prose-typed address would otherwise be learned only as fragments (`gmail`, `com`); the prose
	/// learning path uses this to capture `local@domain.tld` as a single address token. Requires an `@`,
	/// a dotted domain, and a ≥2-letter TLD, so prose like `e.g.` or `U.S.A.` is rejected.
	static func trailingEmail(in text: String?) -> String? {
		guard let text, let regex = emailRegex else { return nil }
		// Emails never start or end with whitespace/closing punctuation, so trimming both ends is safe
		// and lets the `$`-anchored match reach an address that a boundary char immediately follows.
		let trimmed = text.trimmingCharacters(in: emailTrimSet)
		guard trimmed.contains("@") else { return nil }
		let ns = trimmed as NSString
		guard let match = regex.firstMatch(in: trimmed, options: [], range: NSRange(location: 0, length: ns.length)),
		      match.range.location != NSNotFound else { return nil }
		return ns.substring(with: match.range)
	}

	/// `local@domain.tld` anchored at end of string. Compiled once and shared (`NSRegularExpression` is
	/// immutable and thread-safe).
	private static let emailRegex = try? NSRegularExpression(
		pattern: "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
	)
	/// Trailing/leading chars that can't be part of an email and are stripped before matching.
	private static let emailTrimSet = CharacterSet.whitespacesAndNewlines
		.union(CharacterSet(charactersIn: ".,;:!?\"'()[]{}<>"))

	/// A word character: Unicode letter, decimal digit, apostrophe, or combining mark.
	static func isWordCharacter(_ character: Character) -> Bool {
		if character == "'" { return true }
		if character.isLetter || character.isNumber { return true }
		// Standalone combining marks (rare — most arrive composed into a letter, but guard anyway).
		return character.unicodeScalars.allSatisfy { scalar in
			scalar.properties.isDiacritic
				|| CharacterSet.nonBaseCharacters.contains(scalar)
		} && !character.unicodeScalars.isEmpty
	}
}
